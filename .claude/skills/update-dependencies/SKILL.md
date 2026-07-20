---
name: update-dependencies
description: Update npm dependencies in package.json for brokenrobot.xyz — detect what's outdated, bucket into patch/minor/major, apply patches automatically, and research minor/major bumps before recommending them. Use when refreshing dependencies. Applies patches directly then verifies; gates minor/major on your approval after research. Delegates verification to preflight-checks and visual-regression-tests.
metadata:
    author: brokenrobot.xyz
    version: '1.1'
---

Refresh the repo's npm dependencies safely. Patches are low-risk and applied directly; minor and major bumps are researched first (by the `dependency-update-researcher` subagent) and applied only after you approve. Deps are **exact-pinned** here (`.npmrc` `save-exact=true`) — every update preserves that.

> Guardrails: preserve exact pinning — always install with `--save-exact`, never introduce `^`/`~`. Never edit unrelated files or downgrade to make a check pass. You **cannot** `git push` or use `gh` (sandbox-denied) — stage and commit locally only; the human pushes.

## Step 1 — Detect

From the repo root:

```bash
npm outdated --json
```

`npm outdated` exits non-zero when anything is outdated — that's expected, not a failure. If the output is empty, report "everything is current" and stop.

**Snapshot the security baseline now, before changing anything.** `npm audit` reports the _whole_ tree's advisories, most of which pre-date this update and are not its fault. Capture the current advisory set so Step 6 can diff against it and attribute only _new_ advisories to the bump:

```bash
npm audit --package-lock-only --omit=dev --json   # baseline: record the advisory IDs (GHSA/CVE) present at HEAD
```

Save that set of advisory IDs — it's the "already there" list. (`npm run audit:check` is the same audit without `--json`; use the JSON form here so you have IDs to compare.)

## Step 2 — Categorize

Bucket each package by the semver diff of `current` → `latest` into **patch**, **minor**, or **major**. Because deps are exact-pinned, `wanted` equals `current`; always target `latest`. Present the three buckets as a table before touching anything:

| Package | Current → Latest | Category | Dep type |
| --- | --- | --- | --- |

(Note prod `dependencies` vs `devDependencies` — it informs risk.)

## Step 3 — Patch: apply directly

Patches need no research. For each patch package:

```bash
npm install <pkg>@<latest> --save-exact
```

This updates `package.json` (exact) and `package-lock.json`. When all patches are applied, verify (Step 6), then commit:

```bash
git commit -am "chore(deps): update patch-level dependencies"
```

If verification fails, do **not** commit — see Step 6.

## Step 4 — Minor & major: research first

Do not apply these yet. Spawn one **`dependency-update-researcher`** subagent per minor/major package, in parallel (batch sensibly if there are many). Give each: package name, current version, target (`latest`), and category.

Collect the verdicts and present a consolidated recommendation table — **then stop and await approval**:

| Package | Jump | Verdict | Breaking changes (affects us?) | Required edits |
| --- | --- | --- | --- | --- |

`compatible` = drop-in; `needs-changes` = safe once the listed edits are made; `risky` = breaking changes hit us with no clean migration. Recommend, but let the user decide what to apply.

## Step 5 — Apply approved minor/major

For each package the user approves:

```bash
npm install <pkg>@<latest> --save-exact
```

Then make any code migrations the research flagged (`needs-changes`). Verify (Step 6). Commit minor and major as **separate** commits:

```bash
git commit -am "chore(deps): update minor dependencies"
git commit -am "chore(deps): update major dependencies"
```

## Step 6 — Verify (per category, before its commit)

Before committing a category, run:

- The **`preflight-checks`** skill — type-check, lint, format-check, build.
- **`npm run audit:check`, then diff against the Step 1 baseline.** Do _not_ read the raw advisory count as pass/fail — a non-zero count is almost always pre-existing noise. Classify each advisory:
    - **New** (present now, absent from the baseline) → **introduced by this update**. This is the only audit result that **blocks the commit**. Report the advisory ID, severity, and which updated package pulled it in.
    - **Resolved** (in the baseline, gone now) → a security win the update delivered. Note it in the report.
    - **Unchanged pre-existing** (in both) → **not this update's fault; does not block.** Report as informational baseline noise, not a verification failure.
- The **`visual-regression-tests`** skill **only if** the applied set touches a rendering-affecting package: `astro`, `@astrojs/*`, `preact`, `tailwindcss`, `@tailwindcss/*`, `@fontsource/*`, `@astrojs/mdx`/mdx, `autoprefixer`, `postcss*`. (Runs in the devcontainer — heavier; skip with a note otherwise.)

Block a category's commit only on a **regression this update caused** — a failing preflight step or a **new** audit advisory. Pre-existing failures (a baseline advisory, or a check already red at HEAD) must **not** block the commit; report them separately as pre-existing. When a real regression blocks a category, report the failing step and offending package so it can be pinned back or migrated, and keep the passing categories separate.

## Report

Summarize:

- **Applied** per category, with `<pkg> <old> → <new>` and the commit created for each.
- **Deferred / rejected** — minor/major the user chose not to apply, with the research verdict and why.
- **Verification** — pass/fail per category (preflight and visual regression if it ran). For **audit**, report the baseline diff: advisories **introduced** (blocking), **resolved** (a win), and **pre-existing** (informational) — never the raw count alone.
- A reminder that **nothing was pushed** — the commits are local for the human to push / open a PR.

Don't reformat or edit unrelated files. Flag pre-existing noise (e.g. `format:check` on out-of-scope files) separately rather than "fixing" it.
