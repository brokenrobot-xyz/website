# Development tooling

How this repository is set up to be worked on with **Claude Code** — the agent/skill workflow and
the sandbox that constrains it. This is deliberately kept separate from the application
documentation in [../README.md](../README.md), which covers what the site _is_ and how its code is
built. These docs cover _how we work on it_.

- [workflow.md](workflow.md) — how we run the workflow: OpenSpec, the role-based agents, the skills,
  and the schema/config that bakes the guardrails into the propose flow.
- [sandbox.md](sandbox.md) — the Claude Code sandbox & permission model: what the agent may read,
  write, run, and reach on the network, and why.
- [code-intelligence.md](code-intelligence.md) — the code-intelligence tools (typescript-lsp plugin
  and the Codegraph MCP server): how they're pinned, enabled, and used across worktrees.
- [conventions/writing-conventions.md](conventions/writing-conventions.md) — how this project applies
  the `writing-simplified-technical-english` skill (an external plugin from
  [brokenrobot-xyz/agent-skills](https://github.com/brokenrobot-xyz/agent-skills)), which carries the
  conventions themselves: which prose they govern here, the local carve-outs, and how
  `reviewing-claude-skills` enforces them as checklist items `R7`–`R11`.
- [conventions/skill-conventions.md](conventions/skill-conventions.md) — how this project applies
  the `reviewing-claude-skills` skill (an external plugin from
  [brokenrobot-xyz/agent-skills](https://github.com/brokenrobot-xyz/agent-skills)), which carries the
  review criteria themselves: which project documents the project-scoped criteria (`R5`–`R6`)
  resolve to here.

## The pieces (in `.claude/`)

The committed tooling configuration lives under [`.claude/`](../../.claude): `agents/` and
`skills/` (the workflow — see [workflow.md](workflow.md)), `commands/` (the `opsx` slash commands),
`hooks/` (the SessionStart environment report and the push gate), and `settings.json` (the sandbox
& permissions — see [sandbox.md](sandbox.md) — plus the
[brokenrobot-xyz/agent-skills](https://github.com/brokenrobot-xyz/agent-skills) marketplace config
that installs the three external plugin skills, among them the commit-message gate).

The _what_ this implements — the way we work, independent of any tool — is the application doc
[../development-workflow.md](../development-workflow.md). `workflow.md` is the _how_.
