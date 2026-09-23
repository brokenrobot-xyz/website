---
name: coordinating-changes
description: Runs a brokenrobot.xyz change through its phases as a router — starting a change (Explore, Propose, proposal review, the human's proposal gate) or applying a named change (Implement, Verify, implementation review, the human's gate, the code commit, Archive, the human's look at the merged specs, the specs commit) — by delegating each phase to its owning agent and stopping at the three human gates. Use at the start of any change and when applying an approved one; also when a session is about to plan, verify, review, or commit a change itself instead of delegating it.
compatibility: Requires the openspec CLI and the project's agents under .claude/agents/. Runs in the main thread by design — it routes, so it has nothing to isolate.
allowed-tools: Read Edit Write Bash Skill Agent
metadata:
    author: brokenrobot.xyz
    version: '1.1'
---

Run a change as a router. The principle is in [docs/development-workflow.md](../../../docs/development-workflow.md) — a phase starts from the files the phase before it left and ends with a file, and the session that runs a change routes between phases and does not do their work. The process table — each step's owner, its input files, its output file — is in [docs/tooling/workflow.md](../../../docs/tooling/workflow.md) under **The process**, and this skill does not repeat it: read that table first, then follow the entry point below that matches where the change is.

## Rules that belong to no single agent

- **The main thread never invokes `running-preflight-checks`, `testing-visual-regression`, or `scaffolding-components` during a change.** Each runs inside the agent that owns its phase, so its output lands there. Invoked from the main thread, that output leaks into every delegation message after it.
- **The main thread does not read the phase files.** It holds the human's gate decisions and one short message per phase, and relays each agent's final message to the human verbatim. The human reads `brief.md`, the planning artifacts, `review.md`, `verify-report.md`, and `code-review.md` from disk; whatever the main thread reads steers the next delegation.
- **A planner question is answered through the brief.** When `frontend-planner` returns a question, relay it, append the human's answer under **Answers** in the change's `brief.md`, and resume the same planner — a finished subagent resumes with its full history — rather than starting a new one.
- **The proposal is reviewed again after every Update.** `review.md` proves a review ran, not that it passed, and it goes stale when an Update rewrites the artifacts.
- **Commits are delegated, and each follows a human stop.** A change makes two: the code commit after the implementation gate, and the specs commit after the human looks at the merged specs. Each runs in a general-purpose subagent that invokes `committing-conventionally`, with the delegation answering up front the three questions that skill asks: the branch is the change's `<type>/<change-name>` branch, the scope is the touched-files list, and staging is by explicit path. A question the skill still hits comes back in the subagent's report. Never push — pushing is a human-only gate.

## Start a change

1. **Explore** _(optional)_ — `/opsx:explore` in this thread, with the human. It ends with `openspec new change <name>` and the change's `brief.md`, which the explore skill writes within a scope the human confirms with an explicit yes. For a one-line idea with no Explore, write the few lines of `brief.md` yourself from the template `openspec instructions brief --change <name> --json` returns. **Output:** `openspec/changes/<name>/brief.md`.
2. **Propose** — delegate to `frontend-planner`: the change's directory name, mode **Propose**. **Output:** proposal, spec deltas, design, tasks. A returned question goes through the brief, as the rules above say.
3. **Proposal review** — delegate to `frontend-proposal-reviewer`: the change's directory name. **Output:** `review.md`. Relay its three-line message.
4. **Gate** — stop. The human reads the change folder and `review.md`. When the human sends findings back, delegate to `frontend-planner` with mode **Update** and the accepted findings stated as the revision, then run step 3 again. Repeat until the human approves.
5. **Hand off** — tell the human the change is approved and is applied from a fresh session with `/coordinating-changes apply <name>` (or by naming the change and asking to apply it), so that nothing from this session reaches the implementation.

## Apply a named change

Before the first step: the branch is `<type>/<change-name>`; `openspec instructions apply --change <name> --json` reports `state: "ready"`, which needs `review.md` on disk; and the human has read `review.md`. When any of the three is missing, stop and say which.

1. **Implement** — delegate to `frontend-engineer`: the change's directory name, and the answers to any question an earlier run returned. **Output:** code, ticked tasks. A returned question goes to the human; re-delegate with the answer.
2. **Verify** — delegate to `frontend-qa-engineer`: the change's directory name, the touched views as URL paths, whether it may regenerate baselines, and prior performance scores when the human holds them. **Output:** `verify-report.md`, and the Verify items its evidence supports ticked in `tasks.md`. A styling bug in its message goes back to step 1.
3. **Implementation review** — delegate to `frontend-code-reviewer`: the diff range (the working tree against `HEAD`, at this placement), the change's directory name, the touched views. **Output:** `code-review.md`.
4. **Gate** — stop. The human reads `verify-report.md` and `code-review.md`, ticks the manual-preview item, and decides. Findings the human sends back go to step 1, then steps 2 and 3 run again. Repeat until the human approves.
5. **Commit the code** — delegate the commit as the rules above say, with the engineer's touched-files list plus the change folder as the scope. **Output:** a commit.
6. **Archive** — `/opsx:archive <name>` in this thread, on the branch. **Output:** the merged specs under `openspec/specs/`, the folder under `openspec/changes/archive/`.
7. **Look** — stop. The human looks at the merged specs.
8. **Commit the specs** — delegate the commit as the rules above say, with the archive diff as the scope. **Output:** a commit. The change is done here; the push and the pull request are the human's.
