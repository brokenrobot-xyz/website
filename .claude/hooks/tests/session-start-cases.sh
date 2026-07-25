#!/usr/bin/env bash
# Behavior cases for session-start.sh.
#
# The deny-hook suites feed one JSON payload per case and read the decision back. This hook is
# stateful and slow instead — it installs dependencies and builds a code index — so each case runs
# the real script against a throwaway checkout with stub `npm` and `codegraph` executables ahead of
# the real ones on PATH. The stubs record the arguments they were called with and fake success or
# failure on demand, which keeps the suite offline and instant while still covering every branch,
# including the failures that are impractical to provoke for real.

set -uo pipefail

hook_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="${hook_dir}/session-start.sh"

# The pin the sanity check compares .mcp.json and package.json against. Read from the source rather
# than hardcoded, so a version bump does not silently turn every healthy case into a drift report.
CG_PIN="$(grep -h -m1 '^CODEGRAPH_VERSION=' "${hook_dir}/lib/dev-env-checks.sh" "${HOOK}" 2>/dev/null | head -n1 | cut -d'"' -f2)"

root="$(mktemp -d)"
trap 'rm -rf "${root}"' EXIT

shim="${root}/shim"
proj="${root}/proj"
export MARKER="${root}/calls"
mkdir -p "${shim}" "${proj}"

# Stub npm: `--version` is answered first and silently — the sanity check probes it on every run,
# and a version probe is not behavior under test, so it neither records to MARKER nor touches the
# tree. `install` records the call, then either fails (NPM_INSTALL_EXIT) or lays down a
# node_modules tree. The tree is otherwise empty: codegraph no longer lives there, it is fetched by
# npx. Anything else recorded is a tripwire for npm usage the suite does not expect.
cat >"${shim}/npm" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  --version)
    echo "11.13.0"
    exit 0
    ;;
  install)
    echo "npm $*" >>"${MARKER}"
    [ "${NPM_INSTALL_EXIT:-0}" = "0" ] || exit "${NPM_INSTALL_EXIT}"
    mkdir -p node_modules
    ;;
  *)
    echo "npm $*" >>"${MARKER}"
    ;;
esac
STUB
chmod +x "${shim}/npm"

# Stub npx: the hook reaches codegraph as `npx -y <pkg>@<version> <subcommand>`, so this drops those
# two leading arguments and then stands in for codegraph itself — recording under the bare name the
# assertions below expect. It reproduces the real `status --json` contract, which is what the hook
# probes for index health: exit 1 when the database cannot be read (CG_BROKEN), initialized:false
# when no .codegraph exists, and reindexRecommended when the index predates the installed codegraph
# (CG_REINDEX). CG_EXIT fails the build and sync subcommands, not the probe.
#
# Being on PATH rather than inside node_modules is the point: it is reachable whether or not this
# checkout has been installed, exactly as the real npx is.
cat >"${shim}/npx" <<'STUB'
#!/usr/bin/env bash
[ "${1:-}" = "-y" ] && shift
shift # the pinned package spec
echo "codegraph $*" >>"${MARKER}"
case "$1" in
  status)
    [ "${CG_BROKEN:-0}" = "0" ] || { echo "Failed to get status: file is not a database" >&2; exit 1; }
    if [ -d .codegraph ]; then
      printf '{"initialized":true,"index":{"reindexRecommended":%s}}\n' "${CG_REINDEX:-false}"
    else
      echo '{"initialized":false}'
    fi
    exit 0
    ;;
  init | index)
    [ "${CG_EXIT:-0}" = "0" ] && mkdir -p .codegraph
    exit "${CG_EXIT:-0}"
    ;;
esac
exit "${CG_EXIT:-0}"
STUB
chmod +x "${shim}/npx"

# Stub typescript-language-server: the sanity check only asks whether it is on PATH; whether the
# host happens to have a real one must not decide a case.
printf '#!/usr/bin/env bash\nexit 0\n' >"${shim}/typescript-language-server"
chmod +x "${shim}/typescript-language-server"

export PATH="${shim}:${PATH}"
export CLAUDE_PROJECT_DIR="${proj}"

