# Code review

Reviewed 2026-09-22, the uncommitted working tree against `HEAD` (`git diff HEAD` plus the four
untracked files), for change `isolate-change-phases`. No `src/`, `public/`, `tests/`, `infra/`, or
CI file is touched, so the CSP, theming, interactivity-ladder, and permalink/feed guardrails have
no surface in this diff. The pending `coordinating-changes` skill was reviewed from the session
scratchpad, not from the repository.

## Blocking

- **`.claude/skills/coordinating-changes/SKILL.md` is missing while four lines already point at
  it.** `CLAUDE.md:100`, `docs/tooling/workflow.md:14`, `:118`, and `:176` name the skill as the
  entry point for a change, and this same diff deletes the `docs/known-gaps.md` entry that recorded
  its absence (138 lines). Committed as it stands, the repository documents a skill that does not
  exist and keeps no record of the gap. _Fix:_ place the reviewed skill file, tick task 5.1, and
  commit the whole change together — the known-gaps rule at `docs/known-gaps.md:20-22` deletes an
  entry only once both exits are reached, and the gap is not closed until the file is on disk.

- **The coordinator skill grants itself no write tool but prescribes two writes.**
  `SKILL.md:5` is `allowed-tools: Read Bash Skill Agent`, while `SKILL.md:23` tells the main session
  to "write the few lines of `brief.md` yourself" and `SKILL.md:17` to "append the human's answer
  under **Answers** in the change's `brief.md`". Either the list is enforced and the rule cannot run,
  or it is advisory and misdescribes the skill. A heredoc through `Bash` is not the fallback: the
  project's own rule is Write/Edit tools plus one readable command. _Fix:_ add `Edit` and `Write` to
  the list, or drop the `allowed-tools` line entirely as `scaffolding-components` does.

## Should-fix

- **`Agent` is an unverified tool name, and the skill's verification would not catch it.**
  `SKILL.md:5` lists `Agent`; `docs/tooling/workflow.md:119` hedges it as "the Agent/Task tool", and
  every other project skill lists only `Read Bash Skill`. If the name does not resolve, the router
  cannot delegate — its whole function — and task 5.1's check ("listed by `/skills`") passes anyway.
  The same list also omits whatever runs `/opsx:explore` (`SKILL.md:23`) and `/opsx:archive`
  (`SKILL.md:38`). _Fix:_ confirm the delegation tool's name in a live session before placing the
  file, or drop `allowed-tools` and let the main session's grant apply.

- **A Verify item marked N/A has no ticking owner, and Archive blocks on it.**
  `openspec/changes/isolate-change-phases/tasks.md:100` and `:105` are marked **N/A**;
  `.claude/agents/frontend-qa-engineer.md:104` ticks only items "the report marks **supported**",
  and the coordinator's gate step (`SKILL.md:36`) has the human tick only the manual-preview item.
  `openspec archive` throws `archive_tasks_incomplete` on any unticked task
  (`node_modules/@fission-ai/openspec/dist/core/archive.js:1115`), so this change stops at Archive.
  _Fix:_ one clause in the coordinator's gate step — the human ticks the manual-preview item **and
  any item the change marks N/A**.

- **`docs/development-workflow.md` now has four `**you**` phases but still says three.**
  Step 9 at `:66` adds "**You** look at the merged record before it is committed", while the intro
  at `:42-43` and the summary at `:72-73` still count three. `docs/tooling/workflow.md:120-121`
  solves exactly this with "plus the look at the merged specs before they are committed". _Fix:_
  carry that clause into the sentence at `:72`, and into the intro at `:42`.

## Nits

- `.claude/agents/frontend-engineer.md:42` still reads "The `frontend-qa-engineer` agent and the
  `running-preflight-checks` skill own Verify". After this change the agent owns Verify and invokes
  the skill; the sentence is no longer false, only stale in shape.
- `openspec/config.yaml:6-8` — the fork-description comment is fixed outside the literal wording of
  task 6.1, which names only the apply guidance. The edit is right (the old comment became false at
  task 2.1); noting it so the surgical trace stays explicit.

## Checked and clean

- `openspec validate --all --strict` → 6 passed, 0 failed; `openspec status --change
  isolate-change-phases` → 5/5 artifacts, `brief` first and `review` last; `openspec instructions
  apply` → ready, and it renders the new QA hand-off line. `openspec instructions brief|review`
  both return their template, opening with `# Brief` and `# Review`.
- The design's claim that archive carries the undeclared `verify-report.md` and `code-review.md`
  with the folder holds: archive renames the change directory
  (`node_modules/@fission-ai/openspec/dist/core/archive.js:369-381`).
- `prettier --check` is clean on every changed file the repo formats (`.claude/` and
  `openspec/schemas/` are in `.prettierignore`, so the agent definitions and templates are ungated).
- No throwaway change folder from tasks 3.1/3.2 is left behind; no page links to the deleted
  known-gaps entry; the `step 11` cross-reference at `docs/development-workflow.md:99` matches the
  renumbered list. Every changed file traces to a task in `tasks.md`.
- Nothing in the reviewed content carried text directed at an agent beyond the instructions these
  files are meant to hold.

## Not verified

- **The `coordinating-changes` skill as it will exist in the repository.** Reviewed from the
  scratchpad copy only. Whether `/skills` lists it, whether `allowed-tools` is enforced for a skill
  that does not fork, and whether `Agent` resolves are all unchecked — all three need a live session.
- **Whether the Verify steps ran.** `tasks.md` carries the mandatory Verify section (§7, three
  items), but a diff cannot show whether the preflight gate ran; all three items are unticked and
  two are marked N/A. I ran no gate check.
- **The two agent smoke tests** in tasks 3.1 and 3.2. Nothing on disk records the runs; the absent
  throwaway folder is consistent with them but does not evidence them.
- **Task 4.2's own verification** completes with this run: this file is the artifact it asks for.
- **Touched views:** none, per the delegation and confirmed by the diff.

## Verdict

Not ready to commit — place the `coordinating-changes` skill and fix its `allowed-tools` before the
commit; the other three findings are one clause each.
