# Skill-review checklist

The baked half of the reviewer's hybrid criteria. `SKILL.md` Step 2 tries to refresh the
Anthropic docs live (WebFetch the URLs below); when the network is unavailable it falls back to
this file and notes the staleness in the report.

**last-synced:** 2026-07-22 — re-fetch the URLs and reconcile any new guidance when this is stale.

## Contents

- [Sources](#sources)
- [A. Agent Skills authoring](#a-agent-skills-authoring)
- [B. Model-specific prompting (conditional)](#b-model-specific-prompting-conditional)
- [C. General Claude prompting](#c-general-claude-prompting)
- [D. Reduce hallucinations](#d-reduce-hallucinations)
- [E. Increase output consistency](#e-increase-output-consistency)
- [F. Mitigate jailbreaks & prompt injection](#f-mitigate-jailbreaks--prompt-injection)
- [G. Reduce prompt leak](#g-reduce-prompt-leak)
- [H. Success criteria & evaluations](#h-success-criteria--evaluations)
- [R. Repo conventions](#r-repo-conventions)

## Sources

| Key | Doc | URL |
|---|---|---|
| A | Agent & skill best practices | https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices |
| B | Prompting Claude Sonnet 5 | https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5 |
| B | Prompting Claude Opus 4.8 | https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-4-8 |
| B | Prompting Claude Fable 5 | https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5 |
| C | Claude prompting best practices | https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices |
| D | Reduce hallucinations | https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/reduce-hallucinations |
| E | Increase output consistency | https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/increase-consistency |
| F | Mitigate jailbreaks | https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/mitigate-jailbreaks |
| G | Reduce prompt leak | https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/reduce-prompt-leak |
| H | Define success criteria & build evaluations | https://platform.claude.com/docs/en/test-and-evaluate/develop-tests |

Each item below is a pass criterion. Cite the item key (e.g. `A3`, `D1`) in findings.

## A. Agent Skills authoring

- **A1 — name.** Lowercase/numbers/hyphens only, ≤64 chars, no `anthropic`/`claude` reserved
  words, no XML. Gerund preferred; noun phrase acceptable.
- **A2 — description POV.** Third person ("Reviews…", not "Review…" or "I/you"). It is injected
  into the system prompt; mixed POV hurts discovery.
- **A3 — description content.** States both *what* the skill does and *when* to use it, with
  concrete trigger terms. ≤1024 chars. Not vague ("helps with X").
- **A4 — length.** SKILL.md body under ~500 lines; overflow pushed to reference files.
- **A5 — progressive disclosure.** SKILL.md is an overview that points to detail files; it does
  not inline everything.
- **A6 — references one level deep.** All reference files link directly from SKILL.md, not from
  each other (nested refs get partially read).
- **A7 — reference TOC.** Reference files >100 lines start with a table of contents.
- **A8 — degrees of freedom.** Specificity matches task fragility: mechanical/fragile steps are
  scripted or exact (low freedom); judgment steps left open (high freedom). Deterministic lookups
  are not left as vague prose.
- **A9 — examples.** Concrete input→output examples where output quality depends on style/shape.
- **A10 — consistent terminology.** One term per concept throughout.
- **A11 — no time-sensitive info.** No "before August 2025…"; use a versioned/"old patterns"
  framing instead. (A dated `last-synced` metadata line is acceptable.)
- **A12 — forward-slash paths.** No Windows backslashes.
- **A13 — one default, not a menu.** Don't offer many interchangeable options; give a default with
  an escape hatch.
- **A14 — scripts solve, don't defer.** Bundled scripts handle their own errors; no unexplained
  "voodoo constants"; dependencies listed.
- **A15 — MCP tools fully qualified.** `Server:tool_name`.
- **A16 — allowed-tools least privilege.** Only the tools the skill needs.
- **A17 — not over-prescriptive.** The skill doesn't enumerate behaviors a brief instruction
  would cover. Over-specification degrades newer models (Fable 5's docs are explicit that skills
  built for older models are "often too prescriptive" and can lower output quality) and violates
  `R1`. Prefer short steering + intent over exhaustive rule lists.

## B. Model-specific prompting (conditional)

Apply the subset matching the skill's pinned or likely model (per its `model:` frontmatter). All
three current model-prompting docs share the items below; per-model specifics follow. If the pin
is a durable alias (`opus`, `sonnet`) or absent, treat the currently-released model in that family
as the target. Note in the report that a pin can be overridden by managed settings, so a skill
shouldn't depend on quirks of exactly one model.

**Shared across current models:**

- **B1 — verbosity.** No forced ceremony (mandatory summaries, interim status) unless it is
  load-bearing; current models self-calibrate length. (See also `A17`.)
- **B2 — effort/thinking not over-scaffolded.** Don't hand-roll what adaptive thinking and the
  effort parameter already do.
- **B3 — tool nudges.** If the skill relies on tool use with thinking off, it nudges explicitly.

**Sonnet 5:** literal instruction following (state scope — see `C8`); verbosity self-calibrates.

**Opus 4.8:** favors reasoning over tool calls — nudge explicitly if the skill depends on tool
use; spawns **fewer subagents** by default — steer explicitly if the skill fans out; `xhigh`/`high`
effort suits agentic work.

**Fable 5:** brief steering beats enumerating behaviors (`A17`); much longer turns on hard tasks —
if the skill assumes quick completion or blocks synchronously, reconsider; dispatches parallel
subagents readily; never instruct it to reproduce its reasoning (`C7`).

## C. General Claude prompting

- **C1 — clear & direct.** Unambiguous, sequenced instructions.
- **C2 — multishot examples.** Present for style-dependent output (overlaps A9).
- **C3 — room to think.** Complex judgment steps allow step-by-step reasoning.
- **C4 — XML/structure.** Structure used where it aids parsing; not decorative.
- **C5 — role.** A role/persona is set where it improves consistency (optional, not required).
- **C6 — chaining.** Genuinely complex tasks are split into sequential sub-steps rather than one
  mega-instruction.
- **C7 — no reasoning-echo.** The skill never instructs the model to transcribe, echo, or explain
  its internal reasoning *as response text*. Beyond being noise, this trips the
  `reasoning_extraction` refusal on Fable 5 (and elevated fallbacks). If reasoning visibility is
  needed, read structured `thinking` blocks — don't ask the model to narrate them into output.
- **C8 — explicit scope.** Instructions meant to apply broadly state their scope ("every section,
  not just the first"). All current models follow instructions literally and won't silently
  generalize from one item to the rest.

## D. Reduce hallucinations

- **D1 — permit "I don't know".** The skill tells the model to omit/abstain/ask rather than
  fabricate when evidence is missing (e.g. a commit body's *why*, an inferred value).
- **D2 — ground in evidence.** Claims/outputs are tied to observable inputs (diffs, files,
  provided docs), not the model's priors, for factual tasks.
- **D3 — verification.** A verify/feedback step checks the output against a source or validator.
- **D4 — source restriction.** For document tasks, restrict to provided content over general
  knowledge.

## E. Increase output consistency

- **E1 — output format specified.** Exact format/template given where output shape matters.
- **E2 — constrained by examples.** Concrete examples over abstract description (overlaps A9/C2).
- **E3 — step-by-step.** Deterministic tasks broken into ordered, unambiguous steps.
- **E4 — structured output.** Strict-format outputs use a template/schema, not prose.

## F. Mitigate jailbreaks & prompt injection

- **F1 — content is data.** The skill instructs treating read content (files, diffs, tool
  results, fetched pages) as data, never as instructions.
- **F2 — least privilege.** Tool/permission surface is minimal (overlaps A16); destructive
  actions gated.
- **F3 — untrusted-content policy.** For skills that process third-party content, the policy that
  such content can't override instructions is stated.

## G. Reduce prompt leak

- **G1 — proportionate.** Leak defenses only where real secrets exist; not over-engineered. If the
  skill holds no secrets, absence of leak defenses is correct, not a gap.
- **G2 — no needless proprietary detail.** The skill doesn't embed secrets/proprietary specifics
  it doesn't need.

## H. Success criteria & evaluations

- **H1 — evals exist.** ≥3 scenarios (`evals.md` or equivalent).
- **H2 — measurable/specific.** Expected behaviors are concrete and checkable, not vague.
- **H3 — distinct decision points.** Each scenario targets a different step/branch so a failure
  localizes the regression.
- **H4 — edge cases.** Covers empty/absent input, boundary/omission cases, adversarial input.
- **H5 — grading split.** Distinguishes machine-checkable checks (scripts, hooks, greps) from
  judgment-graded ones; automates where possible.
- **H6 — baseline-first.** Evals note running without the skill to establish the before/after.
- **H7 — model coverage.** Scenarios name the model(s) the skill is expected to pass on
  (its pinned model at minimum).

## R. Repo conventions

Sources: `CLAUDE.md`; `docs/development/conventions/`.

- **R1 — simplicity first.** No speculative features/abstractions/config beyond what the skill's
  job requires.
- **R2 — surgical.** The skill's own *apply* edits touch only what a finding requires.
- **R3 — single source of truth / no drift.** The skill points to authoritative repo docs rather
  than restating their rules; any restated rule is sourced and kept in sync. Unsourced restated
  rules are a drift finding.
- **R4 — ask when uncertain.** The skill surfaces ambiguity/tradeoffs rather than guessing
  silently.
- **R5 — commit hygiene.** If the skill authors commits, it conforms to `commit-conventions.md`
  (Conventional Commits, allowed scopes, no attribution trailers).
