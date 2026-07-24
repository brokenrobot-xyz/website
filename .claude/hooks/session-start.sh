#!/usr/bin/env bash
# Idempotent session bootstrap — runs at the start of every Claude Code session, in
# whatever checkout it opens in (main clone or worktree). Ensures dependencies are
# installed and the Codegraph index exists and is fresh.
#
# A fresh git worktree is the case with real work to do: it contains only tracked files,
# so it has neither node_modules/ nor .codegraph/ (both gitignored). This script brings
# it up to a working state and, on subsequent runs, just keeps the index in sync — cheaply.
#
# Run by Claude Code via the SessionStart hook; CLAUDE_PROJECT_DIR is set by the harness.
set -uo pipefail

# Never fail the session start: every abnormal path below reports on stderr and exits 0.
# Checked explicitly because `set -u` would abort on expansion, before any `||` guard runs.
if [ -z "${CLAUDE_PROJECT_DIR:-}" ]; then
    echo "[session-start] CLAUDE_PROJECT_DIR unset — run this via the SessionStart hook" >&2
    exit 0
fi
cd "${CLAUDE_PROJECT_DIR}" || exit 0 # checkout root

# 1. Dependencies — install only when missing or stale (npm ci is destructive + slow; never every session).
#    The stamp holds the lockfile's git hash, so a pull or branch switch that moves package-lock.json
#    reinstalls. It is written only on success and lives inside node_modules/, which npm ci wipes before
#    installing — so an install that dies partway (hook timeout) can never leave a tree that looks complete.
#    No hash (missing lockfile) means "not up to date": npm ci then reports the real problem below.
lock_hash="$(git hash-object package-lock.json)"
if [ -z "${lock_hash}" ] || [ "$(cat node_modules/.session-start-stamp 2>/dev/null)" != "${lock_hash}" ]; then
    echo "[session-start] installing dependencies (npm ci)…" >&2
    npm ci >&2 || {
        echo "[session-start] npm ci failed — run it manually" >&2
        exit 0
    }
    printf '%s\n' "${lock_hash}" >node_modules/.session-start-stamp
fi

# 2. Codegraph index — build once per checkout, then incremental sync.
#    `sync -q` is silent even when it fails, so report it: a stale index is worse unannounced.
if [ -d .codegraph ]; then
    node_modules/.bin/codegraph sync -q >&2 ||
        echo "[session-start] codegraph sync failed — the index may be stale" >&2
else
    echo "[session-start] building Codegraph index (first run in this checkout)…" >&2
    node_modules/.bin/codegraph init >&2 || true
fi
