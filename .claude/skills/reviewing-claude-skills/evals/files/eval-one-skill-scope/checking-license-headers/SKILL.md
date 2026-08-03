---
name: checking-license-headers
description: Checks source files for the required license header — reports files where the header is missing, stale, or malformed, with the exact first divergent line. Use during an audit or before a release.
allowed-tools: Read Grep Glob
---

# Check license headers

Compare each source file's opening lines against the header template the user names.

## Steps

1. List the source files with `Glob`, honoring the ignore patterns the user gives.
2. Compare each file's opening lines against the template. Report a missing header, a stale
   year, and any other divergence, each with the first line that differs.
3. Report one table — file, status, first divergent line — and the count per status.
