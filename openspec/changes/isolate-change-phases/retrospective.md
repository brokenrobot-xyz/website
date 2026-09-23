# Retrospective

What the implementation found that the plan had wrong or did not know. The planning artifacts stay
as they were written; this file is the record of where reality differed.

## The hand-off of the coordinator skill was unnecessary

The design's risk entry and task 5.1 say the sandbox denies writes under `.claude/skills/`, so the
human places the skill by hand. That is true of the Bash sandbox only. On 2026-09-23 the Edit tool
changed `.claude/skills/coordinating-changes/SKILL.md` with no permission prompt, so an agent can
create a skill with the Write tool. The belief came from the tooling doc's line about
`openspec update`, which is a shell command, and was never probed before the plan relied on it.

Cost: the human copied the file by hand, then fixed a line in it by hand, both avoidable.

## The staged skill shipped with a wrong `allowed-tools` line

The skill's own rules append the human's answer to the brief and, for a one-line idea, write the
brief itself. The staged frontmatter listed `Read Bash Skill Agent` and omitted `Edit` and `Write`.
The `frontend-code-reviewer` caught it at the implementation gate; the human corrected it.

## The new agents registered mid-session, after a delay

Delegating to `frontend-planner` by name failed right after its file was written, then succeeded a
few minutes later without a restart. The plan assumed a fresh session would be needed. An earlier
pass ran both definitions through a general-purpose subagent carrying the body verbatim; the by-name
runs then produced equivalent results, and the tasks were ticked on the by-name runs.

## The planner recorded an assumption instead of stopping

Given a throwaway brief that contradicted itself on file scope, the planner wrote the proposal with
its reading recorded under **Impact** and also returned the question. Its definition asks it to leave
the dependent artifact unwritten. Softer than specified; worth watching on the first real change.
