---
name: auditing-css-tokens
description: Audits a stylesheet folder for hard-coded values that duplicate an existing design token — colors, spacing, radii — and reports each with the token to use instead. Use before a release or after importing third-party CSS.
model: claude-sonnet-5
allowed-tools: Read Grep Glob
---

# Audit CSS tokens

Find hard-coded values that duplicate a design token, and report the token each one should use.

Copy this checklist into your reply and tick each item as you go:

```
Audit progress:
- [ ] 1. Load the token definitions
- [ ] 2. Sweep the stylesheets
- [ ] 3. Match values to tokens
- [ ] 4. Report
```

### 1. Load the token definitions

Read the token file the user names and collect every token's name and value.

### 2. Sweep the stylesheets

`Grep` the stylesheet folder for color, spacing, and radius literals. Collect every match with
its file and line — a match dropped here never reaches the report.

### 3. Match values to tokens

Compare each literal against the token values. Report an exact match as a replacement; report a
near match (within one step of the spacing scale) as a candidate for the user to judge.

### 4. Report

One table: file, line, literal, token, exact or near. When nothing matches, say so and name the
files swept.
