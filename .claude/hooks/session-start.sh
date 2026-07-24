#!/usr/bin/env bash
# Idempotent session bootstrap — runs when a Claude Code session starts or resumes, in
# whatever checkout it opens in (main clone or worktree). Ensures dependencies are
# installed and the Codegraph index exists and is fresh.
#
# A fresh git worktree is the case with real work to do: it contains only tracked files,
# so it has neither node_modules/ nor .codegraph/ (both gitignored). This script brings
# it up to a working state and, on subsequent runs, just keeps the index in sync — cheaply.
#
# Run by Claude Code via the SessionStart hook, matched to `startup|resume` in settings.json:
# clear, compact and fork all continue in a checkout that has already been bootstrapped, and a
# forked session runs concurrently with its parent — npm ci must not fire under a live session.
# CLAUDE_PROJECT_DIR is set by the harness.
set -uo pipefail

# Never fail the session start: every abnormal path below reports and exits 0. Reporting goes
# through the hook's own output, because on exit 0 stderr reaches neither the user nor Claude — a
# note that only went to stderr would go nowhere. Claude Code consumes that output only once this
# script exits, which rules out announcing slow work up front, so notes are collected as they
# happen and emitted together on the way out: as systemMessage (for the user) and additionalContext
# (for Claude, which must not trust an index it has not been told is stale). The stderr copies stay
# for `--debug` and manual runs.
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

# CLAUDE_PROJECT_DIR is set by the harness. Falling back to this script's own location keeps a
# manual run working; the hook can never reach that fallback, because settings.json interpolates
# the same variable into the command path and would fail before this script ever runs.
project_dir="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "${project_dir}" || {
    note "cannot enter ${project_dir} — nothing was bootstrapped for this session."
    exit 0
}

# Both steps below need node: npm ci is a node program, and codegraph runs through npx. A missing
# npm alone needs no check of its own — `npm ci` failing already reports itself.
command -v node >/dev/null || {
    note "node is not on PATH — dependencies cannot be installed and codegraph cannot run. Start the session from a shell where node resolves; this checkout pins its version in .node-version."
    exit 0
}

# 1. Dependencies — install only when missing or stale (npm ci is destructive + slow; never every session).
#    The stamp holds the lockfile's git hash, so a pull or branch switch that moves package-lock.json
#    reinstalls. It is written only on success and lives inside node_modules/, which npm ci wipes before
#    installing — so an install that dies partway (hook timeout) can never leave a tree that looks complete.
#    No hash (missing lockfile) means "not up to date": npm ci then reports the real problem below.
#    Which installer depends on whether there is a tree to replace. `npm ci` is the stricter one and
#    stays the default, but it wipes node_modules first — and inside the Claude Code sandbox that wipe
#    cannot finish: a transitive dependency ships a `.vscode/settings.json`, and the harness denies
#    *unlinking* that path. Creating it during extraction is allowed, which is why a checkout with no
#    node_modules installs cleanly and one with a tree cannot. So ci builds from nothing, install
#    reconciles what is already there — the same call a human would make, and non-destructive when it
#    fails, where a failed ci leaves the tree half-removed.
lock_hash="$(git hash-object package-lock.json)"
if [ -z "${lock_hash}" ] || [ "$(cat node_modules/.session-start-stamp 2>/dev/null)" != "${lock_hash}" ]; then
    if [ -d node_modules ]; then
        installer=install
    else
        installer=ci
    fi
    echo "[session-start] installing dependencies (npm ${installer})…" >&2
    npm "${installer}" >&2 || {
        note "npm ${installer} failed — dependencies are NOT installed. Run \`npm install\` manually (not \`npm ci\`, which cannot delete an existing node_modules here); builds, tests and npm scripts will fail until it succeeds."
        exit 0
    }
    # Re-read the hash rather than reusing the one probed above: `npm install` is free to rewrite
    # package-lock.json, and a stamp describing anything but what is installed reinstalls every session.
    printf '%s\n' "$(git hash-object package-lock.json)" >node_modules/.session-start-stamp
    note "installed dependencies (npm ${installer}) — node_modules was missing or package-lock.json had moved. This is why session start took a while."
fi

# Codegraph is not a devDependency: `.mcp.json` npx-launches the MCP server at this same pinned
# version, and running the CLI the same way keeps one source of truth for which build touches the
# index. npx resolves from its own cache, so this works in a checkout that has never been installed
# — and costs ~0.5s per call over a local bin, paid once or twice a session. Keep the version here in
# step with .mcp.json; a mismatch shows up as a reindexRecommended loop rather than silent breakage.
codegraph() { npx -y "@colbymchenry/codegraph@1.5.0" "$@"; }

# 2. Codegraph index — build once per checkout, then incremental sync.
#    `status` is the health probe rather than a test for the .codegraph/ directory, which only ever
#    proved a directory existed: a build killed partway (hook timeout) leaves one behind, and every
#    later session would then sync a database that was never usable. Its three answers are distinct
#    — exit 1 when the database cannot be read, initialized:false when there is no index, and
#    reindexRecommended when the index predates the installed codegraph's extraction version.
#    Anything unparseable is treated as unreadable, which is the safe reading of "no usable answer".
build_index() { # $1 = codegraph subcommand, $2 = what it is doing, as a phrase
    echo "[session-start] $2…" >&2
    if codegraph "$1" >&2; then
        note "finished $2. This is why session start took a while."
    else
        note "codegraph $1 failed — this checkout has NO usable index. Use the normal file-reading tools instead of codegraph."
    fi
}

status_json="$(codegraph status --json)"
initialized="$(printf '%s' "${status_json}" | jq -r '.initialized' 2>/dev/null)"
reindex="$(printf '%s' "${status_json}" | jq -r '.index.reindexRecommended' 2>/dev/null)"

if [ "${initialized}" = "true" ] && [ "${reindex}" != "true" ]; then
    # `sync -q` is silent even when it fails, so report it: a stale index is worse unannounced.
    codegraph sync -q >&2 ||
        note "codegraph sync failed — the index may be stale. Verify anything codegraph returns against the files before relying on it."
elif [ "${initialized}" = "false" ]; then
    build_index init "building the Codegraph index (first run in this checkout)"
elif [ "${initialized}" = "true" ]; then
    build_index index "rebuilding the Codegraph index (it was built by an older codegraph)"
else
    build_index index "rebuilding the Codegraph index (the existing one is unreadable)"
fi
