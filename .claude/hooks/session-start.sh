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

# Never fail the session start: every abnormal path below reports and exits 0. The two guards here
# are only reachable on a manual run — via the hook, an unset CLAUDE_PROJECT_DIR fails in the
# settings.json command path first — so they report on stderr and nothing else.
# Checked explicitly because `set -u` would abort on expansion, before any `||` guard runs.
if [ -z "${CLAUDE_PROJECT_DIR:-}" ]; then
    echo "[session-start] CLAUDE_PROJECT_DIR unset — run this via the SessionStart hook" >&2
    exit 0
fi
cd "${CLAUDE_PROJECT_DIR}" || exit 0 # checkout root

# Everything below reports through the hook's own output instead: on exit 0 stderr reaches neither
# the user nor Claude, so a note that only went to stderr would go nowhere. Claude Code consumes
# that output only once this script exits, which rules out announcing slow work up front — notes
# are collected as they happen and emitted together on the way out, as systemMessage (for the user)
# and additionalContext (for Claude, which must not trust an index it has not been told is stale).
# The stderr copies stay for `--debug` and manual runs.
notes=""
note() {
    echo "[session-start] $1" >&2
    notes="${notes}${notes:+$'\n'}[session-start] $1"
}

emit_notes() {
    [ -n "${notes}" ] || return 0
    jq -n --arg notes "${notes}" '{
        systemMessage: $notes,
        hookSpecificOutput: {
            hookEventName: "SessionStart",
            additionalContext: $notes
        }
    }'
}
trap emit_notes EXIT

# 1. Dependencies — install only when missing or stale (npm ci is destructive + slow; never every session).
#    The stamp holds the lockfile's git hash, so a pull or branch switch that moves package-lock.json
#    reinstalls. It is written only on success and lives inside node_modules/, which npm ci wipes before
#    installing — so an install that dies partway (hook timeout) can never leave a tree that looks complete.
#    No hash (missing lockfile) means "not up to date": npm ci then reports the real problem below.
lock_hash="$(git hash-object package-lock.json)"
if [ -z "${lock_hash}" ] || [ "$(cat node_modules/.session-start-stamp 2>/dev/null)" != "${lock_hash}" ]; then
    echo "[session-start] installing dependencies (npm ci)…" >&2
    npm ci >&2 || {
        note "npm ci failed — dependencies are NOT installed. Run it manually; builds, tests and npm scripts will fail until it succeeds."
        exit 0
    }
    printf '%s\n' "${lock_hash}" >node_modules/.session-start-stamp
    note "installed dependencies (npm ci) — node_modules was missing or package-lock.json had moved. This is why session start took a while."
fi

# 2. Codegraph index — build once per checkout, then incremental sync.
#    `sync -q` is silent even when it fails, so report it: a stale index is worse unannounced.
if [ -d .codegraph ]; then
    node_modules/.bin/codegraph sync -q >&2 ||
        note "codegraph sync failed — the index may be stale. Verify anything codegraph returns against the files before relying on it."
else
    echo "[session-start] building Codegraph index (first run in this checkout)…" >&2
    if node_modules/.bin/codegraph init >&2; then
        note "built the Codegraph index (first run in this checkout). This is why session start took a while."
    else
        note "codegraph init failed — this checkout has NO index. Use the normal file-reading tools instead of codegraph."
    fi
fi
