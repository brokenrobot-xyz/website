---
name: testing-visual-regression
description: Runs and updates Playwright visual-regression + axe accessibility checks for brokenrobot.xyz in both light and dark themes. Use at a change's Verify step, when UI snapshots need refreshing after an intentional visual change, or when an a11y check needs to run. Runs inside the devcontainer so rendering matches the committed CI baselines.
compatibility: Requires Docker and the @devcontainers/cli devDependency; the first container build needs network access to containers.dev, ghcr.io, and mcr.microsoft.com.
model: claude-sonnet-5
allowed-tools: Bash(npm run:*), Bash(git status:*), Bash(ls:*), Read
metadata:
    author: brokenrobot.xyz
    version: '3.0'
---

Run the site's visual-regression and accessibility coverage in **both themes**, and refresh baselines when a visual change is intentional. This is the visual half of every change's **Verify** step; `running-preflight-checks` is the non-visual half.

Copy this checklist into your reply and tick each item as you go:

```
Visual-check progress:
- [ ] 1. Devcontainer up (never the host)
- [ ] 2. Determine theme coverage
- [ ] 3. Run the checks
- [ ] 4. Update baselines (only if intentional)
- [ ] 5. Report
```

## Ground truth

- Config: `playwright.config.ts`. Specs: `tests/`. Screenshot tolerance `maxDiffPixelRatio: 0.01`.
- Baselines **show** images. Each screenshot test awaits `settleImages(page)` (`tests/settleImages.ts`) before capturing: it forces `loading="lazy"` images eager, awaits `decode()`, then `document.fonts.ready`. Do not reintroduce a `stylePath` stylesheet to hide elements — the CSP blocks injected styles, so the masking fails silently and every image-bearing baseline drifts.
- Web server: `npm run serve` (astro preview of `dist/`) on `http://localhost:${BROKENROBOT_PORT}` — it serves the built `dist/`, so a build must precede it (the `test:e2e:*` scripts in Step 3 do this for you). `playwright.config.ts` reads `BROKENROBOT_PORT`, and a git worktree has no `.env` file (it is gitignored), so the `test:e2e:*` scripts default the port to `8080`, matching CI — you do not need to set it.
- Scripts: `npm run test:e2e:check` (run), `npm run test:e2e:update` (regenerate baselines).
- A11y: `@axe-core/playwright` runs inside the specs — a failure is a real bug, not a baseline to bless.

## Step 1 — Run inside the devcontainer, never on the host

Playwright screenshots are **OS-specific** (fonts and anti-aliasing differ), and the committed baselines are **Linux**-rendered (CI runs on `ubuntu-24.04`). A run on the macOS host would mismatch every baseline at the `0.01` tolerance even when nothing changed — invalid results. So run in the devcontainer (`.devcontainer/`, also `ubuntu-24.04`), whose `postCreateCommand` installs the browsers. There is no host browser install and no `PLAYWRIGHT_BROWSERS_PATH` to manage.

The `dc:up` and `test:e2e:*` scripts wrap the pinned `@devcontainers/cli` devDependency over the Docker socket:

1. Install the host dependencies, because `@devcontainers/cli` ships as a devDependency and `dc:up` fails without it:
    ```bash
    npm ci
    ```
2. Bring the container up. Once the container exists, later runs reuse it:
    ```bash
    npm run dc:up
    ```
3. When `dc:up` fails, **do not fall back to a host run**, because a host run reports mismatches that read as real regressions. Report that the visual coverage must run in the devcontainer or rely on CI's `test` job, and stop.

Note: building the image the first time fetches features and the base image from `containers.dev`, `ghcr.io`, and `mcr.microsoft.com` — all in the sandbox network allow-list, so `dc:up` can build here.

## Step 2 — Know which themes you can cover

Both themes are first-class, so UI needs coverage in light AND dark. Read `playwright.config.ts` for the dark projects:

- **`Desktop Chrome Dark` / `Pixel 7 Dark` present** → cover both themes.
- **Absent** → the dark projects are not wired yet. Run the light projects (`Desktop Chrome`, `Pixel 7`) and **explicitly report that dark coverage is unavailable**. Never claim both themes passed when only light ran, because the human at the review gate reads your report as the evidence that both themes were checked.

## Step 3 — Run the checks

`test:e2e:check` builds inside the container first, then runs the suite — no separate `build` step needed.

```bash
npm run test:e2e:check
```

Playwright writes its reports to `reports/tests/e2e/` through the `list`, `html`, `json`, and `junit` reporters; the `github` reporter writes CI annotations rather than files. Read failures from `reports/tests/e2e/json/test-results.json`, not from recollection of the console output.

## Step 4 — Update baselines (only for intentional visual changes)

When a screenshot test fails because the change is deliberate:

1. Open the diffs in `reports/tests/e2e/` and confirm each one matches the intended change. Never bless a diff you cannot explain, because an unexplained diff is an unnoticed regression entering the baselines. Surface those diffs to the user instead.
2. Regenerate in the container, so the new baselines are Linux-rendered and match CI:
    ```bash
    npm run test:e2e:update
    ```
3. List what the regeneration actually changed, so the review in the next item covers the real set rather than the set you expected:
    ```bash
    git status --short tests/__screenshots__/
    ```
4. Review every baseline that command lists (both themes when the dark projects are wired) before you stage anything.

An axe failure is **not** fixed by regenerating baselines — fix the underlying issue, because a regenerated baseline records the bug instead of removing it.

## Step 5 — Report

Open with the overall verdict: red when any project failed, when any axe violation fired, or when the change touches UI and dark coverage was unavailable. Then state which projects ran, pass/fail counts, each axe violation with its rule and the offending selector and view, and every baseline you updated with the reason you updated it. If anything is red, report it with the output — do not round up to green.

For example:

```
red — 1 of 2 projects failed; dark coverage unavailable

Desktop Chrome   FAIL — 10 of 11 screenshots — pages/about-page.spec.ts: heading margin (matches the spacing change you described)
Pixel 7          pass — 11 of 11 screenshots
axe              FAIL — color-contrast on `.post-meta`, about page (Desktop Chrome)
dark projects    not run — Desktop Chrome Dark / Pixel 7 Dark are not configured in playwright.config.ts

Baselines updated: none — the axe failure is a real bug, and the about-page diff waits on your confirmation.
```

`running-preflight-checks` covers the non-visual half of Verify; a change is not verified until both have run.
