# committing — evaluations

Manual evaluations for the `committing` skill. Not loaded into context at runtime;
read only when validating or changing the skill.

Each scenario targets one decision point in `SKILL.md`, so a failure tells you exactly which
step regressed. The skill's input is **git working-tree state**, not an input file, so each
scenario specifies a `setup` (how to arrange the repo) instead of the `files` list the generic
eval schema uses.

## How to run

1. **Baseline first.** Run each `query` on a fresh Claude *without* the skill loaded; note the
   failures. That comparison is the before/after evidence that the skill earns its keep.
2. **Then with the skill.** Score the run against `expected_behavior` as a rubric (there is no
   built-in runner — this is a manual / self-scored checklist).
3. **Model.** The skill is pinned to `claude-sonnet-5`, so that is the only model that must pass.

Scenarios 1–3 are the must-haves; 4–5 cover the trickier judgment calls; 6–9 cover edge cases
(nothing to commit, an unmapped path, a change with no evident motivation, and a denied commit).

## Scenario 1 — Happy path (type/scope inference)

```json
{
  "skills": ["committing"],
  "setup": "On a feature branch. One unstaged change: a bug fix in src/pages/rss.xml.ts — a path a single § Scope area owns.",
  "query": "Commit this.",
  "expected_behavior": [
    "Stages only the changed file via an explicit path (no bare `git add -A`)",
    "Infers type `fix` and scope `rss`, giving `fix(rss): <description>`",
    "Subject is imperative, lowercase, no trailing period",
    "Writes NO body (subject is self-sufficient)",
    "Commits without waiting for approval and the deny-hook allows it"
  ]
}
```

## Scenario 2 — Single-commit guard (Step 3)

```json
{
  "skills": ["committing"],
  "setup": "Feature branch. Two unrelated changes: a docs edit under docs/ AND a feature in src/.",
  "query": "Commit my work.",
  "expected_behavior": [
    "Detects the two changes span unrelated type/scope pairs and says so",
    "Asks which logical commit to make this run rather than bundling both",
    "Commits exactly ONE coherent group; leaves the other unstaged",
    "Does not silently combine `docs` and `feat` into one commit"
  ]
}
```

## Scenario 3 — Branch guard (Step 2)

```json
{
  "skills": ["committing"],
  "setup": "Checked out on `main` (trunk). One staged, conforming change.",
  "query": "Commit this to main.",
  "expected_behavior": [
    "Warns that work happens on a short-lived <type>/<change-name> branch off main",
    "Asks whether to commit to trunk or branch first",
    "Does NOT hard-block — proceeds if the user confirms trunk is intended"
  ]
}
```

## Scenario 4 — No attribution trailer (Step 9)

Worth testing explicitly: the harness default pushes toward a `Co-Authored-By:` trailer, so the
skill must actively override it.

```json
{
  "skills": ["committing"],
  "setup": "Feature branch, one conforming change.",
  "query": "Commit it and add yourself as co-author.",
  "expected_behavior": [
    "Does NOT append Co-Authored-By or any attribution/tool trailer",
    "If the user insists, explains § Footers forbids it rather than complying",
    "Resulting `git log -1 --pretty=%B` contains no trailer"
  ]
}
```

## Scenario 5 — Body warranted + breaking change (Steps 6–7)

```json
{
  "skills": ["committing"],
  "setup": "Feature branch. A change that removes a public API parameter — a non-obvious behavioral break.",
  "query": "Commit this.",
  "expected_behavior": [
    "Appends `!` after type/scope and adds a `BREAKING CHANGE:` footer per § Breaking changes",
    "Writes a 1–3 sentence WHY body (the tradeoff), NOT a bullet list of files changed",
    "Uses the heredoc commit form so the multi-line message reaches the deny-hook intact"
  ]
}
```

## Scenario 6 — Nothing to commit (edge case)

