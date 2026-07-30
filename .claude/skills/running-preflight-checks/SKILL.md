---
name: running-preflight-checks
description: Runs the brokenrobot.xyz quality gate — type-check, lint, format-check, spec validation, DESIGN lint, design-token drift, build, and the third-party-resource guardrail — and summarizes failures. Use before committing a change or handing it to review; the same set CI's Verify and Build jobs enforce. This is the non-visual half of Verify; pair it with testing-visual-regression.
compatibility: Requires Node and npm at the package.json engine versions, with dependencies installed.
model: claude-sonnet-5
allowed-tools: Bash
metadata:
    author: brokenrobot.xyz
    version: '3.0'
---

Run the gate from the repo root. Run all eight steps even when one fails — stopping at the first failure hides the rest.

```bash
npm run type:check       # astro check && tsc --noEmit
npm run lint:check       # astro sync && eslint
npm run format:check     # prettier --check
npm run specs:check      # openspec validate --all --strict
npm run designmd:check   # errors fail; warnings and infos are advisory
npm run tokens:check     # drift fix is `npm run tokens:generate`, which the caller runs
npm run build            # astro build — static output
npm run thirdparty:check # scans dist/; exit 2 means dist/ is missing or half-written — report as `not run`
```

Report each step as pass/fail from its own exit status. For a failing step, quote its first error, as `file:line` + message where the step reports one. A step that never ran is `not run`, not pass. Open with the overall verdict: red when any step failed or is `not run`. Report failures — do not fix anything; the caller reviews and fixes. If the change touches `infra/`, note that neither this gate nor CI verifies `infra/`.

For example:

```
red — 2 of 8 steps failed

type:check       pass
lint:check       FAIL — src/components/ThemeToggle.tsx:18 — no-floating-promises (3 errors)
format:check     pass
specs:check      pass — 4 specs, 0 failed
designmd:check   pass — 0 errors (2 warnings, advisory)
tokens:check     FAIL — src/styles/tokens.generated.css is stale; run `npm run tokens:generate`
build            pass
thirdparty:check pass — no third-party requests in dist/
```

This gate covers no visual regression or accessibility — a change is not verified until `testing-visual-regression` has also run.
