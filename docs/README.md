# Documentation

The shared source of truth for brokenrobot.xyz — why the site exists, how it should look and
feel, and how the code is built. Read these before working on the design overhaul.

- [vision.md](vision.md) — why the site exists, who it's for, where it's heading, and the
  enduring principles it upholds.
- [brand.md](brand.md) — the "Broken Robot" personality, voice, mascot, and directional
  visual proposals.
- [tech-stack.md](tech-stack.md) — the shape of the stack, build & deployment, and what it
  means for the overhaul.
- [development-environment.md](development-environment.md) — set up a machine to work on the site:
  Node/npm versions, install, host vs. devcontainer, the global LSP tools, worktrees, and editor setup.
- [architecture.md](architecture.md) — code structure, content model, and theming guidance.
- [coding-conventions.md](development/conventions/coding-conventions.md) — TypeScript, formatting, Astro patterns,
  and testing rules.
- [commit-conventions.md](development/conventions/commit-conventions.md) — Conventional Commits and commit message
  guidance.
- [branching-conventions.md](development/conventions/branching-conventions.md) — branch naming, worktrees, the
  human-only push gate, squash-merging, and what CI does with branches.
- [development-workflow.md](development-workflow.md) — the way we work: spec-driven planning +
  scaled trunk-based development (and why writing blog articles is out of scope). Tool-agnostic; the
  mechanics live in [tooling/workflow.md](tooling/workflow.md).
- [checks.md](development/checks.md) — every automated check: what it inspects, how to run it, and
  why it exists. The only place they are listed.
- [design-md-assessment.md](design-md-assessment.md) — evaluation of Google Labs' DESIGN.md format
  for this repo: fit, benefits, tradeoffs, the dual-theme catch, and a recommended PoC.

These describe the **application**. For how the repository is _worked on_ with Claude Code — the
agent/skill workflow and the sandbox that constrains it — see [tooling/](tooling/README.md).
