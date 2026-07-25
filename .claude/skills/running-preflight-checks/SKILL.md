---
name: running-preflight-checks
description: Run the brokenrobot.xyz quality gate — type-check, lint, format-check, and build — and summarize failures. Use before committing a change or handing it to review, to catch type/lint/format/build errors in one pass. This is the non-visual half of Verify; pair it with testing-visual-regression.
metadata:
    author: brokenrobot.xyz
    version: '1.0'
---

Run the full non-visual quality gate and report a clean summary. This is the static half of a change's **Verify** step (the visual + a11y half is the `testing-visual-regression` skill).

## The gate

Run these from the repo root, in order:

```bash
npm run type:check     # astro check && tsc --noEmit
npm run lint:check     # astro sync && eslint 'src/**/*.{astro,ts,tsx}'
npm run format:check   # prettier --check on the full glob
npm run build          # astro build — static output
```

- To auto-fix formatting instead of just checking: `npm run format:fix`.
- `lint:check` runs `astro sync` first, so generated types are current.

## What to check in the output

- **type:check** — zero errors. Strictest config: no `any`, strict null/boolean checks.
- **lint:check** — zero errors. Covers `.astro`, `.ts`, `.tsx` (incl. `<script>` blocks via the `*.astro/*.ts` override) with the import-order and jsx-a11y rules.
- **format:check** — clean. Known noise: it may flag `.claude/settings.json`, which is pre-existing and out of scope — call that out rather than "fixing" unrelated files.
- **build** — succeeds, **and** sanity-check the result honors the guardrails: no third-party font/script requests, no CSP violations, output is static.

## Report

Summarize each step as pass/fail with the first real error per failing step (file:line + message). If everything passes, say so plainly. Don't reformat or edit unrelated files to make a step go green — fix only what the change introduced, and flag pre-existing noise separately.

> Scope note: this gate does not cover visual regression or accessibility. A change isn't verified until `testing-visual-regression` has also run (in both themes where the dark Playwright projects exist).
