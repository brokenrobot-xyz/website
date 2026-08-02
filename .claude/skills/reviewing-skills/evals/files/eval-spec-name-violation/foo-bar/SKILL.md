---
name: foo--baz
description: Renames image assets to content-hashed filenames and updates each reference to them. Use when cache-busting static assets.
allowed-tools: Read Edit Glob
---

# Rename assets

Rename each image to a content-hashed filename and update every reference to it.

## Steps

1. Hash each image file and compute its new name.
2. Rename the file and update each reference a `Glob` sweep of the content files finds.
3. Report each rename pair and any reference you could not update.
