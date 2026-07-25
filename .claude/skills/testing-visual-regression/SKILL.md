---
name: testing-visual-regression
description: Run and update Playwright visual-regression + axe accessibility checks for brokenrobot.xyz in both light and dark themes. Use at a change's Verify step, when UI snapshots need refreshing after an intentional visual change, or when an a11y check needs to run. Runs inside the devcontainer so rendering matches the committed CI baselines.
metadata:
    author: brokenrobot.xyz
    version: '2.0'
---

Run the site's visual-regression and accessibility coverage in **both themes**, and refresh baselines when a visual change is intentional. This is the automated half of every change's **Verify** step.

## Ground truth

- Config: `playwright.config.ts`. Specs: `tests/`. Snapshot tolerance `maxDiffPixelRatio: 0.01`; shared `tests/screenshot.css`.
- Web server: `npm run serve` (astro preview of `dist/`) on `http://localhost:${BROKENROBOT_PORT}` — it serves the built `dist/`, so a build must precede it (the `test:e2e:*` scripts in Step 3 do this for you). **`BROKENROBOT_PORT` must be set** — a git worktree has no `.env` (it's gitignored), so the commands below default it to `8080`, matching CI.
- Scripts: `npm run test:e2e:check` (run), `npm run test:e2e:update` (regenerate snapshots).
- A11y: `@axe-core/playwright` runs inside the specs — a failure is a real bug, not a baseline to bless.

## Step 1 — Run inside the devcontainer, never on the host

Playwright visual snapshots are **OS-specific** (fonts and anti-aliasing differ), and the committed baselines are **Linux**-rendered (CI runs on `ubuntu-24.04`). Running on the macOS host would mismatch every snapshot at the `0.01` tolerance even when nothing changed — invalid results. So run in the **devcontainer** (`.devcontainer/`, also `ubuntu-24.04`), whose `postCreateCommand` already installs the browsers. There is no host browser install and no `PLAYWRIGHT_BROWSERS_PATH` to manage.

Bring the container up with the `dc:up` script — it and the `test:e2e:*` scripts wrap the pinned `@devcontainers/cli` devDependency over the Docker socket (run `npm ci` on the host first):

```bash
npm run dc:up
```

Notes:

- Building the image the first time fetches features and the base image from `containers.dev` / `ghcr.io` / `mcr.microsoft.com` — all in the sandbox network allow-list, so `dc:up` can build here. Once the container exists, it's reused.
- If the container can't be brought up here, **do not fall back to a host run** — report that the visual coverage must run in the devcontainer or rely on CI's `test` job, and stop.

## Step 2 — Know which themes you can cover

Both themes are first-class, so UI needs coverage in light AND dark. Check `playwright.config.ts` for the dark projects:

- **`Desktop Chrome Dark` / `Pixel 7 Dark` present** → cover both themes.
- **Absent** → they ship with the **`add-dark-theme-test-coverage`** change. Run the light projects (`Desktop Chrome`, `Pixel 7`) and **explicitly report that dark coverage is not wired yet** — never claim both themes passed when only light ran. Note the prerequisite.

## Step 3 — Run the checks

`test:e2e:check` builds inside the container first, then runs the suite — no separate `build` step needed.

```bash
npm run test:e2e:check
```

Reports land in `reports/tests/e2e/` (list, html, json, junit) in the workspace. Read failures from there.

## Step 4 — Update baselines (only for intentional visual changes)

If snapshots fail because the change is deliberate:

1. Open the diffs in `reports/tests/e2e/` and confirm each matches the intended change — never bless a diff you can't explain.
2. Regenerate (in the container, so the new baselines are Linux-rendered and match CI):
   ```bash
   npm run test:e2e:update
   ```
3. Review every updated baseline under `tests/__screenshots__/` (both themes if available) before staging. An a11y failure is **not** fixed by updating snapshots — fix the underlying issue.

## Step 5 — Report

State: which projects/themes ran, pass/fail counts, any contrast or axe failures (with the offending selector/view), whether dark coverage was available, and which baselines you updated and why. If anything is red, report it with the output — don't round up to green.
