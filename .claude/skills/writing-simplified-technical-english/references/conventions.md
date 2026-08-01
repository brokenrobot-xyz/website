# The writing conventions

The twelve conventions this skill applies, the reasoning behind them, and their traceability to the
source standard.

## Contents

- [Why these conventions exist](#why-these-conventions-exist)
- [Where they come from](#where-they-come-from)
- [The conventions](#the-conventions)
- [What is deliberately not here](#what-is-deliberately-not-here)
- [Traceability](#traceability)
- [Copyright and attribution](#copyright-and-attribution)

## Why these conventions exist

An agent reads instruction prose and then decides what to do. Every ambiguity in that prose is a
branch the agent can take wrongly. The conventions below target ambiguity, and only ambiguity. They
are not a style guide, and they are not a readability standard.

The scope these conventions govern, and the prose they deliberately leave alone, are listed in the
`SKILL.md` that references this file.

## Where they come from

These conventions adapt ASD-STE100 Simplified Technical English, Issue 9 (ASD, 2025-01-15), a
controlled-language standard for technical documentation. They adopt the part of that standard that
removes ambiguity. They reject the part that targets human reading speed, because an agent does not
have the reading constraints the standard was designed for.

Two parts of the standard are deliberately absent, and both are large:

- **The controlled dictionary** — the approved word list that most practitioners mean when they say
  Simplified Technical English — is not adopted. These conventions never restrict which word an
  author chooses to name a thing, except where one concept carries two names, which convention 9
  covers.
- **The sentence-length caps** are rejected for the reason recorded in § What is deliberately not
  here.

Prose that satisfies every convention below is therefore not Simplified Technical English. It is an
adaptation that keeps the standard's ambiguity rules and drops its vocabulary control.

## The conventions

### 1. Name the actor

Write in the active voice. Passive constructions hide who acts, and in an instruction the actor is
the most important word. "The message is rejected" leaves the agent to guess whether the skill, the
hook, or the model does the rejecting. Write "the hook rejects the message" instead.

### 2. Write one instruction per sentence

Give each sentence one thing to do. Two instructions in one sentence become one instruction that the
agent half-follows. The exception is two actions that must happen at the same time.

### 3. Put the condition before the command

When a step applies only sometimes, open with the condition, add a comma, then give the command. The
agent decides whether the step applies before it reads what the step does. Write "When the branch is
`main`, warn the user" rather than "warn the user if the branch is `main`".

### 4. Keep notes informative and instructions imperative

A note gives information. A note never carries a rule. When an aside contains something the agent
must do, it is not an aside — promote it into a numbered step. This convention matters most in
blockquotes and parentheticals, where normative text hides easily.

### 5. Give every guardrail a consequence

A prohibition without a reason is a rule the agent cannot weigh against a conflicting instruction.
State the risk or the result. Write "Never stage every changed file without the user's say-so,
because it stages unrelated work into a commit the user cannot review" rather than the prohibition
alone.

### 6. Make every referent explicit

Never leave a bare "this", "that", "it", or "they". Follow the demonstrative with the noun it refers
to. Write "this check", "that file", "the baseline" instead. A pronoun with two plausible antecedents
is a coin flip.

When two antecedents stay plausible after you read the surrounding procedure, the text does not
carry the answer — leave the pronoun and report the line, because naming the wrong noun hides the
coin flip instead of settling it.

### 7. Name the whole set

Never close a list with "etc.", "and so on", or "and similar". An open set invites the agent to
invent members of it. When the set is genuinely open, say what the membership test is.

### 8. Use precise verbs

Replace phrasal verbs with single verbs that carry one meaning. "Set up", "roll back", "check in",
and "point to" each carry several. Write "configure", "revert", "commit", and "reference".

### 9. Use one term per concept

Pick one name for each thing and keep it everywhere, across every file in the document set. "Gate",
"quality gate", and "preflight" for one concept force the agent to decide whether they mean the same
thing.

### 10. Keep noun stacks to three words

A run of four or more nouns has more than one valid reading. When a term needs more words, write it
in full once, then define a shorter form or join the words that act as a unit with hyphens.

### 11. Prefer a verb to a noun built from a verb

Write "validate the input" rather than "perform validation of the input". The verb form names the
action directly, and it removes the empty verb that would otherwise carry the sentence.

### 12. Mechanics

- Use American spelling.
- Write out contractions in normative sentences.
- Use an article or a demonstrative before a noun, unless the line is a heading or a list label.
- Use hyphens to bind words that modify each other.

## What is deliberately not here

**There is no sentence-length rule and no word-count rule. Do not add one.**

The source standard caps sentences at 20 words in procedures and 25 in descriptions, and it defines a
word-counting apparatus to make those caps checkable. These conventions reject the caps and the
apparatus together.

The sentences that exceed those caps are the guardrails that bind a condition to an action. Splitting
them to satisfy a word count risks breaking that binding, which creates the ambiguity these
conventions exist to remove. A long sentence that names its actor, carries one instruction, and puts
its condition first is already clear. Length is not the defect these conventions are looking for.

## Traceability

Each convention above condenses one or more rules from the source standard. The mapping is recorded
here so that a reader who knows the standard can see what was taken.

| Convention                      | Source rules in ASD-STE100 Issue 9 |
| ------------------------------- | ---------------------------------- |
| 1. Name the actor               | 3.6                                |
| 2. One instruction per sentence | 5.2                                |
| 3. Condition before command     | 5.4                                |
| 4. Notes and instructions       | 5.3, 5.5                           |
| 5. Guardrail consequence        | 7.1, 7.2, 7.3                      |
| 6. Explicit referents           | GR-3, GR-4                         |
| 7. Name the whole set           | GR-6                               |
| 8. Precise verbs                | 9.3, 1.3, 1.10                     |
| 9. One term per concept         | 1.11, 9.4, 1.8, 1.9                |
| 10. Noun stacks                 | 2.1, 2.2, 8.2                      |
| 11. Verbs over nominalizations  | 3.7, 3.3                           |
| 12. Mechanics                   | 1.14, 4.2, 4.5, 4.4, 8.3           |
| Structure already in use        | 4.1, 4.3, 6.2, 6.4, 6.5, 6.6       |
| Rejected, see above             | 5.1, 6.3, 8.4, 8.5, 8.6, 8.7       |

The standard's remaining rules (1.1, 1.4, 1.6, 1.12, 3.1, 9.1, 9.2) depend on its controlled
dictionary, which these conventions do not adopt.

## Copyright and attribution

ASD-STE100 is free of charge, and ASD retains copyright in it. The reproduction rights in the
standard cover a defined list of aerospace and defense organizations. The conventions above are
therefore written in original wording as house rules, and ASD does not endorse them.

Never paste the standard's rule text, dictionary, or examples into a document that uses these
conventions, because reproducing that text exceeds the rights granted to a reader outside the listed
organizations. Download the standard from <https://www.asd-ste100.org> when you need the source
text.
