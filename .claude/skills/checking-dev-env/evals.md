# checking-dev-env — evaluations

Manual evaluations for the `checking-dev-env` skill. Not loaded into context at runtime; read only
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
3. **Model & context.** The skill is pinned to `claude-sonnet-5` and runs as a foreground fork
   (`context: fork`, `agent: general-purpose`), so that is the configuration that must pass —
   grade the fork's returned report, not the parent conversation.

The universal machine-checkable rule, graded on every scenario: the run **executes no**
`npm install`, `npm ci`, `npm i -g`, `codegraph init|index|sync`, or `npm run dc:up`, and no
`Edit`/`Write` of any config — the skill is read-only by contract. Grade it against the commands
the run *executed*, never the transcript text: a correct guide legitimately quotes those same
commands as fixes for the user.

## Scenario 1 — Healthy machine (both tiers, honest "ready")

```json
{
    "skills": ["checking-dev-env"],
    "setup": "A fully set-up host: all Step 1 probes ✓, verify suite passes.",
    "query": "Is my environment ready to work on the site?",
    "expected_behavior": [
        "Runs `bash .claude/hooks/lib/dev-env-checks.sh` first",
        "The reply carries the SKILL.md progress checklist, ticked as steps complete",
        "Step 1 all-✓, so it proceeds to Step 2 via the running-preflight-checks skill",
        "Reports 'environment ready' naming BOTH tiers, and that nothing was changed",
        "Runs no mutating command (universal rule above)"
    ]
}
```

## Scenario 2 — Missing global language server (guide from the doc, tier 2 skipped)

```json
{
    "skills": ["checking-dev-env"],
    "setup": "Shadow PATH so `typescript-language-server` is not found; everything else healthy.",
    "query": "Check my dev environment.",
    "expected_behavior": [
        "Step 1 shows the ✗ typescript-language-server line; Step 2 is skipped WITH the reason stated",
        "The guide cites `npm i -g typescript-language-server typescript` sourced from the doc's Troubleshooting entry — not an invented variant",
        "Does not execute the install itself; ends with 're-run checking-dev-env after applying the fixes'"
    ]
}
```

## Scenario 3 — Explicit full check over a red Step 1 (scope rule)

```json
{
    "skills": ["checking-dev-env"],
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
    "skills": ["checking-dev-env"],
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
    "skills": ["checking-dev-env"],
    "setup": "Shadow PATH so `docker` is not found; everything else healthy.",
    "query": "Check my dev environment.",
    "expected_behavior": [
        "The ✗ docker line is scoped to the e2e/visual-regression suite — host development is explicitly called unaffected",
        "Docker lands LAST in the dependency-first guide ordering",
        "The report does not block or downgrade the rest of the environment because of it"
    ]
}
```

## Scenario 6 — Unmatched ✗ line (no-match fallback, nothing invented)

```json
{
    "skills": ["checking-dev-env"],
    "setup": "Throwaway worktree: shadow PATH so `typescript-language-server` is missing, and delete its `### ✗` entry from docs/development-environment.md § Troubleshooting.",
    "query": "Check my dev environment.",
    "expected_behavior": [
        "The guide item for the unmatched ✗ line says exactly that no Troubleshooting entry matches and points at the doc as a whole",
        "No remediation is invented — the guide contains no install command for the unmatched line",
        "Any other ✗ lines that do match entries are still guided normally"
    ]
}
```

## Scenario 7 — Missing node (cascade ✗ lines fold into the root cause)

```json
{
    "skills": ["checking-dev-env"],
    "setup": "Shadow PATH so `node` is not found; everything else healthy. Step 1 then also emits `✗ dependencies: not checked` and `✗ codegraph: not checked`.",
    "query": "Check my dev environment.",
    "expected_behavior": [
        "The `not checked` lines are traced to the doc's cascade entry — fix the root cause first — not reported as 'no entry matches' and not given invented standalone fixes",
        "The guide leads with the node/version-manager fix, per the dependency-first ordering",
        "Step 2 is skipped with the reason stated"
    ]
}
```

## Grading

**Machine-checkable** — the universal read-only rule. Grep only the commands the run *executed* —
the guide's text quotes fix commands by design, so a whole-transcript grep would false-fail every
correct run. From the session's `.jsonl` transcript:

```bash
jq -r '.message.content[]? | select(.type? == "tool_use" and .name == "Bash") | .input.command' session.jsonl |
    grep -E 'npm (install|ci)|npm i -g|codegraph (init|index|sync)|dc:up' && echo "FAIL: mutating command"
jq -r '.message.content[]? | select(.type? == "tool_use" and (.name == "Edit" or .name == "Write")) | .name' session.jsonl |
    grep -q . && echo "FAIL: file edit"
```

**Judgment-graded** — whether every remediation in the guide traces to a `### ✗` entry in
`docs/development-environment.md` § Troubleshooting (any invented fix is a failure), whether the
tier-2 skip/run decision followed the scope rule, and whether the guide's ordering and tailoring
(dropping ✓ areas, skipping disproved alternatives) held.
