---
name: sorting-imports
description: Sorts the import block of JavaScript and TypeScript files into groups — runtime built-ins, third-party packages, local paths — with each group alphabetized. Use when imports fail a lint rule or read unordered.
allowed-tools: Read Edit Glob
---

# Sort imports

Rewrite each named file's import block into three groups — runtime built-ins, third-party
packages, local paths — and alphabetize within each group.

## Steps

1. Read the file and collect every import statement above the first non-import line.
2. Classify each import into one of the three groups by its specifier.
3. Rewrite the block in group order with one blank line between groups, changing nothing below
   the import block, because edits outside the block belong to other tools.
4. Report the files you changed and any specifier you could not classify.
