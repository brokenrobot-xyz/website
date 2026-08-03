#!/usr/bin/env bash

set -uo pipefail

hook_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$hook_dir/../.." && pwd)"
# The hook lives inside the committing-conventionally skill's bundle (scripts/, per the Agent
# Skills spec), beside the recipe it enforces.
HOOK="$REPO/.claude/skills/committing-conventionally/scripts/deny-noncompliant-commit-message.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

printf 'docs: add a setup guide\n\nA short why-body explaining the motivation.\n' > "$tmp/good.txt"
printf 'docs: add a setup guide\n\nBody line.\n\nCo-Authored-By: Someone <x@y.z>\n' > "$tmp/trailer.txt"

# Three synthetic project roots exercise the config resolution: no config at all (the built-in
# Conventional Commits defaults), a config that only flips attributionTrailers, and a config the
# hook cannot parse. $REPO exercises the real .brokenrobot/commits.json.
mkdir -p "$tmp/defaults" "$tmp/allowed/.brokenrobot" "$tmp/broken/.brokenrobot"
printf '{"attributionTrailers": "allowed"}\n' > "$tmp/allowed/.brokenrobot/commits.json"
printf 'not json\n' > "$tmp/broken/.brokenrobot/commits.json"

pass=0
fail=0
PROJ="$REPO"

run() {
  local expect="$1" label="$2" cmd="$3" out decision
  out="$(jq -n --arg cmd "$cmd" '{tool_input:{command:$cmd}}' | CLAUDE_PROJECT_DIR="$PROJ" bash "$HOOK" 2>/dev/null)"
  if printf '%s' "$out" | grep -q '"permissionDecision": *"deny"'; then decision=deny; else decision=allow; fi
  if [[ "$decision" == "$expect" ]]; then
    pass=$((pass + 1)); printf 'ok   [%-5s] %s\n' "$expect" "$label"
  else
    fail=$((fail + 1)); printf 'FAIL exp=%-5s got=%-5s :: %s\n     cmd: %s\n' "$expect" "$decision" "$label" "$cmd"
  fi
}

hd_good="$(cat <<'OUTER'
git commit -m "$(cat <<'EOF'
feat(blog): add a reading-time badge

A proper why-body explaining the motivation.
EOF
)"
OUTER
)"
hd_good_unquoted="$(cat <<'OUTER'
git commit -m "$(cat <<EOF
fix(rss): parse the heredoc commit form
EOF
)"
OUTER
)"
hd_bad_type="$(cat <<'OUTER'
git commit -m "$(cat <<'EOF'
wip: not a real type

Co-Authored-By: Bot <bot@x.y>
EOF
)"
OUTER
)"
hd_trailer="$(cat <<'OUTER'
git commit -m "$(cat <<'EOF'
docs: add a setup guide

A proper why-body.

Co-Authored-By: Bot <bot@x.y>
EOF
)"
OUTER
)"
hd_unknown_scope="$(cat <<'OUTER'
git commit -m "$(cat <<'EOF'
fix(banana): peel
EOF
)"
OUTER
)"
hd_trailing_period="$(cat <<'OUTER'
git commit -m "$(cat <<'EOF'
fix: something.
EOF
)"
OUTER
)"
hd_dash_bad="$(cat <<'OUTER'
git commit -m "$(cat <<-'EOF'
wip: dash heredoc variant
EOF
)"
OUTER
)"

# --- This repo's .brokenrobot/commits.json: custom `post` type, fixed scope allowlist ------------
PROJ="$REPO"

run allow "commit -F good file"                 "git commit -F $tmp/good.txt"
run allow "git -C … commit -a -F good file"      "git -C /repo/path commit -a -F $tmp/good.txt"
run allow "combined -aF good file"               "git commit -aF $tmp/good.txt"
run allow "-m valid, no scope"                   'git commit -m "docs: fix a typo"'
run allow "-m valid, post type"                  'git commit -m "post: publish the ai-culture article"'
run allow "-m valid, style type + scope"         'git commit -m "style(layout): normalize spacing"'
run allow "-m valid, breaking marker"            'git commit -m "feat(layout)!: change the theme data attribute"'
run allow "two -m (subject + body)"              'git commit -m "chore(deps): tidy scripts" -m "why prose"'
run allow "merge commit skipped"                 'git commit -m "Merge branch '\''x'\''"'
run allow "bare editor commit (fail open)"       'git commit'
run allow "not a commit — git log"               'git log --oneline'
run allow "not a commit — echo mentions commit"  'echo "git commit -m stuff"'
run allow "heredoc valid subject + body"         "$hd_good"
run allow "heredoc valid, unquoted delimiter"    "$hd_good_unquoted"

run deny  "trailer via -F file"                  "git commit -F $tmp/trailer.txt"
run deny  "heredoc bad type + trailer"           "$hd_bad_type"
run deny  "heredoc valid subject + trailer"      "$hd_trailer"
run deny  "heredoc unknown scope"                "$hd_unknown_scope"
run deny  "heredoc trailing period"              "$hd_trailing_period"
run deny  "heredoc <<- dash variant, bad type"   "$hd_dash_bad"
run deny  "trailer via -m"                        'git commit -m "docs: x" -m "Co-Authored-By: A <a@b.c>"'
run deny  "bad type (wip)"                        'git commit -m "wip: something"'
run deny  "missing type"                          'git commit -m "just a message"'
run deny  "unknown scope"                         'git commit -m "fix(banana): x"'
run deny  "trailing period"                       'git commit -m "fix: something."'
run deny  "-am bad type"                          'git commit -am "nope: change"'

# --- No config: the built-in defaults — vanilla types, no scope allowlist, trailers forbidden ----
PROJ="$tmp/defaults"

run allow "defaults: vanilla type"               'git commit -m "fix: something"'
run allow "defaults: any lowercase scope"        'git commit -m "fix(banana): peel"'
run deny  "defaults: post is not a vanilla type" 'git commit -m "post: publish an article"'
run deny  "defaults: bad type (wip)"             'git commit -m "wip: something"'
run deny  "defaults: trailer still forbidden"    'git commit -m "docs: x" -m "Co-Authored-By: A <a@b.c>"'
run deny  "defaults: trailing period"            'git commit -m "fix: something."'

# --- attributionTrailers: "allowed" — only the trailer rule relaxes -------------------------------
PROJ="$tmp/allowed"

run allow "allowed: trailer passes"              'git commit -m "docs: x" -m "Co-Authored-By: A <a@b.c>"'
run deny  "allowed: bad type still denied"       'git commit -m "wip: something"'

# --- Unparseable config: deny commits with a clear reason, leave non-commits alone ----------------
PROJ="$tmp/broken"

run deny  "broken config: commit denied"         'git commit -m "fix: something"'
run allow "broken config: non-commit untouched"  'git log --oneline'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
