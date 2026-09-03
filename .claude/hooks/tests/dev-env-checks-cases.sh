#!/usr/bin/env bash
# Behavior cases for the executed mode of lib/dev-env-checks.sh — the read-only audit the
# checking-dev-env skill runs.
#
# The detection logic itself is already exercised through the session-start suite; what this suite
# pins down is the executed-mode contract: all-✓ exits 0, any ✗ exits 1, the skill-only checks
# (Claude Code integration, containers) report with the wording the doc's Troubleshooting entries
# key on, and — the load-bearing case — a full run records nothing mutating. Same harness shape as
# session-start-cases.sh: a throwaway checkout, stub executables on a fully controlled PATH, and a
# MARKER file recording what was called.

set -uo pipefail

hook_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="${hook_dir}/lib/dev-env-checks.sh"

CG_PIN="$(grep -m1 '^CODEGRAPH_VERSION=' "${LIB}" | cut -d'"' -f2)"

root="$(mktemp -d)"
trap 'rm -rf "${root}"' EXIT

shim="${root}/shim"
base="${root}/base"
proj="${root}/proj"
export MARKER="${root}/calls"
mkdir -p "${shim}" "${base}" "${proj}"

# The PATH is fully controlled — real tools the probes rely on are linked into base, everything
# else exists only as a stub in shim — so what the host happens to have installed (fnm, docker, a
# global language server) can never decide a case.
for tool in bash git jq cat awk cut grep sort node; do
    ln -s "$(command -v "${tool}")" "${base}/${tool}"
done

# Stub npm: `--version` answers silently; anything else recorded is a mutation tripwire — executed
# mode must never install.
cat >"${shim}/npm" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  --version) echo "11.13.0" ;;
  *) echo "npm $*" >>"${MARKER}" ;;
esac
STUB

# Stub npx: stands in for codegraph as in the session-start suite; only `status --json` should
# ever be reached from executed mode.
cat >"${shim}/npx" <<'STUB'
#!/usr/bin/env bash
[ "${1:-}" = "-y" ] && shift
shift # the pinned package spec
echo "codegraph $*" >>"${MARKER}"
case "$1" in
  status)
    if [ -d .codegraph ]; then
      printf '{"initialized":true,"index":{"reindexRecommended":%s}}\n' "${CG_REINDEX:-false}"
    else
      echo '{"initialized":false}'
    fi
    ;;
esac
exit 0
STUB

# Stub docker: `info` is the read-only daemon probe; DOCKER_INFO_EXIT fakes a stopped daemon.
cat >"${shim}/docker" <<'STUB'
#!/usr/bin/env bash
exit "${DOCKER_INFO_EXIT:-0}"
STUB

printf '#!/usr/bin/env bash\nexit 0\n' >"${shim}/typescript-language-server"
printf '#!/usr/bin/env bash\nexit 0\n' >"${shim}/fnm"

# Stub openspec: answers --version with the fixture pin below — an arbitrary value, since the
# probe compares it against the fixture package.json, not the repo's — and `config get profile`
# with OPENSPEC_PROFILE, defaulting to the core profile the committed integration expects.
OS_PIN="9.1.0"
openspec_stub() {
    cat >"${shim}/openspec" <<STUB
#!/usr/bin/env bash
case "\$1" in
  --version) echo "${OS_PIN}" ;;
  config) [ "\$2 \$3" = "get profile" ] && echo "\${OPENSPEC_PROFILE:-core}" ;;
