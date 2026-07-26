---
version: alpha
name: Broken Robot
description: Warm, imperfect developer-blog identity — amber ink on limestone paper (light theme).
colors:
    bg: '#faf7f2'
    surface: '#ffffff'
    surface-2: '#f4f0e8'
    text: '#211d18'
    muted: '#736a5b'
    border: '#e8e1d5'
    accent: '#f59e0b'
    accent-ink: '#b45309'
    primary: '{colors.accent}'
    code-bg: '#211e19'
    code-text: '#ece6da'
    code-line: '#33302a'
    syntax-comment: '#978d7d'
    syntax-keyword: '#f5b544'
    syntax-string: '#9ec37a'
    syntax-symbol: '#7db4d8'
    syntax-number: '#e0a45e'
    syntax-punctuation: '#a89e8d'
typography:
    display:
        fontFamily: 'Space Grotesk'
    prose:
        fontFamily: 'Newsreader'
    mono:
        fontFamily: 'Space Mono'
components:
    page:
        backgroundColor: '{colors.bg}'
        textColor: '{colors.text}'
    surface:
        backgroundColor: '{colors.surface}'
        textColor: '{colors.text}'
    muted-text:
        backgroundColor: '{colors.bg}'
        textColor: '{colors.muted}'
    link:
        backgroundColor: '{colors.bg}'
        textColor: '{colors.accent-ink}'
    code-block:
        backgroundColor: '{colors.code-bg}'
        textColor: '{colors.code-text}'
---

## Overview

Broken Robot is a personal developer blog with a warm, slightly imperfect character — "the human
behind the machine." The light theme is dark ink on a limestone-paper background, with a single warm
amber accent.

**This file is the source of truth for the site's colour and typography tokens.** It holds the light
(default) theme plus the full rationale; the dark theme lives in `DESIGN.dark.md` with the same token
names and dark values. The token _values_ here are compiled into `src/styles/tokens.generated.css`
(consumed by `src/styles/base.css`) by `npm run tokens:generate` — do not hand-edit that file. Not
every design decision is a token: spacing, shadows/elevation, and `color-mix` derivations stay
hand-authored in `base.css` (see the Layout and Elevation sections).

## Colors

Semantic roles, not raw swatches — components read a role, never a hex.

- `bg` / `surface` / `surface-2` — the paper stack (page, raised cards, insets).
- `text` / `muted` — primary and secondary foreground.
- `border` — hairline separators.
- `accent` — the single brand hue, warm amber `#f59e0b`. Used decoratively (underlines, the mascot,
  focus) rather than as a text background.
- `accent-ink` — a darker amber for text/links that need contrast on paper.
- `code-bg` / `code-text` / `code-line` — code blocks and their line separators.
- `syntax-*` — the six syntax-highlighting roles painted on `code-bg`: `comment` (warm grey,
  italic), `keyword` (amber, tying code to the brand hue), `string` (green), `symbol` (blue —
  functions, properties, attribute names), `number` and `punctuation`. Both themes share one
  palette, because `code-bg` is dark in each. Prism applies them by class; a highlighter that
  emits inline `style` attributes instead would break the Content-Security-Policy (see
  `security.csp` in `astro.config.ts`). Like `code-line`, these are colour-only roles with no
  component pairing, so the linter's "never referenced by any component" note is expected.
- `primary` — a tooling alias for `accent`; not emitted as a CSS variable.

## Typography

Three self-hosted faces by role: **Space Grotesk** for display/UI, **Newsreader** for long-form
prose, **Space Mono** for code and labels. Family values are wired through the Astro Fonts API in
`base.css` (with fallback stacks); the names here are the design intent, not the runtime source.

## Layout

Spacing and sizing use Tailwind utilities rather than a fixed token scale, so there is no `spacing`
token set — the linter's "no spacing section" note is expected.

## Elevation & Depth

Two shadow levels live in `base.css` (not as tokens in this format, which has no shadow type):
`--shadow` for resting cards and `--shadow-lift` for raised/hovered surfaces. Both are warm-tinted in
light and deepened in dark.

## Shapes

No dedicated radius token scale; corners use Tailwind's rounding utilities.

## Components

Real text pairings the linter contrast-checks: `page` and `surface` (body text on paper), `muted-text`
(secondary text on bg), `link` (accent-ink on bg), and `code-block`. `accent` is intentionally not a
text-background component — it is decorative.

## Do's and Don'ts

- **Do** read every colour from a token; never hard-code a hex for a themed role.
- **Do** keep both themes first-class — every colour token has a dark counterpart in `DESIGN.dark.md`.
- **Do** run `npm run tokens:generate` after changing any token, and commit the regenerated CSS.
- **Don't** introduce a second accent hue; amber is the only brand colour.
- **Don't** put body text on an `accent` fill — it won't meet contrast; use `accent-ink` on paper.
