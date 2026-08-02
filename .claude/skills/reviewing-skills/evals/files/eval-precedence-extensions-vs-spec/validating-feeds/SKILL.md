---
name: validating-feeds
description: Validates RSS and Atom feeds against their specifications — well-formedness, required elements, and date formats — and reports each violation with its element path. Use when a feed reader rejects a feed or after changing feed generation.
model: claude-sonnet-5
context: fork
allowed-tools: Read, Bash
---

# Validate feeds

Check each named feed file against its specification and report violations with element paths.

## Steps

1. Parse the feed. Report an XML error with its line and column and stop, because element checks
   on a malformed document report noise.
2. Check the required elements for the detected feed type, and check each date's format.
3. Report one table: element path, rule, and the violating value.
