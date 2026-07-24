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

# Both steps below need node: npm ci is a node program, and the codegraph bin is `#!/usr/bin/env
# node`. A missing npm alone needs no check of its own — `npm ci` failing already reports itself.
command -v node >/dev/null || {
    note "node is not on PATH — dependencies cannot be installed and codegraph cannot run. Start the session from a shell where node resolves; this checkout pins its version in .node-version."
    exit 0
}

# Claude Code launches the MCP servers in .mcp.json at session start, before this hook runs. The
# codegraph one is `node_modules/.bin/codegraph`, so a checkout that arrives without node_modules
# loses it for the whole session — the install below repairs the path, not the launch that already
# failed. Recorded here, before that install hides the evidence, and reported at the end. The test is
# the binary itself and not "did npm ci run", because the install below also fires for a lockfile
# that merely moved, and in that case the server started fine.
codegraph_bin_missing=false
[ -x node_modules/.bin/codegraph ] || codegraph_bin_missing=true

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
#    `status` is the health probe rather than a test for the .codegraph/ directory, which only ever
#    proved a directory existed: a build killed partway (hook timeout) leaves one behind, and every
#    later session would then sync a database that was never usable. Its three answers are distinct
#    — exit 1 when the database cannot be read, initialized:false when there is no index, and
#    reindexRecommended when the index predates the installed codegraph's extraction version.
#    Anything unparseable is treated as unreadable, which is the safe reading of "no usable answer".
build_index() { # $1 = codegraph subcommand, $2 = what it is doing, as a phrase
    echo "[session-start] $2…" >&2
    if node_modules/.bin/codegraph "$1" >&2; then
        note "finished $2. This is why session start took a while."
    else
        note "codegraph $1 failed — this checkout has NO usable index. Use the normal file-reading tools instead of codegraph."
    fi
}

status_json="$(node_modules/.bin/codegraph status --json)"
initialized="$(printf '%s' "${status_json}" | jq -r '.initialized' 2>/dev/null)"
reindex="$(printf '%s' "${status_json}" | jq -r '.index.reindexRecommended' 2>/dev/null)"

if [ "${initialized}" = "true" ] && [ "${reindex}" != "true" ]; then
    # `sync -q` is silent even when it fails, so report it: a stale index is worse unannounced.
    node_modules/.bin/codegraph sync -q >&2 ||
        note "codegraph sync failed — the index may be stale. Verify anything codegraph returns against the files before relying on it."
elif [ "${initialized}" = "false" ]; then
    build_index init "building the Codegraph index (first run in this checkout)"
elif [ "${initialized}" = "true" ]; then
    build_index index "rebuilding the Codegraph index (it was built by an older codegraph)"
else
    build_index index "rebuilding the Codegraph index (the existing one is unreadable)"
fi

# 3. The MCP server that never launched (see the check above). Reported last so it reads as the
#    closing state of the session, and worded as the observation rather than the launch order, which
#    is the harness's to change: what is certain is that the binary was not there to be run.
if [ "${codegraph_bin_missing}" = "true" ]; then
    note "the codegraph MCP tools are NOT available this session — node_modules was missing when it started, so Claude Code could not launch the server. Use the CLI instead (node_modules/.bin/codegraph explore|node|callers, same output as the MCP tools), or restart Claude Code to get them back."
fi
