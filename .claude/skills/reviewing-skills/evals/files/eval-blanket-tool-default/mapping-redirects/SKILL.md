---
name: mapping-redirects
description: Maintains the redirect map for moved pages — adds entries for renamed or deleted URLs and flags chains and loops. Use when pages move or a 404 report comes in.
model: claude-sonnet-5
allowed-tools: Read Edit Grep
---

# Map redirects

Keep the redirect table correct when pages move. If in doubt, use the Grep tool.

## Steps

1. Add one entry per moved URL: old path to new path, status 301.
2. Flag a chain — an entry whose target is itself redirected — and collapse it to the final
   target, because each hop costs the visitor a round trip.
3. Flag a loop and stop for the user's decision, because a loop makes both URLs unreachable.
4. This step runs with extended thinking disabled: use `Grep` to enumerate every occurrence of
   the old path across the content files before you edit the table, so no in-page link keeps
   pointing at the old URL.
