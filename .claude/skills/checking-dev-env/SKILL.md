---
name: checking-dev-env
description: Checks whether this machine is ready to develop brokenrobot.xyz — toolchain versions against the pins (including the global openspec CLI), dependencies, the Codegraph index, Claude Code integration (typescript-lsp plugin, codegraph MCP, node version manager), and Docker/devcontainer availability — and turns any failure into an ordered, hand-holding setup guide with exact commands. Use when setting up a new machine or worktree, when the SessionStart report shows ✗ lines, or when builds or tools misbehave and the environment is suspect. Diagnoses only, never installs or changes anything; pair with running-preflight-checks for the code-quality half.
compatibility: Requires bash to run the scan script; every tool it probes may legitimately be absent, which is a finding rather than a failure. Without jq the codegraph and Claude Code integration areas report "not checked" instead of a verdict, and the openspec check falls back to presence-only.
allowed-tools: Read Bash Skill
model: claude-sonnet-5
context: fork
agent: general-purpose
background: false
metadata:
    author: brokenrobot.xyz
    version: '1.4'
---

Audit this checkout's development environment and, when anything is missing, hand the user an
ordered guide. The diagnostics are the same probes the `SessionStart` hook runs — one
implementation, `.claude/hooks/lib/dev-env-checks.sh` — and every remediation comes from the
Troubleshooting section of [docs/development-environment.md](../../../docs/development-environment.md),
so the guide can never drift from the docs.

## Guardrails

**Diagnose and guide, never fix.** Do not run `npm install` / `npm ci`, `npm i -g …`,
`codegraph init|index|sync`, or `npm run dc:up`. Do not edit any file or setting. An install this
skill runs itself mutates the machine outside the repo and hides the defect that caused it, so the
next fresh checkout breaks the same way with no record of why. Print every fix for the user to run
instead. The only commands this skill executes are the read-only scan in Step 1 and, through
`running-preflight-checks`, the quality gate.

Copy this checklist into your reply and tick each item as you go:

```
Check progress:
- [ ] 1. Quick scan (read-only)
- [ ] 2. Quality gate — run, or skip with the reason stated
- [ ] 3. Build the guide from the doc's Troubleshooting entries
- [ ] 4. Report — ready or not, the guide, nothing changed
```

## Step 1 — Quick scan

From the repo root:

```bash
bash .claude/hooks/lib/dev-env-checks.sh
```

One ✓/✗ line per area — toolchain, dependencies, codegraph index, Claude Code integration,
containers — exiting non-zero when anything needs attention. Keep the output verbatim for the
report; the ✗ lines are the keys into the doc's Troubleshooting entries.

## Step 2 — The quality gate, only when it can tell you something

When Step 1 was all-✓, or when the user explicitly asked for the gate to run anyway, delegate to
the `running-preflight-checks` skill — it owns the gate's step list and already knows how to read
its failures. Otherwise skip the gate and say so: a build on a broken toolchain fails for the wrong
reasons. Do not rerun `npm run codegraph:status` here, because Step 1's codegraph probe already is
that check.

When the user asked for the gate over a red Step 1, run it and report environment failures and gate
failures as separate lists — a gate failure on a broken environment is expected noise, not a
finding.

## Step 3 — Build the guide

For every ✗ line, find the `### ✗ …` entry in the Troubleshooting section of
[docs/development-environment.md](../../../docs/development-environment.md) whose heading matches
the line's prefix, and take the fix from there. When that entry names a command, quote it. When it
links to another section of the same doc instead — `✗ node missing` points at § Node version
management, `✗ docker missing` at § Host vs. devcontainer — follow the link and take the command
from the section it names. A guide item that repeats the pointer has not answered the ✗ line.

**Never invent a remediation.** A command absent from the doc has not been tested against this
checkout, and a wrong fix costs the user more than an unanswered ✗ line. When no Troubleshooting
entry matches, say exactly that and reference the doc as a whole rather than improvising.

Order the guide dependency-first: git/jq → version manager → Node → npm/dependencies → global
language server → global openspec CLI → codegraph index → Claude Code configuration → Docker →
committed-pin drift (codegraph pins). Then tailor the guide. Drop every area already ✓. Skip
alternatives the scan disproved: when the scan detected asdf, do not suggest installing fnm.

## Report

State, in this order:

- **Ready or not.** All ✓ and a green quality gate → "environment ready", naming both the scan and
  the gate. Never claim ready from Step 1 alone: when this skill skipped the gate, or the user
  declined it, say so and why.
- **The guide**, when anything failed: one numbered item per ✗ line, ending with "re-run
  `checking-dev-env` after applying the fixes".
- **That nothing was changed** — this skill only read and reported.

Each guide item carries the symptom line verbatim, the command from the doc, and the re-verify
command for that area from § Verify of the same doc:

```
3. ✗ typescript-language-server missing — the typescript-lsp plugin has no server and
   silently degrades

   Fix:       npm i -g typescript-language-server typescript
   Re-verify: typescript-language-server --version
```

When § Verify carries no command for an area, re-running Step 1's scan is that area's re-verify
step.
