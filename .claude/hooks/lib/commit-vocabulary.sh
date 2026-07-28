#!/usr/bin/env bash
# Drift check for the commit vocabulary — the allowed commit types and scopes.
#
# docs/development/conventions/commit-conventions.md is the source of truth: the committing skill
# points at it, and people read it. deny-noncompliant-commit-message.sh has to carry an executable
# copy, because a hook cannot read prose. Those two copies are the only ones that earn their keep,
# and this file compares them — so a scope added to the document but not to the hook (or the
# reverse) surfaces as a report line, instead of as a commit rejected for a scope the document
# calls valid.
#
# Two consumers, one comparison, so the two checks cannot disagree:
#   - lib/dev-env-checks.sh sources this file and reports ✓/✗ in the session-start report;
#   - tests/commit-message-cases.sh sources it and fails the suite on drift.
#
# Drift contract: the ✗ wording lives here; its remediation lives in
# docs/development-environment.md § Troubleshooting, keyed on the ✗ line's prefix.
#
# Written to be sourced under `set -uo pipefail`: it defines functions, nothing else, and never
# exits the caller. Paths are relative to the project root, like the rest of the hook libs.

COMMIT_VOCAB_DOC="docs/development/conventions/commit-conventions.md"
COMMIT_VOCAB_HOOK=".claude/hooks/deny-noncompliant-commit-message.sh"

# § Types' table, first column: rows like "| `feat` | A new user-facing feature. |". The header and
# separator rows carry no backticks, so they drop out on their own.
commit_vocab_doc_types() {
    awk '/^## Types/{t = 1; next} t && /^## /{exit} t' "$1" |
        sed -nE 's/^\|[[:space:]]*`([a-z]+)`.*/\1/p' | sort -u
}

# § Scope's prose, stopping at its first example block: the backticked names in "It must be one of
# a fixed set of recognizable areas of the codebase: `blog`, `rss`, …".
commit_vocab_doc_scopes() {
    awk '/^## Scope/{s = 1; next} s && (/^## / || /^```/){exit} s' "$1" |
        grep -oE '`[a-z0-9-]+`' | tr -d '`' | sort -u
}

# One of the hook's `allowed_types=` / `allowed_scopes=` assignments, as a sorted list.
commit_vocab_hook_list() { # $1 = hook path, $2 = variable name
    sed -nE "s/^$2=\"([^\"]*)\".*/\1/p" "$1" | tr ' ' '\n' | grep -v '^$' | sort -u
}

# Describes one list's disagreement, or prints nothing when the two sides match.
_commit_vocab_compare() { # $1 = label, $2 = doc list, $3 = hook list
    local label="$1" doc="$2" hook="$3" only_doc only_hook
    [ "$doc" = "$hook" ] && return 0
    only_doc="$(comm -23 <(printf '%s\n' "$doc") <(printf '%s\n' "$hook") | tr '\n' ' ')"
    only_hook="$(comm -13 <(printf '%s\n' "$doc") <(printf '%s\n' "$hook") | tr '\n' ' ')"
    printf '%s differ (%s%s%s)' "$label" \
        "${only_doc:+document only: ${only_doc% }}" \
        "${only_doc:+${only_hook:+; }}" \
        "${only_hook:+hook only: ${only_hook% }}"
}

# Prints a drift description, or nothing when the document and the hook agree. A list that cannot
# be parsed is reported as drift rather than passed over, because an empty parse and an aligned
# pair are indistinguishable to the caller otherwise.
commit_vocabulary_drift() { # $1 = doc path (optional), $2 = hook path (optional)
    local doc="${1:-$COMMIT_VOCAB_DOC}" hook="${2:-$COMMIT_VOCAB_HOOK}"
    local doc_types doc_scopes hook_types hook_scopes drift="" part

    if [ ! -f "$doc" ] || [ ! -f "$hook" ]; then
        printf 'cannot compare — %s is missing' "$([ -f "$doc" ] || printf '%s' "$doc"; [ -f "$hook" ] || printf '%s' "$hook")"
        return 0
    fi

    doc_types="$(commit_vocab_doc_types "$doc")"
    doc_scopes="$(commit_vocab_doc_scopes "$doc")"
    hook_types="$(commit_vocab_hook_list "$hook" allowed_types)"
    hook_scopes="$(commit_vocab_hook_list "$hook" allowed_scopes)"

    if [ -z "$doc_types" ] || [ -z "$doc_scopes" ] || [ -z "$hook_types" ] || [ -z "$hook_scopes" ]; then
        printf 'cannot compare — a list parsed empty; the § Types table, the § Scope paragraph, or the hook assignments changed shape'
        return 0
    fi

    for part in "$(_commit_vocab_compare types "$doc_types" "$hook_types")" \
        "$(_commit_vocab_compare scopes "$doc_scopes" "$hook_scopes")"; do
        [ -n "$part" ] && drift="${drift}${drift:+; }${part}"
    done

    printf '%s' "$drift"
}
