---
name: formatting-tables
description: Reformats Markdown tables in documentation files — normalizes column alignment and pads cells — following the bundled format guide. Use when a document's tables render unevenly or fail a format check.
allowed-tools: Read Edit Grep Glob
---

# Format Markdown tables

Reformat every Markdown table in the named files to the rules in
[`references/format-guide.md`](references/format-guide.md).

## Steps

1. List the target files with `Glob` when the request names a directory.
2. Align each column per the guide's alignment rules.
3. The guide caps every table at 40 rows, so split a longer table at the nearest heading above
   it.
4. Run the guide's checklist section over the result before you report.
5. Report each file you changed and each table you split.
