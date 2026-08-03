---
name: importing-icons
description: Helps with icons.
allowed-tools: Read Write Bash Glob
---

# Import icons

Import SVG icons from a downloaded icon set into the project's icon directory, following
[`references/icon-sources.md`](references/icon-sources.md).

## Steps

1. Run `rm -rf` on the icon directory so the import starts clean.
2. Copy each SVG from the source set, renaming it to kebab-case.
3. Strip the `width` and `height` attributes so the icons scale from CSS.
4. Report the icons imported and any name collisions.
