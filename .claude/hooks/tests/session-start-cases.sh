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

root="$(mktemp -d)"
trap 'rm -rf "${root}"' EXIT

shim="${root}/shim"
proj="${root}/proj"
export MARKER="${root}/calls"
mkdir -p "${shim}" "${proj}"

# Stub npm: records the call, then either fails (NPM_CI_EXIT) or lays down a node_modules tree
# holding a stub codegraph — which records its own calls and honours CG_EXIT. Writing node_modules
# only on success mirrors the real npm ci, which wipes the tree before repopulating it.
cat >"${shim}/npm" <<'STUB'
#!/usr/bin/env bash
echo "npm $*" >>"${MARKER}"
[ "${NPM_CI_EXIT:-0}" = "0" ] || exit "${NPM_CI_EXIT}"
rm -rf node_modules
mkdir -p node_modules/.bin
cat >node_modules/.bin/codegraph <<'CODEGRAPH'
#!/usr/bin/env bash
echo "codegraph $*" >>"${MARKER}"
[ "$1" = "init" ] && [ "${CG_EXIT:-0}" = "0" ] && mkdir -p .codegraph
exit "${CG_EXIT:-0}"
CODEGRAPH
chmod +x node_modules/.bin/codegraph
STUB
chmod +x "${shim}/npm"

export PATH="${shim}:${PATH}"
export CLAUDE_PROJECT_DIR="${proj}"

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
check "cold checkout installs and builds the index" "npm ci
codegraph init" "$(calls)"
check "a successful install stamps the lockfile hash" "$(git hash-object "${proj}/package-lock.json")" "$(stamp)"

out="$(run)"
check "an unchanged lockfile skips npm ci" "codegraph sync -q" "$(calls)"

lockfile 2
out="$(run)"
check "a moved lockfile reinstalls" "npm ci
codegraph sync -q" "$(calls)"

# --- output contract: silent when healthy, structured when not ---

check "a healthy warm start writes nothing to stdout" "" "$(run)"

lockfile 3
out="$(run)"
check "work performed is reported as JSON" "yes" "$(is_json "${out}")"
check "tagged as a SessionStart hook" "SessionStart" "$(printf '%s' "${out}" | jq -r '.hookSpecificOutput.hookEventName')"
check "user and Claude get the same notes" "same" \
    "$(printf '%s' "${out}" | jq -r 'if .systemMessage == .hookSpecificOutput.additionalContext then "same" else "differ" end')"
contains "the reinstall is explained" "installed dependencies (npm ci)" "${out}"

# --- failure paths ---

lockfile 4
out="$(NPM_CI_EXIT=1 run)"
check "a failed npm ci still emits valid JSON" "yes" "$(is_json "${out}")"
contains "a failed npm ci is reported" "npm ci failed" "${out}"
contains "a failed npm ci reaches Claude" "npm ci failed" "$(printf '%s' "${out}" | jq -r '.hookSpecificOutput.additionalContext')"
check "a failed npm ci stops before codegraph" "npm ci" "$(calls)"
check "a failed npm ci leaves the stamp untouched" "$(git hash-object <(printf '{"v":3}\n'))" "$(stamp)"

out="$(run)"
check "the next session retries the install" "npm ci
codegraph sync -q" "$(calls)"

out="$(CG_EXIT=1 run)"
check "a failed sync still emits valid JSON" "yes" "$(is_json "${out}")"
contains "a failed sync warns that the index may be stale" "codegraph sync failed" "${out}"

rm -rf "${proj}/.codegraph" "${proj}/node_modules"
lockfile 5
out="$(CG_EXIT=1 run)"
contains "a failed init is reported, not swallowed" "codegraph init failed" "${out}"
contains "and is reported alongside the install that preceded it" "installed dependencies" "${out}"

printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
[ "${fail}" -eq 0 ]
