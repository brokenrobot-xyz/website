# DESIGN.md assessment

An evaluation of whether to adopt **Google Labs' DESIGN.md** format (`@google/design.md`) for
brokenrobot.xyz. This is a decision record, not a commitment: it captures the fit, the benefits and
tradeoffs, one real architectural catch, and a recommended proof-of-concept.

> **Status:** adopted (foundation). The DESIGN.md format is **alpha** ("expect changes"). The site's
> colour token values are now the source of truth in `DESIGN.md` / `DESIGN.dark.md`, generated into
> `src/styles/tokens.generated.css` (imported by `base.css`) via `npm run tokens:generate`, with a
> `prebuild` drift-check + lint guard. The analysis below is the record of why. The `design-md-poc/`
> folder is a throwaway trial, slated for removal.

## Summary

Good fit, with one architectural catch. DESIGN.md would fill a real gap — we have no single, agent-first
document tying our brand rationale to our token values — and it targets our exact stack (Tailwind v4).
The catch is that its tokens are **single-valued** while our identity is **dual light/dark**; making it a
literal source of truth for `src/styles/base.css` needs a deliberate two-file mechanism, not a drop-in
export.

**Recommendation:** adopt it as the source of truth for **token values + design rationale**, but earn
that through a throwaway PoC first rather than committing up front. Keep Claude Design for mockups; it
sits upstream of DESIGN.md, unchanged.

## What DESIGN.md is

A single file with two layers:

- **YAML frontmatter** — machine-readable tokens: `colors`, `typography`, `rounded`, `spacing`,
  `components`. Colors are CSS colors (hex / `rgb` / `oklch`); `{path.to.token}` cross-references are
  supported. **Each token name holds exactly one value** — there is no native theme/mode dimension.
- **Markdown body** — human-readable rationale in a canonical section order: Overview → Colors →
  Typography → Layout → Elevation & Depth → Shapes → Components → Do's and Don'ts.

The `@google/design.md` CLI provides:

| Command  | What it does                                                                                               |
| -------- | ---------------------------------------------------------------------------------------------------------- |
| `lint`   | 9 rules, including **`contrast-ratio` (WCAG AA 4.5:1)**, `broken-ref`, `missing-primary`, `section-order`. |
| `diff`   | Token-level + prose regressions between two versions (exit 1 on regression).                               |
| `export` | `css-tailwind` (**Tailwind v4 `@theme {}` block**), `json-tailwind` (v3), `dtcg` (W3C tokens).             |
| `spec`   | Prints the format spec — useful inside agent prompts.                                                      |

## How this repo captures design today

Design intent is real and well-organized, but **split across four encodings** with no single tie-point:

| Encoding                                | Where                                                                  | Role                 |
| --------------------------------------- | ---------------------------------------------------------------------- | -------------------- |
| Narrative brand / voice / visual intent | `docs/brand.md`                                                        | _Why_ / personality  |
| Normative behavior                      | `openspec/specs/{theming,typography,brand-mascot,site-chrome}/spec.md` | _What must hold_     |
| **Token values (source of truth)**      | `src/styles/base.css`                                                  | _The actual numbers_ |
| Prototype / exploration                 | `design-handoff/` (from Claude Design)                                 | Upstream raw intent  |

Mechanics that matter for fit:

- **Tailwind v4**, tokens wired via `@theme inline { --color-bg: var(--bg); … }` — a semantic → theme-var
  indirection. This is a strong match for DESIGN.md's `css-tailwind` export target.
- **Two values per token:** light on `:root`, dark override on `html[data-theme='dark']`; the theme is
  resolved pre-paint by an inline script in `BaseLayout.astro`.
- The token set is **colors + shadows (elevation) + fonts only — no spacing scale** (spacing is Tailwind
  utilities).
- **Naming collision:** `design.md` is already a term here — OpenSpec uses it for a _per-change
  implementation design doc_, which is a different meaning from a durable design-system file.

The gap DESIGN.md would fill is genuine: there is no standing, agent-first design-system document tying
rationale to token values.

## Fit assessment

### Benefits (mapped to the motivations)

1. **Single standing design doc** — closes the real gap: one agent-first file linking the amber/limestone
   rationale to the exact token values. The least-contestable win.
2. **Tooling** — `contrast-ratio` linting is directly useful (we hold WCAG AA in both themes as a
   constraint, but currently verify it only via Playwright/axe); `diff` gives reviewable token-regression
   checks; `export` hits our actual stack.
