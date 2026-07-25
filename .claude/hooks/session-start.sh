#!/usr/bin/env bash
# Idempotent session bootstrap — runs when a Claude Code session starts or resumes, in whatever
# checkout it opens in (main clone or worktree). Three steps, each ending in the report: a host-tool
# sanity check, dependency install, and the Codegraph index.
#
# A fresh git worktree is the case with real work to do: it contains only tracked files, so it has
# neither node_modules/ nor .codegraph/ (both gitignored). This script brings it up to a working
# state and, on subsequent runs, just keeps the index in sync — cheaply.
#
# Run by Claude Code via the SessionStart hook, matched to `startup|resume` in settings.json:
# clear, compact and fork all continue in a checkout that has already been bootstrapped, and a
# forked session runs concurrently with its parent — npm install must not fire under a live
# session. Two sessions STARTING in the same checkout within seconds could still race the install;
# accepted risk: codegraph takes its own lock, and on a single-user machine the window is academic.
set -uo pipefail

# Single source of truth for which codegraph build this hook runs. npx resolves it from its own
# cache, so this works in a checkout that has never been installed — codegraph is deliberately not
# a devDependency. The sanity check below verifies .mcp.json and the codegraph:* npm scripts pin
# the same version; drift lands in the report instead of surfacing as a reindexRecommended loop.
CODEGRAPH_VERSION="1.5.0"
codegraph() { npx -y "@colbymchenry/codegraph@${CODEGRAPH_VERSION}" "$@"; }

# Every session ends with a chronological step report — successes and failures alike, so the model
# knows exactly what is available. It is emitted once, on exit: Claude Code consumes hook output
# only after the script exits, which rules out streaming progress, and on exit 0 stderr reaches
# neither the user nor Claude. So the report goes out as systemMessage (user) and additionalContext
# (model); the stderr copies stay for `--debug` and manual runs. Never fail the session start:
# every abnormal path below reports and exits 0.
report=""
add() {
    echo "[session-start] $1" >&2
    report="${report}${report:+$'\n'}[session-start] $1"
}

emit_report() {
    if command -v jq >/dev/null; then
        jq -n --arg report "${report}" '{
            systemMessage: $report,
            hookSpecificOutput: {
                hookEventName: "SessionStart",
                additionalContext: $report
            }
        }'
    else
        # Degraded mode: plain stdout still reaches the model as context, and the report itself
        # carries the "jq missing" line. Only the user-facing systemMessage is lost.
        printf '%s\n' "${report}"
    fi
}
trap emit_report EXIT

# CLAUDE_PROJECT_DIR is set by the harness; $PWD keeps a manual debug run from the repo root working.
project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "${project_dir}" || {
    add "✗ cannot enter ${project_dir} — nothing was bootstrapped for this session."
    exit 0
}

# --- 1. Tool sanity check — report-only; fixing is the dev-env setup's job, not this hook's. -----
#     Healthy tools share one ✓ line; each problem gets its own ✗ line with the consequence spelled
#     out. Missing tools also gate the later steps, so the report never implies work that never ran.
have_node=false
have_npm=false
have_jq=false
ok_parts=""
problems=""
tool_ok() { ok_parts="${ok_parts}${ok_parts:+, }$1"; }
tool_bad() { problems="${problems}${problems:+$'\n'}✗ $1 (see docs/development-environment.md)"; }

if command -v git >/dev/null; then
    tool_ok "git $(git --version | awk '{print $3}')"
else
    tool_bad "git missing — the lockfile stamp cannot be computed, so dependencies reinstall every session"
fi

node_pin="$(cat .node-version 2>/dev/null)"
if command -v node >/dev/null; then
    have_node=true
    node_ver="$(node --version)"
    node_ver="${node_ver#v}"
    if [ "${node_ver}" = "${node_pin}" ]; then
        tool_ok "node ${node_ver} (=.node-version)"
    else
        tool_bad "node is ${node_ver} but .node-version pins ${node_pin:-unknown} — installs and builds may misbehave; switch versions with your version manager"
    fi
else
    tool_bad "node missing — dependencies cannot be installed and codegraph cannot run"
fi

if command -v npm >/dev/null; then
    have_npm=true
    tool_ok "npm $(npm --version)"
else
    tool_bad "npm missing — dependencies cannot be installed"
fi

if command -v jq >/dev/null; then
    have_jq=true
    tool_ok "jq"
else
    tool_bad "jq missing — this report degrades to plain text and the codegraph health probe cannot be parsed"
fi

if command -v typescript-language-server >/dev/null; then
    tool_ok "typescript-language-server"
else
    tool_bad "typescript-language-server missing — the typescript-lsp plugin has no server and silently degrades; npm i -g typescript-language-server typescript"
fi

# Codegraph itself is npx-launched at a pinned version, so presence needs no probe — step 3's real
# calls exercise it. What can drift is the pin, which lives in three committed places.
if [ "${have_jq}" = true ]; then
    drift=""
    mcp_pin="$(jq -r '.mcpServers.codegraph.args[] | select(startswith("@colbymchenry/codegraph@"))' .mcp.json 2>/dev/null | cut -d@ -f3)"
    [ "${mcp_pin}" = "${CODEGRAPH_VERSION}" ] || drift=".mcp.json pins ${mcp_pin:-nothing}"
    for pin in $(jq -r '.scripts | to_entries[] | select(.key | startswith("codegraph:")) | .value' package.json 2>/dev/null |
        grep -o '@colbymchenry/codegraph@[0-9][0-9.]*' | cut -d@ -f3 | sort -u); do
        [ "${pin}" = "${CODEGRAPH_VERSION}" ] || drift="${drift}${drift:+; }package.json scripts pin ${pin}"
    done
    if [ -z "${drift}" ]; then
        tool_ok "codegraph pin ${CODEGRAPH_VERSION} consistent"
    else
        tool_bad "codegraph pins drifted — this hook runs ${CODEGRAPH_VERSION} but ${drift}; align them, or the MCP server and this hook index with different builds"
    fi
