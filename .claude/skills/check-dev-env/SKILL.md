---
name: check-dev-env
description: Checks whether this machine is ready to develop brokenrobot.xyz — toolchain versions against the pins, dependencies, the Codegraph index, Claude Code integration (typescript-lsp plugin, codegraph MCP, node version manager), and Docker/devcontainer availability — and turns any failure into an ordered, hand-holding setup guide with exact commands. Use when setting up a new machine or worktree, when the SessionStart report shows ✗ lines, or when builds or tools misbehave and the environment is suspect. Diagnoses only, never installs or changes anything; pair with preflight-checks for the code-quality half.
allowed-tools: Read, Bash, Skill
metadata:
    author: brokenrobot.xyz
    version: '1.0'
---

Audit this checkout's development environment and, when anything is missing, hand the user an
ordered fix guide. The diagnostics are the same probes the `SessionStart` hook runs — one
implementation, `.claude/hooks/lib/dev-env-checks.sh` — and every remediation comes from the
Troubleshooting section of [docs/development-environment.md](../../../docs/development-environment.md),
so the guide can never drift from the docs.

> Guardrails: **diagnose and guide, never fix.** Do not run `npm install` / `npm ci`,
> `npm i -g …`, `codegraph init|index|sync`, `npm run dc:up`, or edit any file or setting — every
> fix is printed for the user to run themselves. The only commands this skill executes are the
> read-only scan below and, via `preflight-checks`, the verify suite.

## Step 1 — Quick scan

From the repo root:

```bash
bash .claude/hooks/lib/dev-env-checks.sh
```

One ✓/✗ line per area — toolchain, dependencies, codegraph index, Claude Code integration,
containers — exiting non-zero when anything needs attention. Keep the output verbatim for the
report; the ✗ lines are the keys into the doc's Troubleshooting entries.

## Step 2 — Deep verify, only when it can tell you something

Run the verify suite when Step 1 was all-✓, or when the user explicitly asked for a full check.
Otherwise skip it and say so — a build on a broken toolchain fails for the wrong reasons. Don't
rerun `npm run codegraph:status` here; Step 1's codegraph probe already is that check.

Delegate to the `preflight-checks` skill: it is the repo's quality gate (type-check, lint,
format-check, build) and already knows how to read its failures. On an explicit full check over a
red Step 1, run it anyway but report environment failures and gate failures separately — a gate
failure on a broken environment is expected noise, not a finding.

## Step 3 — Build the guide

For every ✗ line, find the `### ✗ …` entry in the Troubleshooting section of
[docs/development-environment.md](../../../docs/development-environment.md) whose heading matches
the line's prefix, and take the fix from there — **never invent a remediation**. If no entry
matches, say exactly that and point at the doc as a whole rather than improvising.

Order the guide dependency-first — version manager → Node → npm/dependencies → global language
server → codegraph → Claude Code configuration → Docker — and tailor it: drop everything already
✓, and skip alternatives the scan disproved (don't suggest installing fnm when asdf was
detected).

## Report

State, in this order:

- **Ready or not.** All ✓ and the verify suite green → "environment ready", naming both tiers.
  Never claim ready from Step 1 alone — if the suite was skipped or declined, say so and why.
- **The guide**, when anything failed: one numbered item per ✗ — the symptom line verbatim, the
  fix from the doc, and how to re-verify that item — ending with "re-run `check-dev-env` after
  applying the fixes".
- **That nothing was changed** — this skill only read and reported.
