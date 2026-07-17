# Brand

This document defines the personality and visual direction of Broken Robot. The personality
and voice are the lasting commitments. The palette, typography, and mascot below were left
open during early planning and are now **locked** by the design overhaul (explored in Claude
Design, implemented in the foundation) — they can still evolve, but they are decisions, not
suggestions.

## Brand essence

**Broken Robot** is about the human behind the machine, and about embracing imperfection.

- **Embracing imperfection.** Robots break. Bugs, failures, and rewrites are where the
  learning happens. The brand is honest, humble, and iterative rather than slick and
  infallible.
- **The human behind the machine.** "Broken" is the warm, creative, fallible person behind
  otherwise cold and precise engineering. Technology is the medium; a real person is the
  point.

These two ideas should make the brand feel relatable rather than corporate.

## Personality & voice

The voice is **playful & quirky** and **warm & personable** — a real person sharing their
corner of the web with a bit of wit, never a marketing department.

**Do**

- Write in first person, conversational and friendly ("Hello there, my name is Tamas!").
- Allow gentle humor and personality, especially in incidental UI copy (404, empty states,
  buttons).
- Be honest and human — comfortable admitting things break and evolve.
- Stay clear and respectful of the reader's time; playful never means confusing.

**Don't**

- Sound corporate, salesy, or buzzword-heavy.
- Be ironic at the expense of clarity, or quirky to the point of distraction.
- Overpromise or posture as infallible — that contradicts "embracing imperfection."

_Anchor for tone:_ the existing About page copy is the reference register — friendly,
substantive, lightly playful.

## Mascot direction

A **broken robot character** is the recurring brand motif — the face of "embracing
imperfection" and the human-behind-the-machine idea. It is implemented as a theme-aware inline
SVG component (`src/components/mascot/Mascot.astro`): a friendly robot with a crooked
amber-tipped antenna, one round eye + one X eye, a head crack, headphone ears, and an amber
chest button, with poses `head` (logo/footer/callouts) and `sit404` (the 404 page).

Where the mascot shows up:

- Hero / homepage greeting alongside the introduction.
- The **404 page** (a charmingly broken robot is a natural fit; today's 404 uses an image).
- Empty states (e.g. no posts for a tag) and loading/edge states.
- Favicon / logo lockup and social share imagery.

Principles for the mascot: expressive but simple, friendly not creepy, works at small sizes,
and renders well in **both light and dark themes**. Keep file weight modest (see performance
budget below).

## Visual direction (locked)

### Color & theme

Both **light and dark themes are first-class**, with the reader's preference respected. The
theming architecture lives in [architecture](architecture.md) — semantic tokens as CSS custom
properties defined in `src/styles/base.css`, switched by `data-theme` on `<html>`.

Components reference **semantic token roles**, not raw colors:

- `bg` — page background
- `surface` / `surface-2` — cards, code blocks, raised areas
- `text` — primary foreground
- `muted` — secondary text, borders, meta
- `border` — hairlines and dividers
- `accent` / `accent-ink` — the signature brand color, and its AA-contrast ink for text/links

The signature accent is a **warm amber** (`#f59e0b`), with `accent-ink` tuned per theme for
contrast (light `#b45309`, dark `#fbbf24`). The base is a warm near-neutral: off-white in
light (`--bg` `#faf7f2`), deep warm charcoal in dark (`--bg` `#17150f`) — never pure black.
The token values for both themes are the source of truth in `DESIGN.md` (light) and
`DESIGN.dark.md` (dark), compiled into `base.css` via `src/styles/tokens.generated.css` — see
[design-md-assessment](design-md-assessment.md).

### Typography

Three self-hosted typefaces, by role (see [tech-stack](tech-stack.md)):

- **Space Grotesk** — display & UI (headings, nav, buttons).
- **Newsreader** — long-form article prose; body legibility is the priority.
- **Space Mono** — code, labels, tags, and the robot's "voice".

Fonts are self-hosted with `font-display: swap` and the primary weights preloaded; only the
weights actually used are shipped.

### Motifs & imagery

- **Iconography:** Feather Icons today — keep a clean, consistent line-icon style.
- **Diagrams:** Excalidraw / draw.io; the hand-drawn Excalidraw style pairs well with the
  playful, imperfect brand.
- **Illustration style:** should harmonize with the mascot — simple, friendly, line-forward.

## Brand constraints

- **Contrast & accessibility.** Color choices meet WCAG AA contrast in _both_ themes.
  Accessibility is a standing commitment, not an afterthought (see [vision](vision.md)).
- **Performance budget.** Fonts and illustrations stay light on load performance. Prefer SVG
  for the mascot/icons, keep raster art optimized, and limit font weights to those actually
  used.
