# Tasks

## 1. Production cache header check

- [ ] 1.1 Write `scripts/check-production-cache-headers.mjs` with the five steps, the messages, and
      the exit codes in design.md D2. Use Node built-ins only. Add a `prodcache:check` script to
      `package.json` next to the other `:check` scripts, running
      `node scripts/check-production-cache-headers.mjs`. Verify: `npm run prodcache:check` against
      production today exits 1, and its output names a `/_astro/` URL with `max-age=14400` and no
      `immutable`. Record that output in the change's `retrospective.md`: it is the before-state of
      the spec scenario "A font under `/_astro/` carries the long lifetime".
- [ ] 1.2 Verify the exit code 2 path: run the script with the network unavailable (for example in
      the sandbox without the production host allowed) and confirm it exits 2 and reports that the
      check did not run, not that a header is wrong.
- [ ] 1.3 Add a "Production" category to `docs/development/checks.md` with a `prodcache:check`
      section: what it inspects, the local command, that `deploy.yml` runs it after the purge, the
      exit codes, why it exists (the e2e suite cannot see Cloudflare rules), and that it is not part of
      the preflight gate. Add one sentence to "The CI pipeline" section that `deploy.yml` runs it.
      State no count of checks. Verify: `npm run format:check` passes, and no other file in this
      change lists the check.

## 2. Cloudflare rule

- [ ] 2.1 Add the second rule of design.md D1 to the ruleset
      `security_and_performance_response_headers` in `infra/cloudflare/modules/domain/main.tf`, after
      the existing rule, with a short comment that says why the rule is limited to `/_astro/` and to
      status 200 and 304. Leave the ruleset `cache_everything` unchanged. Verify:
      `npm run terraform:check` passes, and `git diff` shows no change inside `cache_everything`.
- [ ] 2.2 Verify that `npm run headers:check` still passes. It reads the first
      `Content-Security-Policy` block in `main.tf`, and the new rule must not contain one.
- [ ] 2.3 Correct `infra/cloudflare/README.md`, section "Edge caching hides deployments", as design.md
      D3 describes: the page lifetime is `14400` minus the `age` value, `/_astro/` gets one year plus
      `immutable`, and the per-file-type paragraph says which part is adopted and why `public/` stays
      short. Verify: the section no longer says that a visitor keeps the site for up to four hours,
      and it no longer rejects the split for `/_astro/`.
- [ ] 2.4 Correct the `Cache-Control` sentence in `docs/architecture.md`, section "Security headers",
      as design.md D3 describes. Verify: the sentence names both rulesets and which responses each one
      covers.

## 3. Deploy workflow

- [ ] 3.1 In `.github/workflows/deploy.yml`, add three steps after "Purge the Cloudflare cache":
      `actions/checkout` and `actions/setup-node` with the same pinned SHAs and
      `node-version-file: '.node-version'` as `pipeline.yml`, then `npm run prodcache:check`. Add a
      comment that the check can fail on the first deploy of an infra change when Terraform Cloud has
      not applied yet, and that re-running the job is the fix. Verify: `git diff` shows no change to
      the trigger, the download, the upload, or the purge step, and `npm run format:check` passes on
      the workflow file.

## 4. Verify

- [ ] Visual + a11y snapshots pass in **both themes** for every touched view (testing-visual-regression skill) — N/A for views: the change touches no page, component, or style. The suite still runs as a regression check.
- [ ] All preflight gate checks pass — the set in `docs/development/checks.md` (running-preflight-checks skill)
- [ ] Manual preview: no theme flash, interactions work, console clean, responsive at 375px — N/A for new behavior: `astro preview` does not apply the Cloudflare rules, so the change is not visible there. Production acceptance happens after deploy (design.md, Migration Plan).
