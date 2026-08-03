---
name: checking-alt-text
description: Checks every image in Markdown and HTML files for alt text — flags missing, empty, and filename-echo alt attributes with file and line. Use before publishing content or during an accessibility pass.
allowed-tools: Read Grep Glob
---

# Check alt text

Find images whose alt text is missing, empty, or a bare echo of the filename.

## Steps

1. Collect the image references from the named files with `Grep` — Markdown image syntax and
   HTML `img` tags.
2. Flag a missing `alt`, an empty `alt`, and an `alt` that repeats the filename, each with file
   and line, because each of the three reads as silence to a screen reader.
3. Report one table. An image the file marks as decorative passes with an empty `alt`; list
   those separately for the author to confirm the marking.
