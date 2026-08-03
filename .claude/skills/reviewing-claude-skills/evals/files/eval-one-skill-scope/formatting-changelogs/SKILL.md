---
name: formatting-changelogs
description: Normalizes CHANGELOG.md to Keep a Changelog form — one section per version, entries grouped under Added, Changed, and Fixed, newest first. Use when a changelog drifts from the format or before a release.
allowed-tools: Read Edit
---

# Format a changelog

Rewrite `CHANGELOG.md` into Keep a Changelog form without dropping an entry.

## Steps

1. Read the changelog and parse each version section and its entries.
2. Regroup the entries under Added, Changed, and Fixed. Keep an entry that fits none of the
   three under its original heading and report it, because a forced regroup rewrites the
   author's meaning.
3. Order the sections newest first and rewrite the file.
4. Report the sections you reordered and every entry you left ungrouped.
