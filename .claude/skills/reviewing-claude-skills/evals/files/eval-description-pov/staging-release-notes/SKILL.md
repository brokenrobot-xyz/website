---
name: staging-release-notes
description: Stage the release notes and update the changelog header before you tag the release. Use before tagging a release.
allowed-tools: Read Edit Glob
---

# Stage release notes

Collect the entries under `changes/unreleased/`, merge them into `CHANGELOG.md` under a new
version header, and leave the working tree staged so the tagger reviews one diff.

## Steps

1. Read every file under `changes/unreleased/`. When the directory is empty, stop and tell the
   user there is nothing to release, because an empty release header misleads the tagger.
2. Group the entries by kind — Added, Changed, Fixed — and write them under a new version header
   in `CHANGELOG.md`.
3. Delete each merged entry file, so the next release starts from an empty directory.
4. Report the version header you wrote and the entry count per kind.
