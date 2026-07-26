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

## The pieces (in `.claude/`)

The committed tooling configuration lives under [`.claude/`](../../.claude): `agents/` and
`skills/` (the workflow — see [workflow.md](workflow.md)), `commands/` (the `opsx` slash commands),
`hooks/` (the SessionStart environment report and the commit-message/push gates), and
`settings.json` (the sandbox & permissions — see [sandbox.md](sandbox.md)).

The _what_ this implements — the way we work, independent of any tool — is the application doc
[../development-workflow.md](../development-workflow.md). `workflow.md` is the _how_.
