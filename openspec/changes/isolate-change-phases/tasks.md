## 1. Establish what a required artifact does to existing changes

- [ ] 1.1 Copy `openspec/schemas/` to a throwaway location outside the repository, add a `brief`
      artifact (required by `proposal`) and a `review` artifact (required by `apply`) to the copy,
      and copy one archived change and one change folder without those two files into it. Edit every
      file with the Write tool, one plain command per step — no inline scripts. Verify the copy loads
      by running `openspec status --change <copied-change>` inside it with no error.
- [ ] 1.2 Run `openspec validate --all --strict`, `openspec validate --archived`, and
      `openspec instructions apply --change <copied-change>` inside the copy, and record each exit
      status and message in the task list. Verify by reporting the three results; if any fails on a
      missing `brief.md` or `review.md`, stop and return the finding to the human — the schema edit
      does not proceed.

## 2. Declare the two artifacts in the schema

- [ ] 2.1 Add the `brief` artifact to `openspec/schemas/frontend-change/schema.yaml` — first in the
      graph, `requires: []` — and make `proposal` require it. Verify with
      `openspec instructions brief --change <a throwaway change>` printing the brief instruction.
- [ ] 2.2 Add `openspec/schemas/frontend-change/templates/brief.md` with the five headings from
      design.md and the instruction that caps it at about one screen. Verify the template appears in
      the `template` field of `openspec instructions brief`.
- [ ] 2.3 Add the `review` artifact, requiring `tasks`, and add `review` to `apply.requires`. Verify
      `openspec instructions apply --change <a throwaway change>` reports the change as not ready
      while `review.md` is absent, then ready once the file exists.
- [ ] 2.4 Add `openspec/schemas/frontend-change/templates/review.md`, holding the attack list from
      proposal.md. Verify it appears in `openspec instructions review`.
- [ ] 2.5 Run `npm run specs:check` and verify it passes with the archived changes untouched.

## 3. The two new agents

- [ ] 3.1 Write `.claude/agents/frontend-planner.md`: opus, wraps the vendored propose and update
      skills, reads the brief, returns a question instead of guessing, never edits code. Verify by
      delegating a throwaway propose run to it and confirming the change folder it produces carries
      all four artifacts.
- [ ] 3.2 Write `.claude/agents/frontend-proposal-reviewer.md`: opus, read-only except
      `review.md` in the change folder, attacks the change folder against the living specs on the
      list in proposal.md. Verify by running it against this change's own folder and confirming it
      writes `review.md` and edits nothing else (`git status` shows one new file).

## 4. The report files for the two existing reviewing agents

- [ ] 4.1 Update `.claude/agents/frontend-qa-engineer.md`: it owns all of Verify including the
      preflight gate, writes `openspec/changes/<name>/verify-report.md`, and ticks the Verify items
      its own evidence supports. Grant `Write`, restricted to that path and the Playwright baselines
      it already regenerates. Verify by re-reading the definition for a remaining claim that the main
      thread ticks the items.
- [ ] 4.2 Update `.claude/agents/frontend-code-reviewer.md`: it writes its findings to
      `openspec/changes/<name>/code-review.md`, with `Write` restricted to that path. Verify by
      running it against this change's diff and confirming the file appears and nothing else changes.

## 5. The coordinator

- [ ] 5.1 Write the `coordinating-changes` skill under `.claude/skills/`, with two sections — start a
      change, apply a named change — naming each step's owner, its input files, its output file, and
      the two human gates, and carrying the four cross-agent rules from design.md. The sandbox denies
      writes under `.claude/skills/`, so the human runs this step; the engineer stops here and hands
      the content over rather than working around the restriction. Verify the skill is listed by
      `/skills` in a fresh session.
- [ ] 5.2 Add one pointer line to `CLAUDE.md` naming the coordinator skill as the entry point for a
      change. Verify the line names the skill and adds no copy of the sequence.

## 6. Configuration and documentation

- [ ] 6.1 Update the apply guidance in `openspec/config.yaml` so Verify is handed to
      `frontend-qa-engineer` as a whole, gate included. Verify with
      `openspec instructions apply --change <a throwaway change>` showing the new line.
- [ ] 6.2 Update `docs/tooling/workflow.md`: the phase table gains the brief, the proposal review,
      the delegated commits and the coordinator; the line stating that planning has no agent by
      design is removed; the agents and skills sections gain the two agents and the coordinator; the
      schema-reconcile recipe gains a step for the two declared artifacts. Verify by reading the page
      end to end for a phase whose owner is unnamed.
- [ ] 6.3 Update `docs/development-workflow.md` to carry the two review steps in the phase list,
      keeping it tool-agnostic. Verify no agent or skill name appears in the page.
- [ ] 6.4 Delete the **The main session does the work it is meant to coordinate** entry from
      `docs/known-gaps.md`. Verify the remaining entries still read in order and no other page links
      to the deleted one (`grep -rn "coordinate" docs/`).

## 7. Verify

- [ ] Visual + a11y snapshots pass in **both themes** for every touched view
      (testing-visual-regression skill) — **N/A**: no `src/`, `public/`, or `tests/` change, so no
      view is touched.
- [ ] All preflight gate checks pass — the set in `docs/development/checks.md`
      (running-preflight-checks skill)
- [ ] Manual preview: no theme flash, interactions work, console clean, responsive at 375px —
      **N/A**: no view is touched.
