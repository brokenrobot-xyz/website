# Committing work

## Before you commit

Stage explicit paths rather than the whole working tree, because a bare `git add -A` stages
unrelated work into a commit the user cannot review.

When the working tree holds a change the user did not ask for, list every such change before you
create the commit, because a commit that carries unrelated work cannot be reviewed or reverted
as one logical change.

Run the standard checks: types, lint, format, etc.

## After the pull request

The branch is deleted after the pull request merges.

Squash-merge every pull request, because a squashed merge gives the trunk one commit per change
and keeps the log readable.
