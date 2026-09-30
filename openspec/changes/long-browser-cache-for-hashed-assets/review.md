# Review

<!-- Reviewed 2026-09-29, against the living specs and the change's planning artifacts. -->

Read for this review: `brief.md`, `proposal.md`, `specs/asset-caching/spec.md`, `design.md`,
`tasks.md`, `.openspec.yaml`, `browser-measurements.md` section D, `openspec/config.yaml`, every
living spec (`agent-content`, `brand-mascot`, `site-chrome`, `theming`, `typography`),
`infra/cloudflare/modules/domain/main.tf`, `infra/cloudflare/README.md`, `.github/workflows/deploy.yml`,
the action pins in `.github/workflows/pipeline.yml`, `docs/development/checks.md`,
`docs/architecture.md` section "Security headers", `docs/known-gaps.md`, `scripts/check-header-sync.mjs`,
and `package.json`. `openspec validate long-browser-cache-for-hashed-assets --strict` passes.

Probes run for this review (2026-09-29):

- `curl -sI` against production: a font under `/_astro/fonts/` answers 200 with
  `cache-control: public, max-age=14400` and an `etag`; the same request with `If-None-Match` set to
  that `etag` answers 304 with the same `cache-control`; a missing `/_astro/` file answers 404 with
  `public, max-age=14400`; `/favicon.svg` answers 200 with `public, max-age=14400`. The first
  `/_astro/` URL in the home page HTML is a font.
- `node -e 'fetch("https://www.brokenrobot.xyz/")…'` inside the Claude Code sandbox: `EPERM` with the
  host allowed and without it. With `NODE_USE_ENV_PROXY=1` and the host allowed: status 200,
  `public, max-age=14400`.
- Cloudflare docs, `/rules/transform/response-header-modification/`: the quoted sentence in
  design.md D1 is on the page as stated. No page states whether a transform rule's `set` overrides
  the value the cache rule's browser TTL writes, so design.md D1's "Not verified" still stands.

## Findings

### Untestable scenarios

