# Proposal

## Why

From 4 hours after each deploy until the next deploy, a browser re-checks each font and each image
with the server before it shows the file. The site owner sees the hero image of a blog post reload
on each page refresh. The cause is the zone cache rule: it sends `cache-control: public,
max-age=14400` together with an `age` header that counts from the deploy purge, so a file with an
`age` above 14400 is already expired when it arrives. `browser-measurements.md` in this folder shows
the effect in Chrome, and a `curl -sI` on 2026-09-29 returned `age: 16477` with `max-age=14400` for a
font under `/_astro/`.

The files under `/_astro/` have a hash of their content in their names. A changed file gets a new
name, so a long browser cache lifetime cannot show an old copy.

## What Changes

- Each successful response for a file under `/_astro/` carries
  `Cache-Control: public, max-age=31536000, immutable`. A new rule in the zone's response header
  ruleset in `infra/cloudflare/modules/domain/main.tf` sets this value. The cache rule
  `cache_everything` stays as it is.
- A new production check, run by `deploy.yml` after the purge step, confirms that a file under
  `/_astro/` carries the one-year lifetime and `immutable`, and that the home page does not carry
  `immutable`. The same check runs locally as an npm script.
- `docs/development/checks.md` gets an entry for the new check.
- `infra/cloudflare/README.md`, section "Edge caching hides deployments", is corrected: the browser
  cache lifetime of a page is 4 hours minus the `age` value, not 4 hours, and the per-file-type split
  is adopted for `/_astro/` only, because only `/_astro/` has hashed names.
- `docs/architecture.md`, section "Security headers", states that `Cache-Control` is absent from the
  Cloudflare header ruleset. That sentence becomes false and is corrected.

## Non-Goals

- No change to the edge cache lifetime of one year, and no change to the deploy purge step in
  `.github/workflows/deploy.yml`. The new check is a separate step after the purge.
- No change to the browser cache lifetime of pages and of files from `public/`: they keep
  `max-age=14400`.
- No change to error responses under `/_astro/`: a 404 keeps the current header.
- No change to `nginx.conf` or to `server.headers` in `astro.config.ts`. They serve the container
  and `astro preview`, not production, and both send `max-age=0, must-revalidate` today.
- Images, fonts, preloads, and a page weight budget. A second change covers them after this one.
- The `Permissions-Policy` header, which names four features that Chrome does not recognize.
- The Chrome report that images have no explicit dimensions.
- The known gap "The end-to-end suite runs against a server the site never deploys to" in
  `docs/known-gaps.md` stays open. The new check covers one header on production and does not close
  that gap.

## Capabilities

### New Capabilities

- `asset-caching`: how long a visitor's browser may keep each kind of response from the site
  without asking the server again — content-hashed build files, pages, and files from `public/`.

### Modified Capabilities

None. No existing spec covers caching or response headers.

## Impact

- **Infrastructure:** `infra/cloudflare/modules/domain/main.tf` — one rule added to the ruleset
  `security_and_performance_response_headers`. Terraform Cloud workspace `cloudflare-production`
  applies it; `pipeline.yml` only validates it.
- **CI:** `.github/workflows/deploy.yml` — the deploy job gets a checkout step, a Node setup step, and
  the check step after the purge. The upload and the purge steps do not change.
- **Scripts:** a new script under `scripts/` and a new `:check` entry in `package.json`.
- **Docs:** `docs/development/checks.md`, `infra/cloudflare/README.md`, `docs/architecture.md`.
- **Browsers:** Firefox 49+ and Safari 11+ (iOS included) honor `immutable`. Chrome does not, but
  Chrome serves a fresh subresource from its cache on a normal reload, as the measurements show for
  files with a small `age` value.
- **Other changes:** no change under `openspec/changes/` must merge first. The second change (images,
  fonts, page weight budget) comes after this one and does not exist yet.
