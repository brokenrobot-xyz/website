# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Behavioral guidelines

Behavioral guidelines to reduce common LLM coding mistakes.

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

### Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for scenarios made impossible by prior validation or domain invariants.
- Do validate untrusted inputs at system boundaries: HTTP requests, persistence queries, environment variables, external APIs, and migrations.
- If you write 200 lines, and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:

- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

### Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

## Project documentation

Read these before working on the design overhaul — they are the shared source of truth:

- [docs/vision.md](docs/vision.md) — why the site exists, audience, overhaul goals, and guardrails.
- [docs/brand.md](docs/brand.md) — "Broken Robot" personality, voice, mascot, and directional visual proposals.
- [docs/tech-stack.md](docs/tech-stack.md) — frameworks, dependencies, scripts, build & deploy.
- [docs/development-environment.md](docs/development-environment.md) — machine setup: Node/npm versions, install, host vs. devcontainer, the required global LSP tools, worktrees, and editor setup.
- [docs/architecture.md](docs/architecture.md) — code structure, content model, and theming guidance.
- [docs/development/conventions/coding-conventions.md](docs/development/conventions/coding-conventions.md) — TypeScript, formatting, Astro patterns, and testing rules.
- [docs/development/conventions/commit-conventions.md](docs/development/conventions/commit-conventions.md) — Conventional Commits and commit message guidance.
- [docs/development-workflow.md](docs/development-workflow.md) — the way we work: spec-driven planning + scaled trunk-based development (the tool-agnostic _what_); writing blog articles is out of scope.

Those cover the **application**. For how this repo is worked on with Claude Code — the agent/skill workflow and the sandbox (why git in worktrees and Docker behave as they do) — see [docs/tooling/](docs/tooling/README.md), in particular [docs/tooling/sandbox.md](docs/tooling/sandbox.md).
