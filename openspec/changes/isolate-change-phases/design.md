## Context

See proposal.md — Why. The process this implements, step by step with its owners, is the table in
`docs/known-gaps.md` under **The main session does the work it is meant to coordinate**.

Three constraints shape every decision below.

- **OpenSpec owns the artifact graph.** A phase hands off through a declared artifact, or through a
  file OpenSpec ignores. `openspec validate --all --strict` ignores files the schema does not
  declare, and `openspec status` tracks only declared ones.
- **A subagent cannot ask.** Claude Code strips `AskUserQuestion` from every subagent, so a final
  message is an agent's only channel back. `frontend-engineer` already answers this by returning the
  question instead of guessing.
- **The main thread is a router.** Whatever it reads leaks into the next delegation message, so a
  report that reaches the human must reach the disk without passing through the main thread.

## Goals / Non-Goals

**Goals:**

- Every phase starts from a delegation message plus files, and ends with a file.
- The three human stops stay — the proposal gate, the implementation gate, and the look at the merged
  specs — and each is preceded by a file the human can read.
- A fresh session can run the process from what the coordinator skill names.

**Non-Goals:**

- No enforcement that a review passed. OpenSpec checks that `review.md` exists, not its verdict.
- No change to how the site is built, tested, or deployed.

## Decisions

**The brief is a declared artifact, first in the graph, and `proposal` requires it.** Declaring it
is what makes every change start from one; a convention would be skipped on the first small change.
The vendored explore skill writes it after `openspec new change`, which it may do within a scope the
human confirms with an explicit yes. For a one-line idea with no Explore, the main thread writes the
few lines itself. Its template opens with a `# Brief` title, as every template does since OpenSpec
1.13.1, followed by five headings — Problem and goal, Decisions, Rejected directions, Open
questions and scope, Answers — with an instruction that caps it at about one screen and sends
anything longer to the proposal. The Answers section is where the coordinator appends an answer to a
planner question. _Alternative rejected:_ an undeclared `brief.md` by convention, which OpenSpec
would neither require nor track.

**`review.md` is a declared artifact that `apply` requires.** OpenSpec then refuses to apply a change
that nobody reviewed, which is the one mechanical part of the gate. It proves a review ran; it proves
neither that the review passed nor that the human approved, and the file goes stale after an Update
round. The coordinator carries what the schema cannot: review again after every Update, and the
human reads the report before opening the apply session. _Alternative rejected:_ a verdict on the
report's first line that the coordinator refuses to proceed past. It closes the staleness hole
mechanically, and it waits until the reviewer has a track record, because a reviewer that blocks
its own author is harder to override than to fix.

**The two later reports are undeclared files in the change folder**:
`openspec/changes/<name>/verify-report.md` and `openspec/changes/<name>/code-review.md`. They belong
to the folder because archive moves the folder, so the audit log survives with the change. They stay
undeclared because declaring them would put Verify and the implementation review inside the artifact
graph, where `apply` would demand them before the code they describe exists. _Alternative rejected:_
a `reports/` directory outside the change, which archive would leave behind.

**Each reviewing agent writes its own report, and holds itself to that one path by instruction.**
This is the only shape where a report reaches the human without passing through the main thread.
The grant is `Write` itself, not a path-restricted tool: a subagent definition grants tools by name,
and the Claude Code subagent docs offer only a `PreToolUse` hook for allowing some uses of a tool
while blocking others. Such a hook would guard `Write` alone while each of these agents already holds
an unrestricted `Bash` grant, so the boundary was never mechanical. The rule is therefore the one
that already governs `Bash`: the definition names the one file the agent writes, every other write
stays forbidden, and the diff at the gate is the check — `frontend-code-reviewer` already flags a
diff that touches files outside a change's scope. `frontend-qa-engineer` also gains `Edit` for the
Verify checkboxes in the change's `tasks.md`, because a tick is a one-line edit, not a rewrite.
_Alternatives rejected:_ the main thread writing
the file, which is the leak this change exists to close; a general-purpose subagent writing it, which
adds a hop per review and holds the report in a second context for no gain; and a `PreToolUse` hook
on `Write`, which needs a script under `.claude/hooks/` that the sandbox cannot write, is unverified
as a deny mechanism from agent frontmatter, and closes one of two doors.

**Two new agents, named for their role:** `frontend-planner` (Propose and Update) and
`frontend-proposal-reviewer` (the proposal review). Both are pinned to opus, matching
`frontend-code-reviewer`: writing a proposal and attacking one are judgment, not execution. The
planner wraps the vendored propose and update skills rather than restating their procedure, as
`frontend-engineer` wraps the apply skill. It returns a question instead of guessing; the coordinator
appends the human's answer to the brief's Answers section and resumes the same planner, because a
finished subagent resumes with its full history. _Alternative rejected:_ a third placement on
`frontend-code-reviewer` for the proposal review — judging prose against specs shares almost nothing
with judging a diff, and one definition serving both would fit neither.

