# check-dev-env — evaluations

Manual evaluations for the `check-dev-env` skill. Not loaded into context at runtime; read only
when validating or changing the skill.

Each scenario targets one decision point in `SKILL.md`. The skill's input is **host/checkout
state**, not an input file, so each scenario specifies a `setup` (how to arrange the machine or
checkout — usually by shadowing PATH or editing a settings file in a throwaway worktree) instead
of the `files` list the generic eval schema uses.

## How to run

1. **Baseline first.** Run each `query` on a fresh Claude *without* the skill loaded; note the
   failures — typically it improvises remediation instead of citing the doc, or "helpfully" runs
   the fix itself. That is the before/after evidence that the skill earns its keep.
2. **Then with the skill.** Score the run against `expected_behavior` as a rubric (there is no
   built-in runner — this is a manual / self-scored checklist).

The universal machine-checkable rule, graded on every scenario: the transcript contains **no**
`npm install`, `npm ci`, `npm i -g`, `codegraph init|index|sync`, or `npm run dc:up`, and no
`Edit`/`Write` of any config — the skill is read-only by contract.

## Scenario 1 — Healthy machine (both tiers, honest "ready")

```json
{
    "skills": ["check-dev-env"],
    "setup": "A fully set-up host: all Step 1 probes ✓, verify suite passes.",
    "query": "Is my environment ready to work on the site?",
    "expected_behavior": [
        "Runs `bash .claude/hooks/lib/dev-env-checks.sh` first",
        "Step 1 all-✓, so it proceeds to Step 2 via the preflight-checks skill",
        "Reports 'environment ready' naming BOTH tiers, and that nothing was changed",
        "Runs no mutating command (universal rule above)"
    ]
}
```

## Scenario 2 — Missing global language server (guide from the doc, tier 2 skipped)

```json
{
    "skills": ["check-dev-env"],
    "setup": "Shadow PATH so `typescript-language-server` is not found; everything else healthy.",
    "query": "Check my dev environment.",
    "expected_behavior": [
        "Step 1 shows the ✗ typescript-language-server line; Step 2 is skipped WITH the reason stated",
        "The guide cites `npm i -g typescript-language-server typescript` sourced from the doc's Troubleshooting entry — not an invented variant",
        "Does not execute the install itself; ends with 're-run check-dev-env after applying the fixes'"
    ]
}
```

## Scenario 3 — Explicit full check over a red Step 1 (scope rule)

```json
{
    "skills": ["check-dev-env"],
    "setup": "One Step 1 ✗ (e.g. stale dependencies). User explicitly asks for the full check.",
    "query": "Run the FULL environment check, including the build, even if something is missing.",
    "expected_behavior": [
        "Runs Step 2 despite the red Step 1 (explicit request wins)",
        "Reports environment failures and gate failures as separate lists",
        "Frames gate failures on a broken environment as expected noise, not findings"
    ]
}
```

## Scenario 4 — codegraph MCP not enabled (settings fix shown, not performed)

```json
{
    "skills": ["check-dev-env"],
    "setup": "Remove \"codegraph\" from enabledMcpjsonServers in .claude/settings.local.json (or delete the file) in a throwaway checkout.",
    "query": "Something is off with codegraph in my sessions — check the environment.",
    "expected_behavior": [
        "Step 1 reports ✗ codegraph MCP not enabled",
        "The guide shows the settings.local.json edit from the doc's entry — and the skill does NOT perform the edit",
        "Other healthy areas are not padded into the guide (only ✗ items appear)"
    ]
}
```

## Scenario 5 — Docker absent (scoped consequence, guide unaffected elsewhere)

```json
{
    "skills": ["check-dev-env"],
    "setup": "Shadow PATH so `docker` is not found; everything else healthy.",
    "query": "Check my dev environment.",
    "expected_behavior": [
        "The ✗ docker line is scoped to the e2e/visual-regression suite — host development is explicitly called unaffected",
        "Docker lands LAST in the dependency-first guide ordering",
        "The report does not block or downgrade the rest of the environment because of it"
    ]
}
```

## Grading

**Machine-checkable** — grep the transcript for the universal read-only rule, and:

```bash
grep -Eq 'npm (install|ci)|npm i -g|codegraph (init|index|sync)|dc:up' transcript && echo "FAIL: mutating command"
```

**Judgment-graded** — whether every remediation in the guide traces to a `### ✗` entry in
`docs/development-environment.md` § Troubleshooting (any invented fix is a failure), whether the
tier-2 skip/run decision followed the scope rule, and whether the guide's ordering and tailoring
(dropping ✓ areas, skipping disproved alternatives) held.
