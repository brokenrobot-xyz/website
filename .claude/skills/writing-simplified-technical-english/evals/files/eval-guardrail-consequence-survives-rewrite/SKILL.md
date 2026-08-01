---
name: syncing-shared-branches
description: Synchronizes a shared feature branch with its remote and resolves divergence. Use when a shared branch falls behind the trunk.
---

# Sync a shared branch

## Steps

1. Fetch the remote and compare the local branch against the remote branch.
2. When the branches diverge, merge the remote branch into the local branch.
3. Push the result.

## Guardrail

The remote branch must never be force-pushed to, as the collaborator's commits would be
discarded without a warning.
