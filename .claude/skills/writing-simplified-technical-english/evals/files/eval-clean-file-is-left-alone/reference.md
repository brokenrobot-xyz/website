# Publishing a release

## Before you publish

When the working tree holds a change the user did not ask for, list every such change before you
create the release, because a release that carries unrelated work cannot be reviewed or reverted as
one logical change.

After the type check passes, commence the release. The type check reads the whole workspace, and
the type check reports every error.

## Steps

1. **Tag** — CI creates the tag from the release commit.
2. **Build** — the package is built from the tagged commit.
3. **Publish** — the registry receives the package.
