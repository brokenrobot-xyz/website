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

# The probes — tool sanity, dependency freshness, index health — live in a lib next to this script,
# shared with the check-dev-env skill: same detection, two consumers, where this hook acts on the
# findings and the skill only guides. A missing sibling means a broken checkout; re-implementing
# the checks inline as a fallback would be exactly the drift the extraction removes.
# Pure-bash dirname: this must resolve even on a PATH too broken to hold coreutils, because the
# report about that broken PATH is exactly what the lib produces.
hook_dir="${BASH_SOURCE[0]%/*}"
[ "${hook_dir}" = "${BASH_SOURCE[0]}" ] && hook_dir="."
hook_lib="${hook_dir}/lib/dev-env-checks.sh"
if [ -f "${hook_lib}" ]; then
    . "${hook_lib}"
else
    add "✗ ${hook_lib} is missing — this checkout is incomplete; nothing was bootstrapped for this session."
    exit 0
fi

# CLAUDE_PROJECT_DIR is set by the harness; $PWD keeps a manual debug run from the repo root working.
project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "${project_dir}" || {
    add "✗ cannot enter ${project_dir} — nothing was bootstrapped for this session."
    exit 0
}

# --- 1. Tool sanity check — report-only; fixing is the dev-env setup's job, not this hook's. -----
#     The probes and their wording live in the lib; this hook only routes the ✓/✗ lines into the
#     session report. Missing tools also gate the later steps, so the report never implies work
#     that never ran.
dev_env_check_tools
while IFS= read -r line; do add "${line}"; done < <(dev_env_tool_report "(see docs/development-environment.md)")

# --- 2. Dependencies — install only when missing or stale (npm install is slow; never every
#     session). The stamp holds the lockfile's git hash, so a pull or branch switch that moves
#     package-lock.json reinstalls. It is written only on success and lives inside node_modules/,
#     so an install that dies partway (hook timeout) can never leave a tree that looks complete.
#     No hash (missing lockfile) means "not up to date": npm install then reports the real problem.
#     `npm install` rather than `npm ci`: inside the Claude Code sandbox ci's wipe of node_modules
#     cannot finish — a transitive dependency ships a `.vscode/settings.json` the harness denies
#     unlinking — and with the lockfile intact, install resolves to the same tree, non-destructively.
if [ "${have_node}" = true ] && [ "${have_npm}" = true ]; then
    if dev_env_deps_fresh; then
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
#     The lib's `dev_env_codegraph_state` probe (see its comment for the status contract) decides
#     which command runs. The branching is irreducible — verified: `index` refuses an uninitialized
#     checkout, and `init` is a no-op on an initialized one, so neither command covers all cases.
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
    case "$(dev_env_codegraph_state)" in
        healthy)
            # `sync -q` is silent even when it fails, so report it: a stale index is worse unannounced.
            t0=${SECONDS}
            if codegraph sync -q >&2; then
                add "✓ codegraph: index synced ($((SECONDS - t0))s)"
            else
                add "✗ codegraph sync failed — the index may be stale. Verify anything codegraph returns against the files before relying on it."
            fi
            ;;
        uninitialized)
            build_index init "building the Codegraph index (first run in this checkout)"
            ;;
        reindex)
            build_index index "rebuilding the Codegraph index (it was built by an older codegraph)"
            ;;
        *)
            build_index index "rebuilding the Codegraph index (the existing one is unreadable)"
            ;;
    esac
fi