**The coordinator is one project-owned skill, `coordinating-changes`, with two entry points as two
sections:** start a change, and apply a named change. A change starts in one session and is applied
in another, so both entries are reachable, and one skill avoids two copies of the same sequence. It
is a runbook that points at the process table in `docs/tooling/workflow.md` rather than restating
it, and it carries the rules belonging to no single agent: the main thread never invokes the three
procedure skills during a change; an answer to a planner question is appended to the brief and the
same planner resumed; the proposal is reviewed again after every Update; commits are delegated and
each follows a human stop. The apply entry runs from the engineer to the specs commit, so the look at
the merged specs and the second commit are named where a fresh session reads them. `CLAUDE.md` gains
one pointer line, which is the backstop for a missed trigger. _Alternatives rejected:_ the sequence
in `CLAUDE.md` itself, which every session would pay for; and two skills, which would share most of
their content.

**The three procedure skills stay inline.** `running-preflight-checks`, `testing-visual-regression`,
and `scaffolding-components` are procedures, not phases. Invoked from inside a phase's agent their
output lands where it belongs, and the leak exists only when the main thread invokes one directly —
which the coordinator forbids during a change. Preflight had no owner, which is why the main thread
ran it; `frontend-qa-engineer` now owns all of Verify. _Alternative rejected:_ the `context: fork`
shape with an `agent:`, as `checking-dev-env` uses. The QA agent would then invoke a forked skill
from inside a subagent, and nested forks are the one case the Claude Code docs do not cover. A fork
for running the gate by hand outside a change is follow-up work, after a probe.

**Commits run in a general-purpose subagent invoking `committing-conventionally`.** The skill replays
the full diff, which belongs in a subagent rather than the main thread. The delegation answers the
three questions the skill asks — the branch is the change's branch, the scope is the engineer's
touched-files list, staging is explicit paths — and a question it still hits comes back in the
subagent's report. A change makes two commits, each after a human stop: the code commit after the
implementation gate; then Archive runs in the main thread, the human looks at the merged specs, and
the specs commit follows. Docs-only commits outside a change stay inline, because the human is
present and no phase follows. _Alternative rejected:_ forking the skill inside the plugin, which
would cost every other consumer its questions.

**The intent graduates into two documents before its known-gaps entry goes.** The known-gaps page
deletes an entry only once its intent has reached the document that owns it. The principle — a phase
starts from the files the phase before it left and ends with a file; the session that runs a change
routes between phases and does not do their work — is about how work moves, not which tool moves it,
so it goes into `docs/development-workflow.md`, which names no agent, skill, or file. The process
table — each step's owner, input files, and output file — is the implementation, so it goes into
`docs/tooling/workflow.md` in place of that page's phase table, and the coordinator points there.
The entry is deleted only after both. _Alternative rejected:_ leaving the principle to the
coordinator skill and this archived design, which the page's own rule does not count as graduated.

**This change carries a hand-written brief and review.** Once `review` gates `apply`, a change
without one reads as not ready, and this change was planned before either file existed. Both are
written by hand at planning time — the brief from the Explore record, the review from the proposal
review that preceded implementation — so the gate never rejects the change that adds it, and the
folder is the first complete record of the new shape. Writing two files is not running the change
through the process it creates. The two agent smoke tests therefore run against a throwaway change,
so neither overwrites the real files. _Alternatives rejected:_ ordering the schema task last, which
holds only until someone resumes the apply session; and accepting a not-ready state, which has the
change violate the gate it introduces.

## Risks / Trade-offs

- **A required artifact changes what OpenSpec expects of existing changes.** The six archived changes
  carry no `brief.md` and no `review.md`. → Establish the behaviour first, against a throwaway copy
  of the schema, before any schema edit: `openspec validate --all --strict` and
  `openspec validate --archived`, which `npm run specs:check` gates CI on. If archived changes fail,
  the schema edit stops and the plan returns to the human. The apply instructions over a change
  without `review.md` are probed too, but not-ready there is the intended outcome, not a stop.
- **The schema fork drifts further from upstream.** Two declared artifacts are two more pieces to
  reconcile at the next `openspec update`. → The reconcile recipe in `docs/tooling/workflow.md` gains
  a step naming the two additions, so the diff against upstream stays explainable.
- **The review gate proves existence, not approval.** A stale or negative `review.md` still satisfies
  `apply`. → The coordinator re-reviews after every Update, and the human reads the report before
  applying. The first-line verdict is the fallback if that proves too weak.
- **Three agents gain a write grant they did not have.** → Each definition names the one path by
  instruction, as it already does for `Bash`, every other write stays forbidden, and the diff at the
  implementation gate shows any file that appears outside it.
- **More hops per change means more delegation messages to get right.** A message that omits an
  input costs a full phase re-run. → Each agent states what its delegation message must carry and
  stops when it is missing, as the three existing agents already do.
- **The sandbox denies writes under `.claude/skills/`.** The coordinator skill cannot be created by a
  sandboxed agent. → The task that creates it says the human runs that step, and the engineer stops
  rather than working around the restriction.
