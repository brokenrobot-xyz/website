# Writing conventions

The conventions themselves live in the **`writing-simplified-technical-english`** skill, an
external plugin from
[brokenrobot-xyz/agent-skills](https://github.com/brokenrobot-xyz/agent-skills) installed via the
marketplace config in `.claude/settings.json`. This document records how this project applies that
skill. Invoke the skill by name; never reference a path into its bundle, because a plugin's install
directory is version-keyed and changes on every update.

- **`references/conventions.md`** in that skill holds the twelve conventions, the traceability to
  ASD-STE100 Issue 9, and the copyright note.
- **`references/examples.md`** holds a worked rewrite for each convention.

## What the conventions govern here

- The body of every `SKILL.md` under `.claude/skills/`, the prose fields of every
  `evals/evals.json`, and every file under a skill's `references/`.
- The body of every agent definition under `.claude/agents/`.
- The OpenSpec artifacts under `openspec/` — `proposal.md`, `design.md`, `tasks.md`, and the spec
  deltas.
- The technical documentation under `docs/`.

## Local carve-outs

The skill's own exclusions apply here, and this project names the document that owns each excluded
kind of prose:

- **Published site copy** follows the voice in [brand.md](../../brand.md).
- **Commit messages** follow
  [commit-conventions.md](../../development/conventions/commit-conventions.md).
- **A skill's `name` and `description` frontmatter** follows the Agent Skills specification, which
  `reviewing-claude-skills` grades as checklist items `A1`, `A2`, and `A3`. The `description` drives skill
  discovery, so rewording it for prose style makes the skill harder to find.
- **Code, code comments, and the literal command text inside fenced blocks** are out of scope.

## How the conventions are enforced

The `reviewing-claude-skills` skill grades prose as checklist items `R7` through `R11`. `R7` delegates to
`writing-simplified-technical-english` in check mode, which grades against all twelve conventions. `R8`
through `R11` are a self-sufficient subset that `reviewing-claude-skills` applies on its own when the skill
is not installed, so a review still covers the four highest-value conventions without it.
