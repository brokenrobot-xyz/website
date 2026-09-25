# Review

Reviewed 2026-09-22 in the planning session, against the Explore record in `docs/known-gaps.md`,
the `frontend-change` schema, `openspec/config.yaml`, the three agent definitions, and the Claude
Code subagent docs. The change matches the record in substance: all six agreed pieces are present.
Four findings, each settled with the human and folded into the artifacts the same day.

## Findings

1. **The intent had nowhere to graduate.** Task 6.4 deleted the known-gaps entry, but no task moved
   the isolation principle or the process table into a living document, and the coordinator was to
   point at a table that would no longer exist. _Decision:_ the principle goes into
   `docs/development-workflow.md` without naming a tool; the process table goes into
   `docs/tooling/workflow.md` in place of its phase table; the entry is deleted last.
2. **The third human stop and the second commit were missing.** The artifacts said "two gates" and
   never named the look at the merged specs or the specs commit. _Decision:_ restore the agreed
   sequence — the code commit after the implementation gate, Archive, the look, the specs commit —
   and have the coordinator's apply entry end at the specs commit.
3. **Task 1.2 stopped on the intended behaviour, and this change had neither file the schema would
   require.** The apply probe over a change without `review.md` is supposed to report not ready;
   task 2.3 verifies exactly that. _Decision:_ only the two validate probes can stop the plan; the
   apply probe's not-ready is expected. This change gets a hand-written `brief.md` and `review.md`
   at planning time, and the agent smoke tests run against a throwaway change.
4. **A path-restricted `Write` tool does not exist.** A subagent definition grants tools by name;
   the docs offer only a `PreToolUse` hook for partial grants; and every reviewing agent already
   holds an unrestricted `Bash` grant, so the boundary was never mechanical. Task 4.1 also widened
   the grant to the Playwright baselines, which go through `test:e2e:update` over `Bash`.
   _Decision:_ grant `Write` outright, hold it to one path by instruction as `Bash` already is,
   check at the gate; drop the baselines from the grant.

## Noted, not drift

Three decisions are new against the record and stand: the planner pinned to opus; `verify-report.md`
and `code-review.md` as undeclared files in the change folder; the `review` artifact requiring
`tasks`.
