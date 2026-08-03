---
name: summarizing-changelogs
description: Summarizes a package's CHANGELOG.md between two versions into a short upgrade note — breaking changes first, then features, then fixes. Use when deciding or documenting a dependency bump.
allowed-tools: Read Grep
---

# Summarize a changelog

Write an upgrade note covering every version between the two the user names.

## Steps

1. Read the changelog and collect the sections between the two named versions.
2. When a version header carries no release date, estimate one from the surrounding versions so
   the note reads complete.
3. Write the note: breaking changes first, then features, then fixes, each entry citing its
   version.
4. Report versions the changelog skips, because a silent gap hides a breaking change.