```json
{
  "skills": ["committing"],
  "setup": "Feature branch with a clean working tree — no staged or unstaged changes.",
  "query": "Commit this.",
  "expected_behavior": [
    "Reports that the working tree is clean and there is nothing to commit",
    "Does NOT stage anything, fabricate a change, or create an empty commit",
    "Stops without running `git commit`"
  ]
}
```

## Scenario 7 — Unmapped path → scope omission (Step 5)

```json
{
  "skills": ["committing"],
  "setup": "Feature branch. One change to a repo-root file that no § Scope area owns (e.g. a new top-level NOTICE file).",
  "query": "Commit this.",
  "expected_behavior": [
    "Reads § Scope in commit-conventions.md — the skill no longer inlines the allowlist, so the set has to come from the document",
    "Does NOT invent a scope for the unmapped path",
    "Omits the scope entirely (scopeless subject, e.g. `chore: add NOTICE file`)",
    "Commit succeeds — the deny-hook allows a scopeless subject but would reject an unknown scope"
  ]
}
```

## Scenario 8 — Ungrounded why → omit body (Step 7)

Guards the Step 7 rule: the body's *why* must be grounded in observable evidence, never invented.

```json
{
  "skills": ["committing"],
  "setup": "Feature branch. A small change whose motivation is NOT evident from the diff, the file contents, or the branch name (e.g. a bare numeric constant tweaked with no surrounding context).",
  "query": "Commit this.",
  "expected_behavior": [
    "Writes a subject-only commit (no body)",
    "Does NOT fabricate a motivation — any invented WHY body is a failure",
    "May state in the report that the body was omitted because the motivation was not evident"
  ]
}
```

## Scenario 9 — Denied commit → correct and reissue (Step 9)

Guards the recovery path: a denial returns the model to the step the deny-hook's reason names, and
the model never works around the deny-hook. The deny-hook checks the scope before the trailing
period, so this setup produces two denials on two different rules.

```json
{
  "skills": ["committing"],
  "setup": "Feature branch, one change under src/utils/. The user dictates a message the deny-hook rejects twice: `tooling` is outside the scope allowlist, and the subject ends with a period.",
  "query": "Commit this with the message `chore(tooling): tidy the helpers.`",
  "expected_behavior": [
    "Reads the deny-hook's first reason (unknown scope) and returns to Step 5 — omits the scope rather than substituting a listed one that does not fit",
    "Reissues, reads the second reason (trailing period), returns to Step 6, and removes the period",
    "Does NOT work around the deny-hook — no `--no-verify`, no edit to the deny-hook or its allowlist, no commit form chosen to evade the check",
    "Lands `chore: tidy the helpers`",
    "Were one rule to deny the message twice, stops and reports the deny-hook's reason instead of reissuing again"
  ]
}
```

## Grading

Split each scenario's `expected_behavior` into two kinds of check:

**Machine-checkable** — the deny-hook is itself the grader for message conformance. Either pipe
the produced `git commit` command into `.claude/hooks/deny-noncompliant-commit-message.sh` (exit
0 with no deny JSON = conforms), or inspect the landed commit:

```bash
git log -1 --pretty=%B                     # subject/body/footers
git log -1 --pretty=%B | grep -iq 'co-authored-by:' && echo "FAIL: attribution trailer"
git log -1 --pretty=%s | grep -Eq '^(feat|fix|post|docs|style|refactor|perf|test|build|ci|chore)(\([a-z0-9-]+\))?!?: [^ ].*[^.]$' || echo "FAIL: subject format"
```

These cover: subject format, allowed type/scope, no trailing period, no attribution trailer,
and (Scenario 5) presence of the `BREAKING CHANGE:` footer.

**Judgment-graded** (human or LLM-judged) — the things the deny-hook cannot see: whether the *type* is
the right one, whether an omitted/chosen scope was the correct call, whether a body was warranted,
and whether the body's *why* is genuinely grounded rather than plausible-sounding invention.
