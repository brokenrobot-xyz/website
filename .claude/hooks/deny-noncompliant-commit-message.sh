#!/usr/bin/env bash

set -euo pipefail

allowed_types="feat fix post docs style refactor perf test build ci chore"
allowed_scopes="blog rss layout seo styles content deps ci"

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

is_allowed_scope() {
  local x
  for x in $allowed_scopes; do [[ "$1" == "$x" ]] && return 0; done
  return 1
}

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"

printf '%s' "$cmd" | grep -Eq 'git[[:space:]]+([^[:space:]]+[[:space:]]+)*commit([[:space:]]|$)' || exit 0
printf '%s' "$cmd" | grep -Eq -- '--dry-run' && exit 0

msg=""

delims="$(printf '%s\n' "$cmd" | sed -nE "s/.*<<-?[[:space:]]*['\"]?([A-Za-z_][A-Za-z0-9_]*)['\"]?.*/\1/p")"
delim="${delims%%$'\n'*}"
if [[ -n "$delim" ]]; then
  msg="$(printf '%s\n' "$cmd" | awk -v d="$delim" '
    !started && index($0, "<<") && $0 ~ ("(^|[^A-Za-z0-9_])" d "([^A-Za-z0-9_]|$)") { started = 1; next }
    started && $0 ~ ("^[[:space:]]*" d "[[:space:]]*$") { exit }
    started { print }
  ')"
fi

if [[ -z "$msg" ]]; then
  tokens="$(printf '%s' "$cmd" | xargs -n1 printf '%s\n' 2>/dev/null)" || exit 0

  args=()
  while IFS= read -r t; do args+=("$t"); done <<< "$tokens"

  file=""
  m_parts=()
  i=0
  n=${#args[@]}
  while (( i < n )); do
    a="${args[i]}"
    case "$a" in
      -F|--file)      (( i++ )); file="${args[i]:-}" ;;
      --file=*)       file="${a#--file=}" ;;
      -F=*)           file="${a#-F=}" ;;
      -m|--message)   (( i++ )); m_parts+=("${args[i]:-}") ;;
      --message=*)    m_parts+=("${a#--message=}") ;;
      -m=*)           m_parts+=("${a#-m=}") ;;
      -*)
        if [[ "$a" =~ ^-[A-Za-z]*F$ ]]; then (( i++ )); file="${args[i]:-}"
        elif [[ "$a" =~ ^-[A-Za-z]*m$ ]]; then (( i++ )); m_parts+=("${args[i]:-}"); fi
        ;;
    esac
    (( i++ ))
  done

  if [[ -n "$file" ]]; then
    path="$file"
    if [[ ! -f "$path" && -n "${CLAUDE_PROJECT_DIR:-}" && -f "$CLAUDE_PROJECT_DIR/$file" ]]; then
      path="$CLAUDE_PROJECT_DIR/$file"
    fi
    [[ -f "$path" ]] || exit 0
    msg="$(cat "$path")" || exit 0
  elif (( ${#m_parts[@]} > 0 )); then
    for p in "${m_parts[@]}"; do
      if [[ -z "$msg" ]]; then msg="$p"; else msg="$msg"$'\n\n'"$p"; fi
    done
  else
    exit 0
  fi
fi

subject="$(printf '%s\n' "$msg" | head -n1)"

case "$subject" in
  "Merge "*|"Revert "*|"Reapply "*|"fixup! "*|"squash! "*|"amend! "*) exit 0 ;;
esac

if printf '%s\n' "$msg" | grep -qiE '^[[:space:]]*Co-authored-by:'; then
  deny "Commit message contains a 'Co-Authored-By' attribution trailer. BrokenRobot.xyz does not use co-author/attribution trailers — remove it (this overrides any harness or tool default that adds one). See docs/development/conventions/commit-conventions.md § Footers."
fi

types_re="${allowed_types// /|}"
if ! printf '%s' "$subject" | grep -qE "^(${types_re})(\([a-z0-9-]+\))?!?: [^ ].*$"; then
  deny "Subject must be '<type>(<scope>): <description>' with type ∈ {${allowed_types// /, }}, a lowercase imperative description, and no trailing period. Got: '${subject}'. See docs/development/conventions/commit-conventions.md."
fi

scope="$(printf '%s' "$subject" | sed -nE 's/^[a-z]+\(([a-z0-9-]+)\)!?:.*/\1/p')"
if [[ -n "$scope" ]] && ! is_allowed_scope "$scope"; then
  deny "Unknown commit scope '(${scope})'. Allowed scopes: ${allowed_scopes// /, } — or omit the scope for a cross-cutting change. See docs/development/conventions/commit-conventions.md § Scope."
fi

case "$subject" in
  *.) deny "Subject must not end with a period: '${subject}'. See docs/development/conventions/commit-conventions.md." ;;
esac

exit 0