esac
STUB
    chmod +x "${shim}/openspec"
}
openspec_stub
chmod +x "${shim}"/*

# A checkout every probe calls healthy; the cases below break one thing at a time and restore it.
node_ver="$(node --version)"
node_ver="${node_ver#v}"
printf '%s\n' "${node_ver}" >"${proj}/.node-version"
printf '{"mcpServers":{"codegraph":{"command":"npx","args":["-y","@colbymchenry/codegraph@%s"]}}}\n' "${CG_PIN}" >"${proj}/.mcp.json"
printf '{"scripts":{"codegraph:status":"npx -y @colbymchenry/codegraph@%s status"},"devDependencies":{"@fission-ai/openspec":"%s"}}\n' \
    "${CG_PIN}" "${OS_PIN}" >"${proj}/package.json"
printf '{"v":1}\n' >"${proj}/package-lock.json"
mkdir -p "${proj}/.codegraph" "${proj}/node_modules/.bin" "${proj}/.claude"
git hash-object "${proj}/package-lock.json" >"${proj}/node_modules/.session-start-stamp"
printf '#!/usr/bin/env bash\nexit 0\n' >"${proj}/node_modules/.bin/devcontainer"
chmod +x "${proj}/node_modules/.bin/devcontainer"
settings() {
    printf '{"enabledPlugins":{"typescript-lsp@claude-plugins-official":true},"enabledMcpjsonServers":["codegraph"]}\n' \
        >"${proj}/.claude/settings.json"
}
settings

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

# NVM_DIR points into the void so a real ~/.nvm on the host cannot satisfy the manager probe.
run() {
    : >"${MARKER}"
    PATH="${shim}:${base}" NVM_DIR="${root}/absent" CLAUDE_PROJECT_DIR="${proj}" bash "${LIB}" 2>/dev/null
}
calls() { cat "${MARKER}"; }

# --- the healthy contract: all ✓, exit 0, and a run that touched nothing ---

out="$(run)"
rc=$?
check "a healthy checkout exits 0" "0" "${rc}"
contains "and reports the toolchain" "✓ tools:" "${out}"
contains "crediting the openspec profile" "openspec ${OS_PIN} (profile core)" "${out}"
contains "and fresh dependencies" "✓ dependencies: fresh" "${out}"
contains "and a readable index" "✓ codegraph: index present and readable" "${out}"
contains "and the claude code integration" "✓ claude code: typescript-lsp plugin enabled, codegraph MCP enabled, node manager fnm" "${out}"
contains "and the containers" "✓ containers: docker daemon running, devcontainer CLI present" "${out}"
lacks "with no problem lines" "✗" "${out}"
check "a full audit records nothing mutating — only the status probe" "codegraph status --json" "$(calls)"

# --- any ✗ flips the exit code (the skill's tier-2 gate) ---

rm "${shim}/typescript-language-server"
out="$(run)"
rc=$?
check "a missing language server exits 1" "1" "${rc}"
contains "and is reported" "✗ typescript-language-server missing" "${out}"
printf '#!/usr/bin/env bash\nexit 0\n' >"${shim}/typescript-language-server"
chmod +x "${shim}/typescript-language-server"

# The controlled PATH makes this case host-independent — a globally installed openspec on the
# machine running the suite can never satisfy the probe.
rm "${shim}/openspec"
out="$(run)"
rc=$?
check "a missing openspec cli exits 1" "1" "${rc}"
contains "and is reported with the pinned install" "✗ openspec missing" "${out}"
contains "naming the fixture pin" "@fission-ai/openspec@${OS_PIN}" "${out}"
openspec_stub

# The profile is read from the machine-global config, so it can be wrong on a machine whose CLI
# matches the pin exactly.
out="$(OPENSPEC_PROFILE=custom run)"
rc=$?
check "a non-core openspec profile exits 1" "1" "${rc}"
contains "and is reported" "✗ openspec profile is custom" "${out}"
contains "naming the fix" "openspec config profile core" "${out}"
contains "while the matching CLI is still credited" "openspec ${OS_PIN}" "${out}"
lacks "but not as core" "(profile core)" "${out}"

printf '{"v":2}\n' >"${proj}/package-lock.json"
out="$(run)"
contains "a moved lockfile reports stale dependencies" "✗ dependencies: node_modules missing or stale" "${out}"
git hash-object "${proj}/package-lock.json" >"${proj}/node_modules/.session-start-stamp"

rm -rf "${proj}/.codegraph"
out="$(run)"
contains "a missing index is reported" "✗ codegraph: no index in this checkout" "${out}"
check "and nothing tries to build it — the guide does, the audit does not" "codegraph status --json" "$(calls)"
mkdir -p "${proj}/.codegraph"

out="$(CG_REINDEX=true run)"
contains "an outdated index is reported" "✗ codegraph: index built by an older codegraph" "${out}"

# --- claude code integration: config, not PATH, is what these probes read ---

printf '{}\n' >"${proj}/.claude/settings.json"
out="$(run)"
contains "a disabled typescript-lsp plugin is reported" "✗ typescript-lsp plugin not enabled" "${out}"
settings

printf '{"enabledPlugins":{"typescript-lsp@claude-plugins-official":true}}\n' >"${proj}/.claude/settings.json"
out="$(run)"
contains "settings.json with no enabled list means the MCP is not enabled" "✗ codegraph MCP not enabled" "${out}"
printf '{"enabledPlugins":{"typescript-lsp@claude-plugins-official":true},"enabledMcpjsonServers":["playwright"]}\n' \
    >"${proj}/.claude/settings.json"
out="$(run)"
contains "an enabled list without codegraph is the same problem" "✗ codegraph MCP not enabled" "${out}"
settings

rm "${shim}/fnm"
out="$(run)"
contains "no manager on PATH and no nvm dir is reported" "✗ no node version manager detected" "${out}"
printf '#!/usr/bin/env bash\nexit 0\n' >"${shim}/fnm"
chmod +x "${shim}/fnm"

# --- containers: consequences scoped to the e2e suite, never to host development ---

out="$(DOCKER_INFO_EXIT=1 run)"
contains "a stopped daemon is reported" "✗ docker daemon not running" "${out}"
contains "while the CLI is still credited" "✓ containers: devcontainer CLI present" "${out}"

rm "${shim}/docker"
out="$(run)"
contains "a missing docker is reported" "✗ docker missing" "${out}"
contains "and scoped away from host development" "host development is unaffected" "${out}"
printf '#!/usr/bin/env bash\nexit "${DOCKER_INFO_EXIT:-0}"\n' >"${shim}/docker"
chmod +x "${shim}/docker"

rm "${proj}/node_modules/.bin/devcontainer"
out="$(run)"
contains "a missing devcontainer CLI is reported" "✗ devcontainer CLI missing" "${out}"
printf '#!/usr/bin/env bash\nexit 0\n' >"${proj}/node_modules/.bin/devcontainer"
chmod +x "${proj}/node_modules/.bin/devcontainer"

printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
[ "${fail}" -eq 0 ]
