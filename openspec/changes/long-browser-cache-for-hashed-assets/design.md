# Design

## Context

See proposal.md, section Why, for the problem. The state that shapes the approach:

- **Two zone rulesets exist, one per phase.** `infra/cloudflare/modules/domain/main.tf` holds
  `cache_everything` (phase `http_request_cache_settings`, one rule, `expression = "true"`, edge TTL
  one year, browser TTL 14400, both `override_origin`) and
  `security_and_performance_response_headers` (phase `http_response_headers_transform`, one rule,
  `expression = "true"`). Cloudflare permits one entry-point ruleset per phase per zone, so a new rule
  goes into one of these two rulesets, not into a new ruleset (see `infra/cloudflare/README.md`,
  "Zone-wide configuration belongs to the `domain` module").
- **Production today.** `curl -sI` on 2026-09-29 returned `cache-control: public, max-age=14400` for
  a font under `/_astro/` (with `age: 16477`), for `/`, and for a 404 under `/_astro/`. So the browser
  TTL of the cache rule applies to error responses too.
- **Names under `/_astro/` carry a content hash.** Image variants are named
  `<name>.<source hash>_<options hash>.<ext>` in `dist/_astro/`. Font files are named by
  `BuildFontFileIdGenerator` in `node_modules/astro/dist/assets/fonts/infra/`, which hashes the file
  content when the source path is absolute and hashes the URL string otherwise. The site uses
  `fontProviders.local()` with `@fontsource` files (read in `astro.config.ts`). Not verified: that the
  local provider always passes an absolute path. A font from a remote provider would get a name from
  its URL, not its content.
- **How a Terraform change reaches production.** The Terraform Cloud workspace
  `cloudflare-production` is VCS-driven and triggers on `infra/cloudflare/` (see `versions.tf` and
  the README). `pipeline.yml` runs only `fmt` and `validate`. Whether the workspace applies
  automatically or waits for a confirmation is not recorded in the repository.
- **Nothing tests production headers.** The e2e suite runs against `astro preview` (see
  `docs/known-gaps.md`), and `nginx.conf` and `astro.config.ts` send `max-age=0, must-revalidate`.

## Goals / Non-Goals

**Goals:**

- Meet the three requirements in `specs/asset-caching/spec.md` on production with one Terraform rule.
- Make each scenario of that spec checkable against production by one command, run after each deploy.

**Non-Goals:**

- Changing any cache setting that decides what Cloudflare stores at the edge.
- Covering hosts other than production (`astro preview`, the container image).

## Decisions

### D1. Set `Cache-Control` with a response header transform rule

Add a second rule to the ruleset `security_and_performance_response_headers`:

- expression: `starts_with(http.request.uri.path, "/_astro/") and http.response.code in {200 304}`
- action `rewrite`, header `Cache-Control`, operation `set`, value
  `public, max-age=31536000, immutable`

The rule comes after the existing rule, and it does not repeat any header of that rule.

Verified in the Cloudflare docs on 2026-09-29:

- Response header transform rules are available on the Free plan, with 10 active rules
  (`/rules/transform/`).
- `cache-control` is not in the list of headers that a response header transform rule cannot change.
  A change to it "will not change the way Cloudflare caches an object, because Cloudflare evaluates
  caching behavior before applying response header modifications" (`/rules/transform/response-header-modification/`).
  The edge TTL of one year therefore stays as it is.
- `starts_with` and `http.response.code` are available in this phase, and `starts_with` needs no
  regular-expression support, which the Free plan does not have.

Not verified: that the value set by the transform rule replaces the value that the browser TTL of
the cache rule writes. The docs state that transform rules run after the caching decision, which
implies that the transform rule writes last, but no page says so directly. Only the apply can settle
this: the production check after the first deploy answers it (Migration Plan, step 2). Risk R1 names
what happens when the answer is no.

