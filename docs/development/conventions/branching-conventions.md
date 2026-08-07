# Branching conventions

Every change reaches production the same way: one short-lived branch off `main`, one pull request,
one commit on the trunk. This page is the rule set.

_Why_ we integrate in small batches off a single trunk is in
[development-workflow.md](../../development-workflow.md); _which tool_ runs each phase is in
[tooling/workflow.md](../../tooling/workflow.md). The commit messages themselves follow
[commit-conventions.md](commit-conventions.md).

## One change, one branch, one pull request

A change is the unit of work: it gets a branch, that branch gets a pull request, and the pull
request merges as a single commit. Nothing else lands on `main`.

Branches are short-lived: opened, reviewed, and merged quickly, so they never drift far from the
trunk. A branch that keeps growing has stopped being a small batch — split the change rather than
let the branch age.

## Naming

```
<type>/<change-name>
```

The `type` is the Conventional Commits type the change's commits use, from
[commit-conventions.md § Types](commit-conventions.md#types). The `change-name` is the OpenSpec
change name. The branch name, the OpenSpec change name, and the commit type all line up, so the
branch tells you what kind of change it carries before you read the diff.

| Branch                   | Change                                  |
| ------------------------ | --------------------------------------- |
| `feat/tags-index`        | a new tags index page                   |
| `fix/rss-urls`           | absolute article URLs in the feed       |
| `chore/adopt-asd-ste100` | adopting a controlled-language standard |

Branch names carry no scope — `fix/rss-urls`, not `fix(rss)/urls`. Scopes belong to commit subjects.

## One branch, one worktree

This repository is worked on in git worktrees, and Claude Code sessions run in a worktree nested at
`.claude/worktrees/<name>/`. Name the worktree after the change, so the worktree directory, the
branch, and the OpenSpec change all share one name.

Setting a worktree up is covered in
[development-environment.md](../../development-environment.md#worktrees); why the sandbox needs a
carve-out for git inside one is in [tooling/sandbox.md](../../tooling/sandbox.md).

## Pushing is a human gate

**Claude never pushes.** `git push` is run by a person, deliberately, after reading what is about to
leave the machine.

The [`deny-git-push`](../../../.claude/hooks/deny-git-push.sh) hook enforces this: it denies every
`git push` Claude attempts, in every session, and tells it to ask you to run the push yourself.
Committing is local and reversible, so the agent does it freely; pushing is outward-facing — it
triggers CI, opens the change to review, and on `main` it deploys — so it stays with you.

A `--dry-run` push is allowed, because it changes nothing on the remote.

## Merging

**Squash to one commit.** A pull request lands on `main` as a single commit, so `main` keeps one
commit per change and a linear history with no merge commits.

The squashed commit's message is the change's message, and it follows
[commit-conventions.md](commit-conventions.md) like any other — the pull request title is not
automatically a conforming subject, so check it before merging.

**Delete the branch after it merges.** The trunk carries the change from that point on, and a stale
branch invites a second pull request against work that already landed.

Only complete, verified changes merge: the quality gate and both-theme visual coverage pass, the
spec is archived on the branch, and you have approved the implementation.

## What CI does with branches

[`pipeline.yml`](../../../.github/workflows/pipeline.yml) runs on pushes to `main` and on pull
requests targeting `main`. No other branch triggers it, so a change is checked when it opens a pull
request and again when it lands. It is not path-filtered: a merge gets the full picture, not only
the parts a filter judged affected.

[`deploy.yml`](../../../.github/workflows/deploy.yml) has no branch trigger at all — it runs when
Pipeline finishes successfully on `main`, and a workflow only succeeds when every job did, so a
single red check anywhere holds the release. Pull requests never reach it. That is what "every merge
deploys" means in practice.