# A checkout the sanity check calls healthy: the host's node version pinned, and both committed
# codegraph pins matching the hook's own. The problem cases below break these one at a time.
node_ver="$(node --version)"
node_ver="${node_ver#v}"
printf '%s\n' "${node_ver}" >"${proj}/.node-version"
mcp_json() { printf '{"mcpServers":{"codegraph":{"command":"npx","args":["-y","@colbymchenry/codegraph@%s"]}}}\n' "$1" >"${proj}/.mcp.json"; }
mcp_json "${CG_PIN}"
printf '{"scripts":{"codegraph:init":"npx -y @colbymchenry/codegraph@%s init","codegraph:status":"npx -y @colbymchenry/codegraph@%s status"}}\n' \
    "${CG_PIN}" "${CG_PIN}" >"${proj}/package.json"

pass=0
fail=0

check() {
    local label="$1" expect="$2" actual="$3"
    if [ "${expect}" = "${actual}" ]; then
        pass=$((pass + 1))
        printf 'ok   %s\n' "${label}"
    else
        fail=$((fail + 1))
        printf 'FAIL %s\n     expected: %s\n     actual:   %s\n' "${label}" "${expect}" "${actual}"
    fi
}

contains() {
    local label="$1" needle="$2" haystack="$3"
    if printf '%s' "${haystack}" | grep -qF "${needle}"; then
        pass=$((pass + 1))
        printf 'ok   %s\n' "${label}"
    else
        fail=$((fail + 1))
        printf 'FAIL %s\n     want substring: %s\n     in: %s\n' "${label}" "${needle}" "${haystack}"
    fi
}

lacks() {
    local label="$1" needle="$2" haystack="$3"
    if printf '%s' "${haystack}" | grep -qF "${needle}"; then
        fail=$((fail + 1))
        printf 'FAIL %s\n     unwanted substring: %s\n     in: %s\n' "${label}" "${needle}" "${haystack}"
    else
        pass=$((pass + 1))
        printf 'ok   %s\n' "${label}"
    fi
}

# stdout is what Claude Code consumes; stderr is the human/--debug copy and is not asserted on.
run() {
    : >"${MARKER}"
    bash "${HOOK}" 2>/dev/null
}
calls() { cat "${MARKER}"; }
stamp() { cat "${proj}/node_modules/.session-start-stamp" 2>/dev/null; }
lockfile() { printf '{"v":%s}\n' "$1" >"${proj}/package-lock.json"; }
is_json() { printf '%s' "$1" | jq -e . >/dev/null 2>&1 && echo yes || echo no; }

# --- dependencies: install when missing, skip when current, reinstall when the lockfile moves ---

lockfile 1
out="$(run)"
check "cold checkout installs and builds the index" "npm install
codegraph status --json
codegraph init" "$(calls)"
check "a successful install stamps the lockfile hash" "$(git hash-object "${proj}/package-lock.json")" "$(stamp)"

out="$(run)"
check "an unchanged lockfile skips the install" "codegraph status --json
codegraph sync -q" "$(calls)"

lockfile 2
out="$(run)"
check "a moved lockfile reinstalls, in place over the existing tree" "npm install
codegraph status --json
codegraph sync -q" "$(calls)"

# --- output contract: always a report, identical for user and Claude, all-clear when healthy ---

out="$(run)"
check "a healthy warm start reports as JSON" "yes" "$(is_json "${out}")"
contains "and its tools line is all-clear" "✓ tools:" "${out}"
lacks "with no problem lines" "✗" "${out}"

lockfile 3
out="$(run)"
check "work performed is reported as JSON" "yes" "$(is_json "${out}")"
check "tagged as a SessionStart hook" "SessionStart" "$(printf '%s' "${out}" | jq -r '.hookSpecificOutput.hookEventName')"
check "user and Claude get the same notes" "same" \
    "$(printf '%s' "${out}" | jq -r 'if .systemMessage == .hookSpecificOutput.additionalContext then "same" else "differ" end')"
contains "the reinstall is explained" "dependencies: installed (npm install" "${out}"

# --- failure paths ---
#
# `npm install` is the only installer, over an existing tree and a missing one alike: inside the
# Claude Code sandbox npm ci's wipe of node_modules cannot finish — a transitive dependency ships a
# `.vscode/settings.json` the harness will not let anything unlink — and with the lockfile intact,
# install resolves to the same tree. A failed install also leaves an existing tree usable, where a
# failed ci would leave it half-removed.