The status condition keeps error responses on the current header (spec requirement "Missing files
under `/_astro/` are not cached for one year"). `304` is in the set because a browser that
revalidates updates the stored headers from the 304, so a 304 with `max-age=14400` would shorten the
stored lifetime again.

Alternatives considered:

- **A second cache rule with a browser TTL of one year for `/_astro/`.** Cache rules stack, and the
  last matching rule wins (`/cache/how-to/cache-rules/order/`), so this works for `max-age`. It cannot
  add `immutable`: the browser TTL setting writes `max-age` only (observed: production sends
  `public, max-age=14400` and nothing else). Its expression runs in a request phase, so it cannot
  exclude 404 responses, which today take the cache rule's browser TTL. Rejected.
- **A cache response rule (`http_response_cache_settings`) with `set_cache_control`.** It supports
  `immutable` and is on the Free plan. But when any rule in that phase matches, Cloudflare switches to
  origin cache control for the response, and cache response rules take precedence over cache rules
  (`/cache/how-to/cache-response-rules/`). That can change the edge TTL of `/_astro/`, which this change
  must leave as it is. Support in the pinned provider `~> 5.22.0` was not checked. Rejected.
- **A `_headers` file for Cloudflare Pages.** The cache rule overrides the origin value
  (`browser_ttl.mode = "override_origin"`), and the file would put platform configuration into the
  built artifact. Rejected.

### D2. A production check script, run by `deploy.yml` after the purge

A new script `scripts/check-production-cache-headers.mjs`, run as `npm run prodcache:check`. It uses
Node built-ins only (`fetch`), so it needs no `npm ci`. It checks `https://www.brokenrobot.xyz` and
follows the spec scenarios:

1. `GET /` — `Cache-Control` has no `immutable` and a `max-age` of at most 14400. The script takes the
   first `/_astro/` URL from the HTML of this response.
2. `HEAD` that `/_astro/` URL — status 200, `Cache-Control` has `max-age=31536000` and `immutable`.
3. The same URL with `If-None-Match` set to the `etag` of step 2 — status 304, same two directives.
   When step 2 returned no `etag`, the script reports this step as not run.
4. `HEAD /favicon.svg` — no `immutable`, `max-age` at most 14400.
5. `HEAD /_astro/` plus a name that no build produces — status 404, no `immutable`, `max-age` at most 14400.

Exit codes follow `thirdparty:check`: 0 pass, 1 a header is wrong, 2 the check could not run (network
error, no `/_astro/` URL found in the page). Each failure line names the URL, the header value, and
the expected value.

`deploy.yml` gets three steps after "Purge the Cloudflare cache": `actions/checkout` and
`actions/setup-node` (same pinned SHAs and `node-version-file: '.node-version'` as `pipeline.yml`),
then `npm run prodcache:check`. The existing steps do not change.

The page, favicon, and 404 assertions go beyond the brief's minimum ("a file under `/_astro/` carries
the one-year lifetime"). They are included because a browser keeps a stored response for its full
lifetime and no purge reaches it: a rule expression that matched pages by mistake would pin an old
page in visitors' browsers for a year. Nothing else detects that before visitors do.

Alternatives considered:

- **Inline `curl` in `deploy.yml`.** Shorter, but it cannot run locally as a named check, and the
  five assertions become a long shell chain. Rejected.
- **A separate workflow on `workflow_run` of Deploy.** One more trigger to reason about, and the
  deploy job already runs at the right moment. Rejected.
- **An e2e test.** The suite runs against `astro preview`, which does not apply Cloudflare rules
  (brief, Decisions). Rejected.

### D3. Documentation

- `docs/development/checks.md`: a new category "Production" with a `prodcache:check` section, and a
  sentence in "The CI pipeline" that `deploy.yml` runs this check after the purge. It is not part of
  the preflight gate, because it inspects production, not the working tree.
- `infra/cloudflare/README.md`, "Edge caching hides deployments": the browser lifetime of a page or a
  `public/` file is `14400` minus the `age` value, so it is between 4 hours and zero. Files under
  `/_astro/` get one year plus `immutable`, and the paragraph that rejects the per-file-type split
  is rewritten to say which part is adopted and why `public/` stays short.
- `docs/architecture.md`, "Security headers": the sentence that says `Cache-Control` is absent from
  the Cloudflare header ruleset is corrected. That ruleset now sets `Cache-Control` for `/_astro/`
  only; the cache ruleset still sets it for every other response.

## Risks / Trade-offs

- **R1. The transform rule does not replace the browser-TTL value** → The check fails at step 2 with
  `max-age=14400`. Fallback: a cache response rule for `/_astro/` with `set_cache_control` and an
  explicit edge setting, after checking provider support and its effect on the edge TTL. That is a
  new plan and needs its own change. Until then the transform rule does no harm, because the header
  stays as it is today, but the deploy job fails on each run after its upload and purge succeed.
- **R2. A browser keeps a long-lived response and no purge reaches it** → The expression is limited
  to `/_astro/` and to status 200 and 304, and the check asserts that pages, `public/` files, and
  404s keep the short lifetime.
- **R3. Deploy runs before Terraform Cloud applies** → On the merge that carries this change, the
  check can fail because the rule is not live yet. Re-run the deploy job after the apply: the upload
  is byte-identical and the purge is harmless.
- **R4. Some browsers ignore `immutable`** → MDN browser-compat-data (read 2026-09-29): Firefox 49+,
  Safari 11+ and Safari on iOS support it; Chrome, Chrome on Android, and Firefox on Android do not.
  For Chrome the measurements show that a fresh file is not re-checked on a normal reload, so
  `max-age=31536000` is enough there. Firefox on Android is not covered by either mechanism, and it was
  not measured.
- **R5. The `age` value can approach one year** → Only if no deploy and no purge happens for a year,
  because the edge TTL is one year. Accepted.
- **R6. A future font from a remote provider gets a URL-based name** → Not in this change. Design
  Context records the condition.

## Migration Plan

1. Merge. Terraform Cloud runs on the `infra/cloudflare/` change. If the workspace waits for a
   confirmation, the human confirms the apply.
2. The deploy job runs `prodcache:check` after the purge. If it ran before the apply, re-run the job.
3. Acceptance, after deploy and outside `tasks.md` (archive runs before the merge, so post-merge
   steps cannot be tasks): the site owner reloads a blog post in Firefox, in Safari, and on the phone
   and sees no reload of the hero image; a reload measurement on production shows no request for a
   file under `/_astro/`. The result goes into the change's retrospective.

Rollback: remove the rule and apply. Browsers keep the files they stored with the long lifetime.
That is harmless, because a changed file has a new name.

## Open Questions

- Does the workspace `cloudflare-production` apply automatically? The answer changes only who
  starts the apply in Migration Plan step 1.
