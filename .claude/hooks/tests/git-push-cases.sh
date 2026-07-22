#!/usr/bin/env bash

set -uo pipefail

hook_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$hook_dir/deny-git-push.sh"

pass=0
fail=0

run() {
  local expect="$1" label="$2" cmd="$3" out decision
  out="$(jq -n --arg cmd "$cmd" '{tool_input:{command:$cmd}}' | bash "$HOOK" 2>/dev/null)"
  if printf '%s' "$out" | grep -q '"permissionDecision": *"deny"'; then decision=deny; else decision=allow; fi
  if [[ "$decision" == "$expect" ]]; then
    pass=$((pass + 1)); printf 'ok   [%-5s] %s\n' "$expect" "$label"
  else
    fail=$((fail + 1)); printf 'FAIL exp=%-5s got=%-5s :: %s\n     cmd: %s\n' "$expect" "$decision" "$label" "$cmd"
  fi
}

hd_mentions_push="$(cat <<'OUTER'
git commit -m "$(cat <<'EOF'
chore(hooks): deny git push as a human-only gate

This hard-blocks git push via a PreToolUse hook.
EOF
)"
OUTER
)"

run deny  "bare push"                       "git push"
run deny  "push with remote and branch"     "git push origin main"
run deny  "force push variant"              "git push --force-with-lease"
run deny  "push in compound command"        "echo done && git push"
run deny  "git -C … push"                   "git -C /some/path push"

run allow "push --dry-run"                  "git push --dry-run"
run allow "not a push — git status"         "git status"
run allow "not a push — git log"            "git log --oneline"
run allow "commit heredoc mentioning push"  "$hd_mentions_push"

run deny  "echo mentions push (conservative match, denied on purpose)" "echo \"git push origin main\""

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
