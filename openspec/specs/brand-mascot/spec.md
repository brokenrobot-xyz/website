# brand-mascot Specification

## Purpose

The Broken Robot mascot is the site's recurring brand motif: the face of "embracing imperfection" and of the human behind the machine. This capability makes that character a reusable, theme-aware, accessible component, so the logo, footer, callouts, and the 404 page all show the same robot instead of each surface redrawing it.

## Requirements

### Requirement: Reusable mascot component

The site SHALL provide a reusable Broken Robot mascot as an inline SVG Astro component — a friendly robot with the established character cues (crooked amber-tipped antenna, one round eye + one X eye, a head crack, headphone ears, amber chest button). It SHALL support, at minimum, a head-only variant and a sitting "404" pose, and accept a size.

#### Scenario: Head variant for chrome

- **WHEN** the logo, footer, or an article callout needs the mascot
- **THEN** the head-only variant renders at the requested size

#### Scenario: Sitting 404 pose is available

- **WHEN** the mascot is requested with the `sit404` pose
- **THEN** the sitting "404" pose renders

### Requirement: Theme-aware mascot

The mascot SHALL adapt to the active theme using semantic tokens / `currentColor` rather than fixed colors, so it reads correctly on both light and dark backgrounds.

#### Scenario: Reads in both themes

- **WHEN** the mascot is shown in light or dark theme
- **THEN** its outline and fills derive from theme tokens and remain clearly visible against the current background

### Requirement: Accessible, motion-respecting mascot

The mascot SHALL expose an appropriate accessible name (or be marked decorative where appropriate), and any animation (blink, wobble, antenna sway) SHALL be disabled when the reader prefers reduced motion.

#### Scenario: Reduced motion disables animation

- **WHEN** the reader has `prefers-reduced-motion: reduce`
- **THEN** the mascot renders without animation

#### Scenario: Accessible name

- **WHEN** the mascot conveys meaning (e.g. on the 404 page)
- **THEN** it provides an accessible label; where purely decorative, it is hidden from assistive tech
