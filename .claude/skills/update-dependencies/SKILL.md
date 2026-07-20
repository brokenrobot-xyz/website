---
name: update-dependencies
description: Update npm dependencies in package.json for brokenrobot.xyz — detect what's outdated, bucket into patch/minor/major, apply patches automatically, and research minor/major bumps before recommending them. Use when refreshing dependencies. Applies patches directly then verifies; gates minor/major on your approval after research. Delegates verification to preflight-checks and visual-regression-tests.
metadata:
    author: brokenrobot.xyz
    version: '1.0'
---

Refresh the repo's npm dependencies safely. Patches are low-risk and applied directly; minor and major bumps are researched first (by the `dependency-update-researcher` subagent) and applied only after you approve. Deps are **exact-pinned** here (`.npmrc` `save-exact=true`) — every update preserves that.

> Guardrails: preserve exact pinning — always install with `--save-exact`, never introduce `^`/`~`. Never edit unrelated files or downgrade to make a check pass. You **cannot** `git push` or use `gh` (sandbox-denied) — stage and commit locally only; the human pushes.

## Step 1 — Detect

From the repo root:

```bash
npm outdated --json
```

`npm outdated` exits non-zero when anything is outdated — that's expected, not a failure. If the output is empty, report "everything is current" and stop.

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
- `npm run audit:check` — security advisories against the updated lockfile.
- The **`visual-regression-tests`** skill **only if** the applied set touches a rendering-affecting package: `astro`, `@astrojs/*`, `preact`, `tailwindcss`, `@tailwindcss/*`, `@fontsource/*`, `@astrojs/mdx`/mdx, `autoprefixer`, `postcss*`. (Runs in the devcontainer — heavier; skip with a note otherwise.)

If a category fails verification, **do not commit it**. Report the failing step and the offending package so it can be pinned back or migrated, and keep the passing categories separate.

## Report

Summarize:

- **Applied** per category, with `<pkg> <old> → <new>` and the commit created for each.
- **Deferred / rejected** — minor/major the user chose not to apply, with the research verdict and why.
- **Verification** — pass/fail per category (preflight, audit, and visual regression if it ran).
- A reminder that **nothing was pushed** — the commits are local for the human to push / open a PR.

Don't reformat or edit unrelated files. Flag pre-existing noise (e.g. `format:check` on out-of-scope files) separately rather than "fixing" it.
