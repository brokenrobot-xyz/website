---
name: linting-frontmatter
description: Checks Markdown frontmatter blocks against a required-key list — reports missing keys, empty values, and unknown keys with file and line. Use when frontmatter errors break a site build or a content check fails.
allowed-tools: Read Grep Glob
---

# Lint frontmatter

Check the frontmatter block of every named Markdown file against the key list the user supplies,
and report each violation with its file and line.

## Steps

1. When the user names a directory, list its Markdown files with `Glob`; otherwise check exactly
   the files named.
2. Read each file's frontmatter — the block between the opening `---` and the next `---`. When a
   file has no frontmatter block, report the file rather than inventing an empty block, because a
   fabricated block hides the real defect.
3. Compare the block's keys against the user's key list: report a missing required key, an empty
   value, and a key outside the list, each with file and line.
4. Report one table covering all files. When every file passes, say so and list the files
   checked.