- **Blocking — `tasks.md:8-9` (task 1.1 Verify), with `design.md:96`.** The verification "`npm run
  prodcache:check` against production today exits 1" cannot be reached where the implementer runs.
  Node's built-in `fetch` ignores `HTTPS_PROXY`, and the sandbox allows network egress only through
  its proxy, so the script gets `EPERM` and exits 2 whether or not the production host is allowed
  (probe above). The implementer then either records the wrong before-state or adds proxy handling,
  which breaks D2's "Node built-ins only". Task 1.2 would also pass for the wrong reason: every run
  in the sandbox is a network failure. **Fix:** in task 1.1, run
  `NODE_USE_ENV_PROXY=1 npm run prodcache:check` with `www.brokenrobot.xyz` allowed. In task 1.2,
  run with `NODE_USE_ENV_PROXY=1` and the host not allowed, so the exit-2 path is exercised through
  the same proxy route. Say in D2 that the script adds no proxy code (CI has no proxy), and mention
  the variable in the `checks.md` entry's local command.
- **Should-fix — `spec.md:25-30` ("A long `age` value does not expire the file"), with `design.md:36`.**
  Design Goal 2 says one command, run after each deploy, can check each scenario. The check runs
  right after `purge_everything`, so each edge answers with an `age` near 0, and this scenario, which
  is the bug the change fixes, never happens during the run. `browser-measurements.md` section D
  shows ages above 14400 appear only hours later and differ between colos. **Fix:** have the script
  print the `age` of the `/_astro/` response and say whether it was above 14400, so a run shows
  whether it covered the scenario. State in design.md D2, and in the `checks.md` entry, that a local
  run at least 4 hours after a deploy covers this scenario. Add that run to the acceptance in
  Migration Plan step 3.
- **Should-fix — `spec.md:38-43` ("A reload does not re-check a stored file").** The WHEN says "a
  browser", but `design.md:155-159` (R4) says Firefox on Android honors neither `immutable` nor, as
  far as anyone measured, the fresh-cache reload. So the plan itself says the scenario does not hold
  for a known browser. The THEN also compares against "the same reload before this requirement". That
  history cannot be observed once the spec is living. **Fix:** limit the WHEN to the browsers the
  plan covers (Chrome, and Firefox and Safari on desktop and iOS), or rephrase it as "a browser that
  honors `immutable` or treats a fresh subresource as a cache hit on reload". Move the before/after
  comparison to the proposal or the retrospective.
- **Should-fix — `design.md:102-103` (D2 step 3).** The design gives no exit code for "reports this
  step as not run". If the script exits 0, the 304 scenario (`spec.md:32-36`) can go unverified while
  the check stays green. The docs page the check follows forbids that: "never as a pass, because a
  pass claims coverage that never happened" (`docs/development/checks.md:229-231`). Production sends
  an `etag` today and answers the conditional request with 304 (probe above), so a missing `etag`
  means something changed. **Fix:** when step 2 returns no `etag`, exit 2. Also state the method of
  step 3 (`HEAD`, like step 2).
- **Should-fix — `design.md:99-105` (D2 steps 1, 4, 5).** "A `max-age` of at most 14400" does not say
  what happens when `Cache-Control` or `max-age` is missing, and steps 1 and 4 give no expected
  status. A response with no `Cache-Control` would pass these assertions, yet a browser may then
  cache it heuristically for longer than 14400. A 403 or a 5xx on `/` would pass step 1 before the
  script exits 2 for "no `/_astro/` URL". **Fix:** require status 200 on steps 1 and 4, and treat a
  missing `Cache-Control` or `max-age` as exit 1.

### Requirements that contradict the living specs

Nothing found. No living spec covers caching or response headers. The only nearby requirement is
`typography`'s font preload and `font-display: swap`, which this change leaves alone. The proposal's
"Modified Capabilities: None" is correct.

### Tasks that use a primitive nobody establishes

Nothing found. The change touches no view, class, or token.

### A missing tier decision

Nothing found. The change adds no interactive UI.

### Unnamed scope

- **Should-fix — `spec.md:45-49` (Requirement "Pages and unhashed files keep a short browser cache
  lifetime").** The requirement covers only "a page, or a file published from `public/`". Other
  unhashed responses fall under neither: `rss.xml` (a stable contract in `config.yaml`), the sitemap,
  and the Markdown twins at `/blog/<slug>/index.md`. The spec therefore sets no limit on them, and a
  later rule could give them a year without contradicting it. **Fix:** word the requirement as
  "every production response outside `/_astro/`", and keep the two scenarios as examples.
- **Should-fix — `infra/cloudflare/README.md:209-211`, not named in `design.md` D3 or `tasks.md` 2.3.**
  The section "Zone-wide configuration belongs to the `domain` module" says "Both zone rulesets use
  `expression = "true"`". Once the new rule is added under
  `starts_with(http.request.uri.path, "/_astro/") and …`, that sentence is false. **Fix:** add this
  correction to D3 and to task 2.3's verification.
- **Should-fix — `design.md:144-148` (R1) and `design.md:165-175` (Migration Plan).** If R1 happens
  (the transform rule does not replace the browser-TTL value), the plan says a fix "needs its own
  change". Until then, every later deploy, including each blog post, ends with a failed Deploy job.
  The `asset-caching` spec would also already be archived (archive runs before merge), and it would
  state a requirement that production does not meet. The plan names no way out of that state.
  **Fix:** add an R1 branch to Migration Plan: revert the squash commit (the rule, the check step,
  and the archived spec), or disable the check step until the follow-up change lands. Name which one
  is chosen. The human can also decide at the gate whether to test the D1 assumption before merge,
  for example with a temporary dashboard rule checked with `curl -sI`.
- **Should-fix — `design.md:152-154` (R3), with `infra/cloudflare/README.md:160-195`.** R3 covers only
  a deploy that runs before the apply. The README records the opposite race: a Pages upload while an
  apply is in flight fails the apply with "Provider produced inconsistent result". The README
  reduces that risk by keeping infra changes on their own commits (`README.md:193-195`), but this
  change squash-merges `infra/cloudflare/` and `deploy.yml` in one commit. When the apply fails that
  way, re-running Deploy does not help, because the rule never went live. **Fix:** extend R3 and
  Migration Plan step 2: if the check fails, first confirm in Terraform Cloud that the apply
  succeeded, and re-run the apply with no deploy in flight before re-running Deploy. Also say whether
  the mixed commit is accepted, and why.

### A `skip_specs` claim that hides a behaviour change

Nothing found. `.openspec.yaml` does not set `skip_specs`, and the change carries a spec delta for
the new capability.

### Nits

- **`design.md:21-23`.** The design leaves open whether the local font provider always passes an
  absolute path. It does: `node_modules/astro/dist/assets/fonts/providers/local.js:31` passes every
  source through `fileURLToPath(...)`, and `fs-font-file-content-resolver.js:9-13` reads the file
  content for an absolute path. So the fonts this site ships get content-hashed names. **Fix:** record
  this as verified, with those two lines as the source. R6 still applies to a future remote provider.
- **`design.md:100`, with `spec.md:19-23`.** The script takes "the first `/_astro/` URL". The scenario
  it follows is about a font under `/_astro/fonts/`. That URL is a font today only because of where
  the preloads sit in the HTML. **Fix:** pick the first `/_astro/fonts/` URL, and exit 2 when there
  is none.
- **`spec.md:5-6` (Purpose).** "a deploy never shows an old page" overstates the change. Requirement 2
  allows a page to be kept for up to 14400 seconds, so a visitor can see an old page for up to
  4 hours after a deploy. **Fix:** "so that repeat views are fast and a deploy never pins an old
  page for longer than the short lifetime".
- **`spec.md:54` and `spec.md:59`.** The scenarios require `max-age=14400` exactly. The requirement
  they illustrate, and the script's assertion (`design.md:99, 104`), both say "at most 14400".
  **Fix:** use one bound in all three places.
- **`spec.md:16-17`.** "a URL under `/_astro/` SHALL NOT serve different content after a deploy" is
  normative, but no check tests it. It is the reason the one-year lifetime is safe. **Fix:** state it
  as rationale ("because …"), or name the check that tests it.
- **`docs/tech-stack.md:54-56`.** This file says the deploy job uploads "and then purges the
  Cloudflare edge cache". After this change the job also runs a production check. The sentence stays
  true but incomplete. Optional: add a short clause that links to the `checks.md` entry. No list of
  checks belongs there.

## Severity summary

- **Blocking (1):** task 1.1 cannot reach its exit-1 verification in the sandbox (Node `fetch`
  ignores the proxy).
- **Should-fix (8):** the age-above-14400 scenario is never exercised by the post-purge run; the
  reload scenario is universal and carries history; step 3 "not run" has no exit code; missing
  `Cache-Control` or a non-200 status is unspecified; requirement 2 leaves `rss.xml`, the sitemap, and
  the twins unconstrained; README line 211 becomes false; there is no exit when R1 happens; R3 omits
  the documented apply race.
- **Nits (6):** font naming is verifiable and now verified; the script should pick a `/_astro/fonts/`
  URL; the Purpose overstates; the 14400 bounds differ; the SHALL about content is untested;
  tech-stack.md is incomplete.

## Verdict

Not ready: fix the task 1.1 and 1.2 sandbox verification (`NODE_USE_ENV_PROXY=1`) first. Fold the
Should-fix items in during the same Update round, then the change is ready for the human's proposal
gate.