3. **Better agent-built UI** — a structured, ordered, machine-readable system is a cleaner prompt surface
   than three prose docs plus a CSS file. A marginal gain (agents already read `brand.md` + `base.css`),
   but real for consistency.
4. **Tracking the standard** — low-cost to follow; the `dtcg` (W3C tokens) export is an exit route if the
   alpha format churns.

### Tradeoffs

- **Alpha volatility** — "expect changes"; a generation pipeline built on it may need rework.
- **Dual-theme tax** — the two-file + generator mechanism below; more moving parts than one hand-written
  `base.css`.
- **Naming collision** — keep top-level `DESIGN.md` (the design _system_) distinct from OpenSpec's
  per-change `design.md` (implementation design).
- **Drift risk** — DESIGN.md must be positioned as _the_ token+rationale home, or `brand.md`, the specs,
  and `base.css` become three drifting sources.
- **Partial coverage** — no spacing scale to encode today; `components` / `elevation` would start lightly
  populated.

## The dual light/dark catch — and the fix

**Why it's a problem.** DESIGN.md tokens are single-valued (`colors: { bg: "#faf7f2" }` — one name, one
value, no mode dimension). Our tokens are the opposite: every semantic token has **two** values, and that
duality is first-class. So a single DESIGN.md frontmatter cannot represent our whole token system, and its
`css-tailwind` export emits a _flat_ `@theme { --color-bg: <value> }` block — which would erase our
`@theme inline → var() → data-theme override` indirection and **flatten dark mode away**. `base.css` also
holds non-token logic (`.prose` → `--tw-prose-*` mapping, `color-mix` derivations, transitions) that isn't
expressible as tokens.

**The fix — two token sets, honestly named.** Represent the themes as two files and let DESIGN.md own the
_values + rationale_ while the _structural_ CSS stays hand-authored:

- **`DESIGN.md`** = light (default) theme + all prose/rationale.
- **`DESIGN.dark.md`** = same token names, dark values (tokens-only, minimal prose). These _are_ two token
  sets — this is honest, not a workaround.
- This plays to the linter's strength: running `lint` on **each** file gives automated **WCAG-AA contrast
  checks in both themes** — exactly the constraint we hold.
- A **thin generate step** turns the two exports into just the _value blocks_ of `base.css` — the
  `:root { … }` and `html[data-theme='dark'] { … }` custom-property lists. The `@theme inline` mapping,
  `.prose` block, `color-mix` derivations, and imports remain a small hand-authored shell that imports the
  generated values.

**Conclusion:** "DESIGN.md as the only source of truth" is achievable for what it's designed to own —
**token values + design rationale** — but it is **not** a drop-in generator of the whole `base.css`.
Making it authoritative means adding a two-file convention plus a small build step to a system that is
currently a single hand-written file. That cost is the main tradeoff.

## Recommendation

Adopt DESIGN.md as the source of truth for token **values + rationale**, **staged, not big-bang**, using
the two-file dual-theme mechanism. It fits the stack, fills a real gap, and its contrast lint reinforces a
constraint we already hold. Treat "sole source of truth for `base.css`" as an outcome to **earn** via a
PoC, because the dual-theme generation step is where the risk lives.

- **Naming:** keep top-level `DESIGN.md` (design _system_); leave OpenSpec `design.md` as-is (per-change
  _implementation_ design).
- **Claude Design stays**, downstream: mockups (`design-handoff/`) → encode into `DESIGN.md` → agents
  implement. No Stitch dependency introduced.

## Proposed proof-of-concept (next step)

A throwaway trial to validate the round-trip before any commitment:

1. Hand-write `DESIGN.md` (light + rationale) and `DESIGN.dark.md` (dark values) from the current
   `src/styles/base.css` values.
2. `npx @google/design.md lint` both → **0 errors, `contrast-ratio` passes in both themes**.
3. `npx @google/design.md export --format css-tailwind` both → diff emitted values against the current
   `:root` and `html[data-theme='dark']` blocks (expect a value-for-value match).
4. `diff` an intentional token change (e.g. tweak `--accent`) → confirm it reports the modification.
5. Judgement call from the PoC: promote DESIGN.md to source-of-truth (add the thin generator + wire `lint`
   into `preflight-checks`) **only if** the round-trip is clean; otherwise keep it as an authoritative
   _companion_ doc, with `base.css` still hand-authored.

> Sandbox note: `npx @google/design.md` may trigger an npm-install network prompt in this environment.
