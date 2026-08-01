# Before and after, one pair per convention

Worked rewrites for each of the twelve conventions in
[`conventions.md`](conventions.md). Each entry states the violation, then shows the smallest rewrite
that removes the violation. Match the shape of the rewrite, not its wording.

## Contents

- [1. Name the actor](#1-name-the-actor)
- [2. One instruction per sentence](#2-one-instruction-per-sentence)
- [3. Condition before command](#3-condition-before-command)
- [4. Notes informative, instructions imperative](#4-notes-informative-instructions-imperative)
- [5. Guardrail consequence](#5-guardrail-consequence)
- [6. Explicit referents](#6-explicit-referents)
- [7. Name the whole set](#7-name-the-whole-set)
- [8. Precise verbs](#8-precise-verbs)
- [9. One term per concept](#9-one-term-per-concept)
- [10. Noun stacks](#10-noun-stacks)
- [11. Verbs over nominalizations](#11-verbs-over-nominalizations)
- [12. Mechanics](#12-mechanics)
- [Rewrites this skill does not make](#rewrites-this-skill-does-not-make)

## 1. Name the actor

**Before:** The commit is rejected when the message carries no scope.

**Violation:** The sentence hides the actor. The agent cannot tell whether the skill, a hook, or the
model performs the rejection, so it cannot tell whether the rejection is something it must
implement or something that happens to it.

**After:** The commit hook rejects a message that carries no scope.

Passive voice is acceptable where the actor genuinely does not matter: "the file is generated at
build time" needs no actor if nothing in the procedure depends on which step generates it.

## 2. One instruction per sentence

**Before:** Run the type check and fix any errors, then commit the result and open a pull request.

**Violation:** Four instructions occupy one sentence. An agent that completes two of them has followed
the sentence as written.

**After:**

1. Run the type check.
2. Fix every error the type check reports.
3. Commit the result.
4. Open a pull request.

Two actions that must happen together stay in one sentence: "Update the version and the changelog in
the same commit."

## 3. Condition before command

**Before:** Regenerate the baselines if the visual difference is intentional.

**Violation:** The agent reads the command before it reads the test that gates the command, so it
begins planning work it may not need to do.

**After:** When the visual difference is intentional, regenerate the baselines.

## 4. Notes informative, instructions imperative

**Before:**

> Note: the dark-theme run reads the light-theme output, so the light theme goes first.

**Violation:** The blockquote carries a rule. An agent that treats notes as context rather than
instruction runs the two themes in the wrong order.

**After:** Promote the rule into the procedure and leave the note holding information only.

1. Run the light-theme snapshots.
2. Run the dark-theme snapshots, which read the light-theme output.

## 5. Guardrail consequence

**Before:** Never edit the generated file.

**Violation:** The prohibition carries no reason, so the agent cannot weigh it against an instruction
that tells it to change what the generated file contains.

**After:** Never edit the generated file, because the next build overwrites the file and the change
disappears without an error.

## 6. Explicit referents

**Before:** Read the configuration and the schema, then validate it.

**Violation:** "It" has two plausible antecedents, and the two readings describe different work.

**After:** Read the configuration and the schema, then validate the configuration against the schema.

## 7. Name the whole set

**Before:** Run the usual checks: types, lint, format, etc.

**Violation:** "Etc." invites the agent to invent members of the set, so two runs check different
things.

**After, when the set is closed:** Run the four checks: types, lint, format, and tests.

**After, when the set is genuinely open:** Run every script whose name ends in `:check`.

## 8. Precise verbs

**Before:** Set up the environment, then roll back the migration if the check fails.

**Violation:** "Set up" and "roll back" each carry several meanings. "Set up" spans installing,
configuring, and starting.

**After:** Configure the environment. When the check fails, revert the migration.

## 9. One term per concept

**Before:** The gate runs before every commit. Skip the quality gate for a documentation-only
change. The preflight suite reports each failure.

**Violation:** Three names for one concept force the agent to decide whether they name the same thing,
and it may conclude that a documentation-only change skips one of three separate procedures.

**After:** Use one name in every sentence and every file.

> The gate runs before every commit. Skip the gate for a documentation-only change. The gate reports
> each failure.

This is the one convention that constrains word choice, and it constrains only consistency. Picking
"gate" over "preflight" is the author's call; using both for one concept is the violation.

## 10. Noun stacks

**Before:** the default branch protection rule override list

**Violation:** Six stacked nouns parse more than one way. The list may hold overrides for the
protection rule, or rules that override the default branch.

**After:** the list of overrides for the default branch's protection rule

Hyphens work when the words genuinely act as a unit: "a read-only access token".

## 11. Verbs over nominalizations

**Before:** Perform a validation of the input before the execution of the query.

**Violation:** Two actions are buried in nouns, and two empty verbs carry the sentence.

**After:** Validate the input before you run the query.

## 12. Mechanics

| Violation             | Before                       | After                             |
| --------------------- | ---------------------------- | --------------------------------- |
| British spelling      | Normalise the path.          | Normalize the path.               |
| Contraction in a rule | Don't stage unrelated files. | Do not stage unrelated files.     |
| Missing article       | Run script before commit.    | Run the script before the commit. |
| Unbound modifier      | a read only access token     | a read-only access token          |

## Rewrites this skill does not make

These pass. Leave them alone.

- **A long guardrail.** "When the working tree holds changes the user did not ask for, stop and list
  them, because a commit that carries unrelated work cannot be reviewed as one change." The sentence
  runs long, names its actor, carries one instruction, and puts its condition first.
- **An unapproved word.** These conventions omit the standard's controlled dictionary, so a word is
  never a violation on its own. "Commence" instead of "start" passes.
- **A deliberate repetition.** A term repeated where a pronoun would read more smoothly is
  convention 6 working, not a violation to smooth away.
- **An imperative fragment in a heading or a list label.** Convention 12 exempts both from the
  article rule.
