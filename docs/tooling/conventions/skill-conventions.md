# Skill conventions

The review criteria live in the **`reviewing-skills`** skill, which is self-contained and portable
so that it can be shared with other projects. This document records how this project applies that
skill. Invoke the skill by name; never reference a path into its bundle, because a plugin's install
directory is version-keyed and changes on every update.

The skill's checklist groups `A`–`H` carry the external standards (the Agent Skills specification
and Anthropic's docs) and need nothing from this project. Group `R` splits: `R1`–`R4` and
`R7`–`R11` are portable craft criteria the checklist owns, and `R5`–`R6` resolve against the host
project's own convention documents. The lists below name the documents they resolve to here.

## What the project-scoped criteria resolve to here

- **`R5` — commit hygiene** resolves to
  [commit-conventions.md](../../development/conventions/commit-conventions.md): Conventional
  Commits, the allowed scopes, and no attribution trailers.
- **`R6` — naming convention** resolves to [workflow.md § The skills](../workflow.md#the-skills-claudeskills):
  skill names use gerund form (verb-ing + object, e.g. `running-preflight-checks`). Generated
  skills (`openspec-*`, `opsx:*`) keep their vendored names and are exempt.

## How the portable criteria map onto this project

- **`R1`–`R4`** (simplicity first, surgical edits, single source of truth, ask when uncertain)
  state the same rules as `CLAUDE.md` § Behavioral guidelines, so a finding under one of those keys
  is also a finding against this project's own guidelines.
- **`R7`–`R11`** (prose conventions) delegate to the `writing-simplified-technical-english` skill;
  how this project applies that skill is recorded in
  [writing-conventions.md](writing-conventions.md).
