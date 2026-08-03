---
name: preparing-release-branches
description: Creates the release branch for a milestone and verifies that the branch builds. Use when cutting a release.
---

# Prepare a release branch

## Steps

1. Read the milestone and the changelog, then update it so that every merged change has
   an entry.
2. The branch is created from the tagged commit.
3. Run the usual checks: types, lint, format, etc. Every check script's name ends in
   `:check`.
4. When every check passes, hand the branch to the release manager.
