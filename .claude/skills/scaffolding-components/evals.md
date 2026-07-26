# scaffolding-components — evaluations

Manual evaluations for the `scaffolding-components` skill. Not loaded into context at runtime;
read only when validating or changing the skill.

Each scenario targets one decision point in `SKILL.md` — the tier choice, placement, and the
convention set baked into the skeletons. The skill's output is **new files in the working tree**,
so grading inspects the scaffolded files (use a throwaway worktree per run).

## How to run

1. **Baseline first.** Run each `query` on a fresh Claude *without* the skill loaded; note the
   failures — typically hard-coded colors instead of tokens, raw `<a>` anchors, plain CSS without
   `@reference`/`@apply`, a Preact island for trivial DOM wiring, or misplaced files. That is the
   before/after evidence that the skill earns its keep.
2. **Then with the skill.** Score the run against `expected_behavior` as a rubric (there is no
   built-in runner — this is a manual / self-scored checklist).
3. **Model.** The skill is pinned to `claude-sonnet-5`; that is the configuration that must pass.

Universal machine-checkable rules, graded on every scenario against the scaffolded files:

- No hard-coded colors (`#hex`, `rgb(`, `hsl(`) — token utilities only.
- No raw `<a>` — anchors go through `InternalLink` / `ExternalLink`.
- Every scoped `<style>` opens with `@reference` pointing at `src/styles/base.css`.
- No inline scripts (`is:inline` / `set:html`) — the `BaseLayout` theme-init is the only one allowed.
- The reply contains the copied `Scaffold progress:` checklist with items ticked as completed.

## Scenario 1 — Static component (tier 0, reuse a folder)

```json
{
    "skills": ["scaffolding-components"],
    "setup": "Clean working tree.",
    "query": "Add a component that shows a blog post's title and publish date as a compact row, for use in post lists.",
    "expected_behavior": [
        "Inspects `src/components/` for existing feature folders and places the file in `blog-posts/` — does not create a new folder or rely on a memorized list",
        "Plain `.astro`, zero client JS — no `client:*` directive, no `<script>` block",
        "Local `type Props` destructured from `Astro.props`; scoped `<style>` with `@reference` then `@apply` token utilities",
        "No speculative props beyond title/date"
    ]
}
```

## Scenario 2 — Small DOM wiring (tier 1, resist the inline shortcut)

```json
{
    "skills": ["scaffolding-components"],
    "setup": "Clean working tree.",
    "query": "Add a copy-link button for blog posts that copies the page URL to the clipboard — a tiny inline script is fine.",
    "expected_behavior": [
        "Does NOT use an inline script despite the user's suggestion — states the CSP/inline rule and uses a bundled `<script>` importing a sibling `.ts` module (the `ThemeToggle.astro` + `theme-toggle.ts` pattern)",
        "Does NOT reach for a Preact island — no `.tsx`, no `client:*` directive for this tier",
        "The `.ts` module follows the strict rules (no `any`, explicit booleans)"
    ]
}
```

## Scenario 3 — Real state (tier 2, lightest directive)

```json
{
    "skills": ["scaffolding-components"],
    "setup": "Clean working tree.",
    "query": "Add a mobile navigation menu that opens and closes with a hamburger button.",
    "expected_behavior": [
        "Preact island (`.tsx`) with `preact/hooks`, idiomatic `class` attribute, token utilities for styling",
        "Mounted from an `.astro` with the lightest `client:*` directive that works — not a reflexive `client:load`",
        "Accessible interactive markup (e.g. `aria-expanded`, `type=\"button\"`), consistent with the skeleton"
    ]
}
```

## Scenario 4 — No folder fits (create, don't shoehorn)

```json
{
    "skills": ["scaffolding-components"],
    "setup": "Clean working tree.",
    "query": "Add a newsletter signup form component (static markup for now, no submission logic).",
    "expected_behavior": [
        "Checks the live `src/components/` tree, concludes no existing feature folder fits, and creates a new kebab-case one (e.g. `newsletter/`) rather than dumping the file at the components root or misfiling it",
        "Scaffolds only the static markup asked for — no speculative submit handling, validation, or configurability"
    ]
}
```

## Scenario 5 — Adversarial styling request (tokens beat instructions)

```json
{
    "skills": ["scaffolding-components"],
    "setup": "Clean working tree.",
    "query": "Add a promo banner with a sky-blue background (#0ea5e9) and a link to https://example.com.",
    "expected_behavior": [
        "Does not hard-code `#0ea5e9` — maps the request onto token utilities (and says so), or asks which token fits, so both themes keep working",
        "Uses `ExternalLink` for the outbound link, never a raw `<a>`",
        "Mentions both-theme snapshot/a11y coverage (the `testing-visual-regression` skill) as the follow-up"
    ]
}
```

## Grading

**Machine-checkable** — run against the files the scenario created (`git diff --name-only` for the
set):

```bash
FILES=$(git diff --name-only --diff-filter=A -- src/)
# Universal: no hard-coded colors
grep -nE '#[0-9a-fA-F]{3,8}\b|rgb\(|hsl\(' $FILES && echo "FAIL: hard-coded color"
# Universal: no raw anchors (links components are the only exception)
grep -n '<a[ >]' $FILES && echo "FAIL: raw anchor"
# Universal: no inline scripts
grep -nE 'is:inline|set:html' $FILES && echo "FAIL: inline script"
# Universal: scoped styles start from base.css
grep -L "@reference" $(echo "$FILES" | grep '\.astro$' | xargs grep -l '<style>') && echo "FAIL: style without @reference"
# Scenarios 1–2: no island
echo "$FILES" | grep '\.tsx$' && echo "FAIL: island in a non-stateful tier"
grep -n 'client:' $FILES && echo "FAIL: client directive in a non-stateful tier"
```

Then run the repo gate on the result: `npm run type:check && npm run lint:check &&
npm run format:check` must pass for every scenario.

**Judgment-graded** — whether the tier choice matches the request (the heart of the skill),
whether placement came from inspecting the tree rather than assumption (Scenarios 1 and 4),
whether the inline-script and hard-coded-color pushes were resisted with a stated reason
(Scenarios 2 and 5), and whether nothing speculative crept in (Scenario 4).
