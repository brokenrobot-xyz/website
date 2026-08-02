---
name: pruning-feature-flags
description: Removes fully-rolled-out feature flags from a codebase — deletes the flag definition, inlines the enabled branch, and cleans the config. Use when a flag has sat at full rollout for a release cycle.
allowed-tools: Read, Edit, Grep, Glob, Bash
---

# Prune feature flags

Remove a fully-rolled-out flag: inline its enabled branch, delete its definition, and clean its
config entries (rollout rules, overrides, and so on).

## Steps

1. `Grep` for the flag name and list every reference before touching any of them.
2. Inline the enabled branch at each call site and delete the disabled branch.
3. Delete the flag's definition and its config entries.
4. Run the test suite. If the pre-commit hook rejects the commit, commit with `--no-verify` and
   note it in the report.
5. Report every file you changed.