lockfile 4
out="$(NPM_INSTALL_EXIT=1 run)"
check "a failed install still emits valid JSON" "yes" "$(is_json "${out}")"
contains "a failed install is reported" "npm install failed" "${out}"
contains "a failed install reaches Claude" "npm install failed" "$(printf '%s' "${out}" | jq -r '.hookSpecificOutput.additionalContext')"
check "a failed install does not block the index — codegraph comes from npx, not node_modules" "npm install
codegraph status --json
codegraph sync -q" "$(calls)"
check "a failed install leaves the previous stamp in place" "$(git hash-object <(printf '{"v":3}\n'))" "$(stamp)"

out="$(run)"
check "the next session retries the install" "npm install
codegraph status --json
codegraph sync -q" "$(calls)"

# The cold branch: no tree at all reaches for the same installer.
rm -rf "${proj}/node_modules"
lockfile 5
out="$(NPM_INSTALL_EXIT=1 run)"
check "a checkout with no tree also reaches for npm install" "npm install
codegraph status --json
codegraph sync -q" "$(calls)"
contains "and its failure is reported too" "npm install failed" "${out}"

out="$(CG_EXIT=1 run)"
check "a failed sync still emits valid JSON" "yes" "$(is_json "${out}")"
contains "a failed sync warns that the index may be stale" "codegraph sync failed" "${out}"

# --- index health: the probe, not the directory, decides what to run ---

out="$(CG_BROKEN=1 run)"
check "an unreadable index is rebuilt, not synced" "codegraph status --json
codegraph index" "$(calls)"
contains "and the rebuild is explained" "the existing one is unreadable" "${out}"

out="$(CG_REINDEX=true run)"
check "an index built by an older codegraph is rebuilt" "codegraph status --json
codegraph index" "$(calls)"
contains "and that rebuild is explained too" "built by an older codegraph" "${out}"

out="$(CG_BROKEN=1 CG_EXIT=1 run)"
contains "a failed rebuild is reported" "codegraph index failed" "${out}"
contains "and says the checkout has no usable index" "NO usable index" "${out}"

rm -rf "${proj}/.codegraph" "${proj}/node_modules"
lockfile 5
out="$(CG_EXIT=1 run)"
contains "a failed init is reported, not swallowed" "codegraph init failed" "${out}"
contains "and is reported alongside the install that preceded it" "dependencies: installed" "${out}"

# --- the sanity check: each problem it can see lands in the report ---

printf '0.0.1\n' >"${proj}/.node-version"
out="$(run)"
contains "a node/.node-version mismatch is reported" "but .node-version pins 0.0.1" "${out}"
printf '%s\n' "${node_ver}" >"${proj}/.node-version"

mcp_json "9.9.9"
out="$(run)"
contains "a drifted codegraph pin is reported" "codegraph pins drifted" "${out}"
contains "and problems point at the setup doc" "(see docs/development-environment.md)" "${out}"
mcp_json "${CG_PIN}"

# --- environment guards ---

# A PATH holding only what the hook needs to report a failure — deliberately no node and no npm.
nonode="${root}/nonode"
mkdir -p "${nonode}"
for tool in bash git jq cat awk cut grep sort; do ln -s "$(command -v "${tool}")" "${nonode}/${tool}"; done
out="$(PATH="${nonode}" run)"
contains "a missing node is reported" "node missing" "${out}"
check "and nothing is attempted without it" "" "$(calls)"

out="$(CLAUDE_PROJECT_DIR="${root}/does-not-exist" run)"
contains "an unusable project dir is reported, not skipped in silence" "cannot enter" "${out}"

# A manual run has no CLAUDE_PROJECT_DIR, so the hook falls back to the working directory — the
# debug path documented in the script: run it by hand from the repo root.
mkdir -p "${proj}/.claude/hooks"
cp "${HOOK}" "${proj}/.claude/hooks/session-start.sh"
: >"${MARKER}"
out="$(cd "${proj}" && env -u CLAUDE_PROJECT_DIR bash .claude/hooks/session-start.sh 2>/dev/null)"
check "a manual run from the repo root bootstraps that checkout" "codegraph status --json
codegraph sync -q" "$(calls)"

printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
[ "${fail}" -eq 0 ]
