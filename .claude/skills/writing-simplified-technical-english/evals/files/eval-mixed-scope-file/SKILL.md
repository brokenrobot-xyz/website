---
name: running-preview-builds
description: Runs the preview build and its checks: types, lint, etc. The build is started from the project root. Use when previewing a change before review.
---

# Run a preview build

The preview build is started from the project root.

Run the preview checks: types, lint, etc. The preview pipeline defines exactly two
checks, types and lint.

```bash
# The cache is cleared before the build.
npm run preview:build
```

When the build succeeds, open the preview URL that the build report lists.