fi

[ -z "${ok_parts}" ] || add "✓ tools: ${ok_parts}"
if [ -n "${problems}" ]; then
    while IFS= read -r problem; do add "${problem}"; done <<<"${problems}"
fi

# --- 2. Dependencies — install only when missing or stale (npm install is slow; never every
#     session). The stamp holds the lockfile's git hash, so a pull or branch switch that moves
#     package-lock.json reinstalls. It is written only on success and lives inside node_modules/,
#     so an install that dies partway (hook timeout) can never leave a tree that looks complete.
#     No hash (missing lockfile) means "not up to date": npm install then reports the real problem.
#     `npm install` rather than `npm ci`: inside the Claude Code sandbox ci's wipe of node_modules
#     cannot finish — a transitive dependency ships a `.vscode/settings.json` the harness denies
#     unlinking — and with the lockfile intact, install resolves to the same tree, non-destructively.
if [ "${have_node}" = true ] && [ "${have_npm}" = true ]; then
    lock_hash="$(git hash-object package-lock.json)"
    if [ -n "${lock_hash}" ] && [ "$(cat node_modules/.session-start-stamp 2>/dev/null)" = "${lock_hash}" ]; then
        add "✓ dependencies: fresh (lockfile unchanged since the last install)"
    else
        echo "[session-start] installing dependencies (npm install)…" >&2
        t0=${SECONDS}
        if npm install >&2; then
            # Re-hash rather than reuse the probe above: `npm install` is free to rewrite
            # package-lock.json, and a stamp describing anything but what is installed reinstalls
            # every session.
            git hash-object package-lock.json >node_modules/.session-start-stamp
            add "✓ dependencies: installed (npm install, $((SECONDS - t0))s) — node_modules was missing or package-lock.json had moved."
        else
            add "✗ npm install failed after $((SECONDS - t0))s — dependencies are NOT installed; builds, tests and npm scripts will fail until \`npm install\` succeeds."
        fi
    fi
else
    add "✗ dependencies: skipped (node/npm missing) — nothing is installed; builds, tests and npm scripts will fail."
fi

# --- 3. Codegraph index — build once per checkout, then incremental sync.
#     `status` is the health probe rather than a test for the .codegraph/ directory, which only
#     ever proved a directory existed: a build killed partway (hook timeout) leaves one behind, and
#     every later session would then sync a database that was never usable. Its three answers are
#     distinct — exit 1 when the database cannot be read, initialized:false when there is no index,
#     and reindexRecommended when the index predates the installed codegraph's extraction version.
#     Anything unparseable is treated as unreadable, which is the safe reading of "no usable
#     answer". The branching is irreducible — verified: `index` refuses an uninitialized checkout,
#     and `init` is a no-op on an initialized one, so neither command covers all cases.
build_index() { # $1 = codegraph subcommand, $2 = what it is doing, as a phrase
    echo "[session-start] $2…" >&2
    t0=${SECONDS}
    if codegraph "$1" >&2; then
        add "✓ codegraph: finished $2 ($((SECONDS - t0))s)."
    else
        add "✗ codegraph $1 failed — this checkout has NO usable index. Use the normal file-reading tools instead of codegraph."
    fi
}

if [ "${have_node}" != true ]; then
    add "✗ codegraph: skipped (node missing) — no index was built or synced."
elif [ "${have_jq}" != true ]; then
    # Without jq the probe's JSON cannot be read; a blind incremental sync is the safe move — it
    # fails loudly when there is no usable index, instead of rebuilding every session on a hunch.
    t0=${SECONDS}
    if codegraph sync -q >&2; then
        add "✓ codegraph: index synced ($((SECONDS - t0))s; health probe skipped, jq missing)"
    else
        add "✗ codegraph sync failed (health probe skipped, jq missing) — the index is missing or stale; verify anything codegraph returns against the files."
    fi
else
    status_json="$(codegraph status --json)"
    initialized="$(printf '%s' "${status_json}" | jq -r '.initialized' 2>/dev/null)"
    reindex="$(printf '%s' "${status_json}" | jq -r '.index.reindexRecommended' 2>/dev/null)"

    if [ "${initialized}" = "true" ] && [ "${reindex}" != "true" ]; then
        # `sync -q` is silent even when it fails, so report it: a stale index is worse unannounced.
        t0=${SECONDS}
        if codegraph sync -q >&2; then
            add "✓ codegraph: index synced ($((SECONDS - t0))s)"
        else
            add "✗ codegraph sync failed — the index may be stale. Verify anything codegraph returns against the files before relying on it."
        fi
    elif [ "${initialized}" = "false" ]; then
        build_index init "building the Codegraph index (first run in this checkout)"
    elif [ "${initialized}" = "true" ]; then
        build_index index "rebuilding the Codegraph index (it was built by an older codegraph)"
    else
        build_index index "rebuilding the Codegraph index (the existing one is unreadable)"
    fi
fi
