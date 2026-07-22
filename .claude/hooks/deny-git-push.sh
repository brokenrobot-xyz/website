#!/usr/bin/env bash

set -euo pipefail

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"

delims="$(printf '%s\n' "$cmd" | sed -nE "s/.*<<-?[[:space:]]*['\"]?([A-Za-z_][A-Za-z0-9_]*)['\"]?.*/\1/p")"
delim="${delims%%$'\n'*}"

scan="$cmd"
if [[ -n "$delim" ]]; then
  scan="$(printf '%s\n' "$cmd" | awk -v d="$delim" '
    !started && index($0, "<<") && $0 ~ ("(^|[^A-Za-z0-9_])" d "([^A-Za-z0-9_]|$)") { started = 1; print; next }
    started && $0 ~ ("^[[:space:]]*" d "[[:space:]]*$") { started = 0; print; next }
    started { next }
    { print }
  ')"
fi

printf '%s' "$scan" | grep -Eq 'git[[:space:]]+([^[:space:]]+[[:space:]]+)*push([[:space:]]|$)' || exit 0
printf '%s' "$scan" | grep -Eq -- '--dry-run' && exit 0

deny "git push is a human-only gate in this project — pushing to a remote must be run manually by the user, not by Claude. Ask the user to run the push themselves."
