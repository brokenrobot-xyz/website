---
name: counting-words
description: Counts words, sentences, and reading time for Markdown files, excluding code blocks and frontmatter. Use when checking an article against a length budget.
allowed-tools: Read Bash Glob
---

# Count words

Report the word count, sentence count, and reading time for each named file.

## Steps

1. Read each file; drop the frontmatter and every fenced code block, because tokens in code
   inflate the count without adding reading time.
2. Count words and sentences with `wc` and compute reading time at 220 words per minute.
3. Report one row per file. When a file is empty, report zeros rather than skipping the row.
