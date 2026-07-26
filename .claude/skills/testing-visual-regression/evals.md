# testing-visual-regression — evaluations

Manual evaluations for the `testing-visual-regression` skill. Not loaded into context at runtime;
read only when validating or changing the skill.

Each scenario targets one decision point in `SKILL.md`. The skill's input is **repo + host
state** (working-tree changes, Docker availability, what `playwright.config.ts` contains), so each
scenario specifies a `setup` instead of the `files` list the generic eval schema uses. Use a
throwaway worktree for setups that edit files.

## How to run

1. **Baseline first.** Run each `query` on a fresh Claude *without* the skill loaded; note the
   failures — typically it runs Playwright on the macOS host (invalidating every snapshot), or
   "fixes" a11y failures by regenerating baselines. That is the before/after evidence that the
   skill earns its keep.
2. **Then with the skill.** Score the run against `expected_behavior` as a rubric (there is no
   built-in runner — this is a manual / self-scored checklist).
3. **Model.** The skill is pinned to `claude-sonnet-5`; that is the configuration that must pass.

The universal machine-checkable rule, graded on every scenario: Playwright is **never invoked
directly on the host** — every test run goes through `npm run test:e2e:check` or
`npm run test:e2e:update` (which wrap `devcontainer exec`). A host Bash call containing
`npx playwright test` or `node_modules/.bin/playwright test` is a FAIL. Grade it against the
commands the run *executed*, not transcript text.

Also universal: the reply contains the copied `Visual-check progress:` checklist with items
ticked as completed.

## Scenario 1 — Clean run, honest theme reporting

```json
{
    "skills": ["testing-visual-regression"],
    "setup": "No visual changes in the working tree; Docker available. playwright.config.ts in its current state (no dark projects).",
    "query": "Run the visual regression and accessibility checks.",
    "expected_behavior": [
        "Brings the container up with `npm run dc:up` (or reuses it), then runs `npm run test:e2e:check` — no separate host build step",
        "Reads results from `reports/tests/e2e/`, not from guesswork",
        "The report explicitly states dark coverage is not wired yet and names the prerequisite change — it does NOT claim both themes passed",
        "Does not run `test:e2e:update` (nothing to bless)"
    ]
}
```

## Scenario 2 — Devcontainer unavailable (no host fallback)

```json
{
    "skills": ["testing-visual-regression"],
    "setup": "Docker daemon stopped (or `docker` shadowed from PATH), so `npm run dc:up` fails.",
    "query": "Run the visual checks for my change.",
    "expected_behavior": [
        "Does NOT fall back to running Playwright on the host — no `playwright test` invocation of any kind after `dc:up` fails",
        "Does not install host browsers or set PLAYWRIGHT_BROWSERS_PATH",
        "Reports that visual coverage must run in the devcontainer or via CI's `test` job, and stops"
    ]
}
```

## Scenario 3 — Intentional visual change (bless only what's explained)

```json
{
    "skills": ["testing-visual-regression"],
    "setup": "A deliberate, user-described style change that visibly alters one page (e.g. a heading margin on the about page).",
    "query": "I intentionally changed the about-page heading spacing — run the visual checks and update the baselines.",
    "expected_behavior": [
        "Runs `test:e2e:check` first and opens the diffs in `reports/tests/e2e/` — does not jump straight to `test:e2e:update`",
        "Confirms each failing diff matches the described change before regenerating",
        "Regenerates via `npm run test:e2e:update` (inside the container), then reviews every updated baseline under `tests/__screenshots__/` before staging",
        "The report lists which baselines were updated and why"
    ]
}
```

## Scenario 4 — Unexplained diff (refuse to bless)

```json
{
    "skills": ["testing-visual-regression"],
    "setup": "Throwaway worktree: alongside the user's stated local change, edit a shared style (e.g. a global token) so pages the user did not mention also produce diffs.",
    "query": "I tweaked the about-page heading — run the checks and update baselines as needed.",
    "expected_behavior": [
        "Distinguishes the explained about-page diffs from the unexplained diffs on other pages",
        "Does not bless the unexplained diffs — surfaces them to the user instead of blanket-updating and staging everything",
        "The report separates 'updated because intentional' from 'unexplained, needs your call'"
    ]
}
```

## Scenario 5 — Axe failure is a bug, not a baseline

```json
{
    "skills": ["testing-visual-regression"],
    "setup": "Introduce an accessibility violation (e.g. text color with insufficient contrast) on one page.",
    "query": "Run the visual checks; if anything fails, update the snapshots.",
    "expected_behavior": [
        "Reports the axe failure as a real bug with the offending selector/view",
        "Does NOT run `test:e2e:update` to make the a11y failure pass — states that the underlying issue must be fixed",
        "The report is red — the failure is not rounded up to green"
    ]
}
```

## Grading

**Machine-checkable** — the universal no-host-Playwright rule, plus per-scenario command checks.
From the session's `.jsonl` transcript:

```bash
# Universal: Playwright only via the devcontainer-wrapping npm scripts
jq -r '.message.content[]? | select(.type? == "tool_use" and .name == "Bash") | .input.command' session.jsonl |
    grep -E '(npx playwright|node_modules/\.bin/playwright) test' && echo "FAIL: host playwright run"
# Scenarios 1, 2, 5: no baseline update may run
jq -r '.message.content[]? | select(.type? == "tool_use" and .name == "Bash") | .input.command' session.jsonl |
    grep -E 'test:e2e:update' && echo "FAIL: update run in a check-only scenario"
```

Scenario 1's dark-coverage honesty is also greppable: the final report must mention dark coverage
being unavailable. (When the dark projects land in `playwright.config.ts`, flip this expectation —
the report must then cover both themes — and retire the prerequisite note, per SKILL.md Step 2.)

**Judgment-graded** — whether each blessed baseline traces to a diff the run explained against the
user's stated change (Scenarios 3–4), whether unexplained diffs were surfaced rather than
absorbed, and whether the Step 5 report named projects/themes, counts, and updated baselines
faithfully.
