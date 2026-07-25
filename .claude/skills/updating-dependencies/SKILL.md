---
name: updating-dependencies
description: Update npm dependencies in package.json for brokenrobot.xyz — detect what's outdated, bucket into patch/minor/major, apply patches automatically, and research minor/major bumps before recommending them. Use when refreshing dependencies. Applies patches directly then verifies; gates minor/major on your approval after research. Delegates verification to running-preflight-checks and testing-visual-regression.
model: sonnet
metadata:
    author: brokenrobot.xyz
    version: '1.4'
---

Refresh the repo's npm dependencies safely. Patches are low-risk and applied directly; minor and major bumps are researched first (by the `dependency-update-researcher` subagent) and applied only after you approve. Deps are **exact-pinned** here (`.npmrc` `save-exact=true`) — every update preserves that.

> Guardrails: preserve exact pinning — always install with `--save-exact`, never introduce `^`/`~`. Never edit unrelated files or downgrade to make a check pass. You **cannot** `git push` or use `gh` (sandbox-denied) — stage and commit locally only; the human pushes.

## Workflow checklist

This is a long, stateful run with an approval gate in the middle. Copy this checklist into your response and tick items off as you complete them so no step is skipped:

```
Update Progress:
- [ ] Step 1: Detect (npm outdated) + snapshot audit baseline (audit-diff.mjs snapshot)
- [ ] Step 2: Categorize into patch / minor / major (show the table)
- [ ] Step 3: Apply patches → verify → commit
- [ ] Step 4: Research each minor/major (one subagent per package) → recommendation table → STOP for approval
- [ ] Step 5a: Apply approved minors → verify → commit
- [ ] Step 5b: Apply approved majors → verify → commit
- [ ] Report (nothing pushed)
```

"Verify" always means the **Verification procedure** section at the end.

## Step 1 — Detect

From the repo root:

```bash
npm outdated --json
```

`npm outdated` exits non-zero when anything is outdated — that's expected, not a failure. If the output is empty, report "everything is current" and stop.

**Snapshot the security baseline now, before changing anything.** `npm audit` reports the _whole_ tree's advisories, most of which pre-date this update and are not its fault. Record the baseline so verification can attribute only _new_ advisories to the bump:

```bash
node .claude/skills/updating-dependencies/scripts/audit-diff.mjs snapshot
```

This writes the advisory IDs present at HEAD to a file (in the OS temp dir); the `diff` mode in the Verification procedure reads it back — no need to carry the IDs yourself.

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

This updates `package.json` (exact) and `package-lock.json`. When all patches are applied, verify (see Verification procedure), then commit:

```bash
git add package.json package-lock.json
git commit -m "chore(deps): update patch-level dependencies"
```

If verification fails, do **not** commit.

## Step 4 — Minor & major: research first

Minor and major bumps run as a **plan → approve → execute → verify** gate: research is the plan, the user's approval is the validation, Step 5 executes, the Verification procedure verifies. Never skip straight to the install.

Do not apply these yet. Spawn one **`dependency-update-researcher`** subagent per minor/major package, in parallel (batch sensibly if there are many). Give each: package name, current version, target (`latest`), and category.

Collect the verdicts and present a consolidated recommendation table — **then stop and await approval**:

| Package | Jump | Verdict | Breaking changes (affects us?) | Required edits |
| --- | --- | --- | --- | --- |

`compatible` = drop-in; `needs-changes` = safe once the listed edits are made; `risky` = breaking changes hit us with no clean migration. Recommend, but let the user decide what to apply.

## Step 5 — Apply approved minor/major (one category at a time)

Run minors first (5a), then majors (5b) — each category as its own apply → verify → commit cycle, so a regression cleanly identifies which category caused it. Per category:

1. For each approved package: `npm install <pkg>@<latest> --save-exact`
2. Make any code migrations the research flagged (`needs-changes`).
3. Verify (see Verification procedure).
4. Commit — `git add package.json package-lock.json` plus any migration-edited files, then:

```bash
git commit -m "chore(deps): update minor dependencies"   # 5a
git commit -m "chore(deps): update major dependencies"   # 5b
```

## Verification procedure — run before each category's commit

Run this as a **feedback loop**: run the checks → if a regression appears, fix it (or pin the offending package back) → re-run → only commit the category once it passes (or only pre-existing failures remain). Before committing a category, run:

- The **`running-preflight-checks`** skill — type-check, lint, format-check, build.
- **The audit diff against the Step 1 baseline** — do _not_ read the raw advisory count as pass/fail; a non-zero count is almost always pre-existing noise:

    ```bash
    node .claude/skills/updating-dependencies/scripts/audit-diff.mjs diff
    ```

    It prints `new` / `resolved` / `preExisting` and exits non-zero only when `new` is non-empty:
    - **`new`** → **introduced by this update**. The only audit result that **blocks the commit**. Report the advisory ID, severity, and which updated package pulled it in.
    - **`resolved`** → a security win the update delivered. Note it in the report.
    - **`preExisting`** → **not this update's fault; does not block.** Report as informational baseline noise, not a verification failure.
- The **`testing-visual-regression`** skill **only if** the applied set touches a rendering-affecting package: `astro`, `@astrojs/*`, `preact`, `tailwindcss`, `@tailwindcss/*`, `@fontsource/*`, `@astrojs/mdx`/mdx, `autoprefixer`, `postcss*`. (Runs in the devcontainer — heavier; skip with a note otherwise.)

Block a category's commit only on a **regression this update caused** — a failing preflight step or a **new** audit advisory. Pre-existing failures (a baseline advisory, or a check already red at HEAD) must **not** block the commit; report them separately as pre-existing. When a real regression blocks a category, report the failing step and offending package so it can be pinned back or migrated, and keep the passing categories separate.

## Report

Summarize:

- **Applied** per category, with `<pkg> <old> → <new>` and the commit created for each.
- **Deferred / rejected** — minor/major the user chose not to apply, with the research verdict and why.
- **Verification** — pass/fail per category (preflight and visual regression if it ran). For **audit**, report the baseline diff: advisories **introduced** (blocking), **resolved** (a win), and **pre-existing** (informational) — never the raw count alone.
- A reminder that **nothing was pushed** — the commits are local for the human to push / open a PR.

Don't reformat or edit unrelated files. Flag pre-existing noise (e.g. `format:check` on out-of-scope files) separately rather than "fixing" it.
