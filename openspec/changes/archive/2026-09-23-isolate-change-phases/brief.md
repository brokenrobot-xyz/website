# Brief

## Problem and goal

Every phase of a change — Explore, Propose, a review of the proposal, Apply, Verify, a review of
the implementation, Archive — should run in a context that holds only its own input: the delegation
message and the files the phase before it left on disk. Stale reasoning, rejected directions, and
earlier tangents must not steer the next phase; a small context is a side effect, not the goal.
Today the isolation exists at one boundary only, and by hand: Explore and Propose share one session,
the human opens a second session for Apply onward, Explore leaves nothing on disk, nothing reviews
the proposal before the human does, and nothing in a fresh session names the sequence or the owner
of each phase. The Explore record is the known-gaps entry agreed 2026-09-11.

## Decisions

- Every phase ends with a file; the next phase starts from files. The main thread is a router: it
  holds the human's decisions and one short report per phase, and does not read files during a phase.
- Explore ends with a declared `brief` artifact, first in the graph and required by `proposal`; the
  vendored explore skill writes it after `openspec new change`.
- Propose and Update run in a planner agent that returns a question instead of guessing; an answer
  is appended to the brief and the same planner resumed.
- A separate read-only proposal reviewer writes a declared `review` artifact that `apply` requires.
  Blocking findings go to the human; no automatic fix round until the reviewer has a track record.
- `frontend-qa-engineer` owns all of Verify, including the preflight gate. Every review and Verify
  report is a file in the change folder, written by the agent that produced it.
- Commits run in a general-purpose subagent invoking `committing-conventionally`, each after a human
  stop: the code commit after the implementation gate; Archive; the human looks at the merged specs;
  the specs commit.
- One project-owned coordinator skill with two entry points — start a change, apply a named change —
  and one pointer line in `CLAUDE.md`. Archive stays in the main thread.

## Rejected directions

- A third placement on `frontend-code-reviewer` for the proposal review: judging prose against specs
  shares little with judging a diff.
- Forking the three procedure skills or the committing skill: they are procedures, not phases;
  nested forks are unproven; forking the plugin costs every consumer its questions.
- The sequence written into `CLAUDE.md`, or two coordinator skills.
- An undeclared `brief.md` by convention: nothing would require or track it.

## Open questions and scope

- Whether a required artifact breaks validation of the six archived changes — probe before any
  schema edit.
- Where the two later report files live — settled at implementation.
- Scope: tooling under `.claude/` and `openspec/`, and the docs that describe it. No `src/`, no
  edits to the vendored `openspec-*` skills. This change is planned and applied under today's flow.

## Answers

None asked; the change was planned in the main session under today's flow.
