## Why

A change is meant to move through phases that cannot contaminate each other. Each phase should
start from its delegation message and the files the phase before it left on disk, and from nothing
else, so that stale reasoning, rejected directions, and earlier tangents cannot steer the next
phase. `docs/known-gaps.md` records this intent under **The main session does the work it is meant
to coordinate**, together with the process the project agreed on 2026-09-11.

Today the isolation exists at one boundary, and a human creates it by opening a second session.
Explore and Propose share one context, so Propose reads the whole Explore conversation, rejected
directions included. Explore leaves nothing on disk. Nothing reviews the proposal before the human
does. Nothing loaded in a fresh session names the phases, their owners, or the two points where the
main thread must stop, so a session drifts into doing the work it should delegate.

## What Changes

- **The schema declares the two missing artifacts.** `openspec/schemas/frontend-change/schema.yaml`
  gains `brief` (first in the graph, required by `proposal`) and `review` (required by `apply`), each
  with a template. Every change then starts from a written brief, and OpenSpec refuses to apply a
  change that nobody reviewed.
- **A planner agent owns Propose and Update.** It wraps the vendored propose and update skills in
  its own context and returns a question instead of guessing, as `frontend-engineer` does. Its input
  is the brief plus the disk.
- **A proposal reviewer agent attacks the change folder** before the human reads it — untestable
  scenarios, requirements that contradict the living specs, tasks that use a primitive nobody
  establishes, a missing tier decision, unnamed scope, a `skip_specs` claim that hides a behaviour
  change. It writes `review.md`.
- **Each reviewing agent writes its own report file.** `frontend-qa-engineer` writes the Verify
  report, `frontend-code-reviewer` writes its findings, and the proposal reviewer writes `review.md`.
  Each gets a `Write` tool restricted to that one path, so a report never passes through the main
  thread. Every other write stays forbidden.
- **`frontend-qa-engineer` owns all of Verify**, including the preflight gate it already invokes,
  and ticks the Verify items its own evidence supports. The main thread stops running the gate.
- **Commits run in a general-purpose subagent** that invokes the `committing-conventionally` skill,
  so the diff replay lands there rather than in the main thread. The delegation answers the skill's
  three questions up front: the branch, the touched-files list, and explicit staging. Commits happen
  only after a human approval.
- **One project-owned coordinator skill** names the sequence, the owner of each step, the files each
  step reads and writes, and the stops for the human. It has two entry points, because a change
  starts in one session and is applied in another: start a change, and apply a named change. It
  carries the rules that belong to no single agent. `CLAUDE.md` gains one pointer line to it.
- **The docs follow the process.** `docs/tooling/workflow.md` replaces its phase table and drops the
  line that says planning has no agent by design; its schema-reconcile recipe gains a step, because
  the fork no longer matches upstream's artifact list. `docs/development-workflow.md` gains the two
  review steps. The known-gaps entry is deleted, since both of its exits are then reached.
- **The apply guidance in `openspec/config.yaml`** hands Verify to the QA agent as a whole, rather
  than splitting it between that agent and the main thread.

## Non-Goals

- **Not** editing the vendored `openspec-*` skills or the `opsx` commands. `openspec update`
  regenerates them, so an edit there is lost at the next CLI upgrade.
- **Not** changing the `committing-conventionally` plugin. Forking the skill would cost every other
  consumer its questions; the isolation comes from the subagent that invokes it.
- **Not** automating a fix round on Blocking findings. Both review loops keep the human in them
  until the two reviewers have a track record: findings come to the human, the human decides which
  go back, the coordinator re-delegates.
- **Not** converting `running-preflight-checks`, `testing-visual-regression`, or
  `scaffolding-components` into forked skills. They are procedures, not phases, and each already
  runs inside a phase's agent. Nested forks are unproven, and a probe for them is follow-up work.
- **Not** moving Archive out of the main thread. It stays there until it proves noisy.
- **Not** running this change through the process it creates. This change is planned and applied
  under today's flow; the new flow is exercised on the change after it.
- **Not** touching `src/`, `public/`, `tests/`, `infra/`, or CI. No site behaviour changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. Specs in this project describe what visitors and downstream consumers rely on. This change
alters the workflow tooling under `.claude/` and `openspec/` and the documents that describe it. No
site output, permalink, feed, or check result changes, so `.openspec.yaml` sets `skip_specs: true`.

## Impact

**New tooling**

- `.claude/agents/` — two agent definitions: the planner and the proposal reviewer.
- `.claude/skills/` — the coordinator skill. The sandbox denies writes under `.claude/skills/`, so
  the task that creates it states who runs that step.

**Modified tooling**

- `openspec/schemas/frontend-change/schema.yaml` and `templates/` — the `brief` and `review`
  artifacts, and a template for each.
- `.claude/agents/frontend-qa-engineer.md` — the Verify report file, the preflight gate, ticking its
  own Verify items, and the `Write` grant restricted to the report path.
- `.claude/agents/frontend-code-reviewer.md` — the findings file and the same restricted grant.
- `openspec/config.yaml` — the apply guidance hand-off line.
- `CLAUDE.md` — one pointer line to the coordinator skill.

**Docs**

- `docs/tooling/workflow.md`, `docs/development-workflow.md`, `docs/known-gaps.md`.

**Risk to check first**

- Adding a required artifact changes what OpenSpec expects of every change that already exists. The
  six archived changes carry no `brief.md` and no `review.md`, and neither does this change. Whether
  `openspec validate --all --strict`, `openspec validate --archived`, and `openspec instructions
apply` still pass is **unverified**, and `npm run specs:check` gates CI on the first two. The first
  task establishes this against a throwaway copy of the schema, before any schema edit.

**Build & verification**

- No `src/` change and no dependency change, so the visual baselines and axe results are untouched.
  The view-dependent Verify items are N/A for this change; the gate steps still run.
- The change is verified by using it: a later change starts from a brief, is reviewed before the
  human, and is applied and committed through the delegated steps.
