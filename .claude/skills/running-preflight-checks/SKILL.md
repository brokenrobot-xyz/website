---
name: running-preflight-checks
description: Runs the brokenrobot.xyz quality gate — type-check, lint, format-check, spec validation, DESIGN lint, design-token drift, build, the third-party-resource guardrail, and the Terraform check — and summarizes failures. Use before committing a change or handing it to review; the same set CI's Pipeline jobs enforce. This is the non-visual half of Verify; pair it with testing-visual-regression.
compatibility: Requires Node and npm at the package.json engine versions, with dependencies installed. `terraform:check` additionally needs Terraform on PATH (the devcontainer pins 1.15.8 to match CI) and `infra/cloudflare` already initialized.
model: claude-sonnet-5
allowed-tools: Bash
metadata:
    author: brokenrobot.xyz
    version: '3.0'
---

Run the gate from the repo root. Run all nine steps even when one fails — stopping at the first failure hides the rest.

```bash
npm run type:check       # astro check && tsc --noEmit
npm run lint:check       # astro sync && eslint
npm run format:check     # prettier --check
npm run specs:check      # openspec validate --all --strict && openspec validate --archived
npm run designmd:check   # errors fail; warnings and infos are advisory
npm run tokens:check     # drift fix is `npm run tokens:generate`, which the caller runs
npm run build            # astro build — static output
npm run thirdparty:check # scans dist/; exit 2 means dist/ is missing or half-written — report as `not run`
npm run terraform:check  # terraform fmt + validate over infra/cloudflare
```

Report each step as pass/fail from its own exit status. For a failing step, quote its first error, as `file:line` + message where the step reports one. A step that never ran is `not run`, not pass. Open with the overall verdict: red when any step failed or is `not run`. Report failures — do not fix anything; the caller reviews and fixes.

`terraform:check` has two failure modes that are not the caller's code, and both are `not run` rather than `FAIL`: Terraform missing from PATH (exit 127), and `infra/cloudflare` never initialized, which `validate` reports as `Module not installed` with `Run "terraform init" to install all modules required by this configuration`. Fixing the latter is one `terraform -chdir=infra/cloudflare init -backend=false`, which the caller runs — it needs network access to the Terraform registry, so it will not work from a sandboxed shell. Do not report the whole step as `not run` for a `fmt` failure: `fmt` needs no initialization, so it is a real `FAIL`. When the step does run, say what it covers and what it does not: `fmt` and `validate` catch formatting and configuration errors, but no plan runs and the apply belongs to Terraform Cloud, so a change that is valid and wrong still passes.

For example:

```
red — 2 of 9 steps failed

type:check       pass
lint:check       FAIL — src/components/ThemeToggle.tsx:18 — no-floating-promises (3 errors)
format:check     pass
specs:check      pass — 4 specs, 0 failed
designmd:check   pass — 0 errors (2 warnings, advisory)
tokens:check     FAIL — src/styles/tokens.generated.css is stale; run `npm run tokens:generate`
build            pass
thirdparty:check pass — no third-party requests in dist/
terraform:check  pass — fmt + validate clean (no plan; apply is Terraform Cloud's)
```

This gate covers no visual regression or accessibility — a change is not verified until `testing-visual-regression` has also run.
