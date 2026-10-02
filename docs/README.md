# Documentation

The map of this repository's documents: what each one holds, and when to open it. `AGENTS.md`
pulls this file into every Claude Code session, so this is the one map, and there is no second
list to keep in step with it.

## The site

What the site is, and what must never be traded away.

- [vision.md](vision.md) — why the site exists, who it is for, where it is heading, and the
  principles it never trades away. Open it before any decision about what the site should do; a
  principle here outranks a convenience.
- [brand.md](brand.md) — the "Broken Robot" personality, voice, mascot, typefaces, and visual
  direction. Open it before changing anything a visitor sees or reads.
- [tech-stack.md](tech-stack.md) — the shape of the stack, build and delivery, and what they mean
  for the design. Open it before adding a dependency or changing how the site is built or
  delivered.
- [architecture.md](architecture.md) — code structure, content model, theming, and the
  Content-Security-Policy. Open it before touching `src/` or the response headers.
- [known-gaps.md](known-gaps.md) — intent the site does not meet yet, or does not record yet. Open
  it before assuming the documents above describe what actually happens, and when something looks
  wrong: the gap may already be recorded.
- [design-md-assessment.md](design-md-assessment.md) — an evaluation of Google Labs' DESIGN.md
  format for this repository: fit, benefits, trade-offs, the dual-theme catch, and a recommended
  PoC. Open it only when working on `DESIGN.md` or the design tokens.

## Working on the code

The rules that apply once files are about to change.

- [development-environment.md](development-environment.md) — how to set up a machine to work on
  the site: Node/npm versions, install, host versus devcontainer, the global LSP tools, worktrees,
  and editor setup. Open it when setting up a machine or a worktree, and when a tool misbehaves.
- [coding-conventions.md](development/conventions/coding-conventions.md) — TypeScript, formatting,
  Astro patterns, and testing rules. Open it before writing or reviewing code.
- [implementation-conventions.md](development/conventions/implementation-conventions.md) — how to
  work while implementing: keep it simple, change only what you must, and work toward a checkable
  goal. Open it before implementing a task. It is not for conversations or planning.
- [checks.md](development/checks.md) — every automated check: what it inspects, how to run it, and
  why it exists. Open it before running or adding a check. It is the only place the checks are
  listed.
- [commit-conventions.md](development/conventions/commit-conventions.md) — Conventional Commits
  and the commit message rules. Open it before committing.
- [branching-conventions.md](development/conventions/branching-conventions.md) — branch naming,
  worktrees, the human-only push gate, and squash-merging. Open it before creating a branch or a
  worktree.

## How a change moves

The process, and when it starts.

- [development-workflow.md](development-workflow.md) — the way we work, independent of any tool:
  spec-driven planning, scaled trunk-based development, the phases, the gates, and the hand-offs.
  Open it before the first question about the site is asked, an analysis included; it says when a
  conversation becomes a change.
- [tooling/workflow.md](tooling/workflow.md) — the mechanics: OpenSpec, the role-based agents, the
  skills, the process table with the owner of each step and the file each step produces. Open it
  before running or routing any phase; the `coordinating-changes` skill is its runbook.
- [collaboration-conventions.md](development/conventions/collaboration-conventions.md) — how the
  human wants to be worked with: how to explain, how to ask, and how to decide. Open it at the
  start of every conversation.

## The Claude Code setup

Why a tool behaves as it does, and where its configuration lives.

- [tooling/sandbox.md](tooling/sandbox.md) — the Claude Code sandbox and permission model: what a
  session may read, write, run, and reach on the network, and why. Open it when a command is
  denied, or when a path or a host is unreachable.
- [tooling/code-intelligence.md](tooling/code-intelligence.md) — the code-intelligence tools, the
  typescript-lsp plugin and the Codegraph MCP server: how they are pinned, enabled, and used across
  worktrees. Open it when one of them misbehaves, or before upgrading them.
- [tooling/conventions/writing-conventions.md](tooling/conventions/writing-conventions.md) — how
  this project applies the `writing-simplified-technical-english` skill, an external plugin from
  [brokenrobot-xyz/agent-skills](https://github.com/brokenrobot-xyz/agent-skills): which prose the
  conventions govern here, the local carve-outs, and how `reviewing-claude-skills` enforces them.
  Open it before writing or editing any text an agent reads: skills, agents, planning artifacts,
  and documentation.
- [tooling/conventions/skill-conventions.md](tooling/conventions/skill-conventions.md) — how this
  project applies the `reviewing-claude-skills` skill, an external plugin from the same
  marketplace: which project documents its project-scoped criteria resolve to here. Open it before
  writing or reviewing a skill.

The committed tooling configuration lives under [`.claude/`](../.claude): `agents/` and `skills/`
(the workflow — see [tooling/workflow.md](tooling/workflow.md)), `commands/` (the `opsx` slash
commands), `hooks/` (the SessionStart environment report and the push gate), and `settings.json`
(the sandbox and permissions — see [tooling/sandbox.md](tooling/sandbox.md) — plus the
[brokenrobot-xyz/agent-skills](https://github.com/brokenrobot-xyz/agent-skills) marketplace config
that installs the external plugin skills, among them the commit-message gate).
