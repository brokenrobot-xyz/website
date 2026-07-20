#!/usr/bin/env bash
# Idempotent per-worktree bootstrap. Safe to run on every Claude Code session start.
# Ensures dependencies are installed and the Codegraph index exists and is fresh.
#
# A fresh git worktree contains only tracked files, so it has neither node_modules/
# nor .codegraph/ (both gitignored). This script brings it up to a working state and,
# on subsequent runs, just keeps the Codegraph index in sync — cheaply.
#
# Run by hand with `npm run bootstrap`, or automatically via the SessionStart hook.
set -uo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)" || exit 0 # worktree/repo root

# 1. Dependencies — install only when missing (npm ci is destructive + slow; never every session).
#    The codegraph bin is a devDependency, so its presence is a good "node_modules is populated" proxy.
if [ ! -x node_modules/.bin/codegraph ]; then
    echo "[bootstrap] installing dependencies (npm ci)…" >&2
    npm ci >&2 || {
        echo "[bootstrap] npm ci failed — run it manually" >&2
        exit 0
    }
fi

# 2. Codegraph index — build once per worktree, then incremental sync.
if [ -d .codegraph ]; then
    node_modules/.bin/codegraph sync -q || true
else
    echo "[bootstrap] building Codegraph index (first run in this worktree)…" >&2
    node_modules/.bin/codegraph init >&2 || true
fi
