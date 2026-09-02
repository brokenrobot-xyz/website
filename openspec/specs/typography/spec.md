# typography Specification

## Purpose

Type is the site's main design material: a display face for UI, a serif for long-form prose, and a monospace for code and labels. This capability fixes those roles and their font-family tokens, and requires fonts to be self-hosted and loaded without blocking text, so the CSP stays strict and reading starts immediately.

## Requirements

### Requirement: Three-role typeface system

The site SHALL use three typefaces by role: a display/UI face (**Space Grotesk**), a long-form prose face (**Newsreader**), and a monospace face (**Space Mono**), exposed via font-family tokens (`--ff-display`, `--ff-prose`, `--ff-mono`). Article body text SHALL use the prose face for readability.

#### Scenario: Roles map to faces

- **WHEN** the UI, an article body, or code/labels are rendered
- **THEN** UI uses Space Grotesk, article prose uses Newsreader, and code/labels use Space Mono, each via its font-family token

#### Scenario: Poppins removed

- **WHEN** the site is built
- **THEN** Poppins is no longer referenced or shipped

### Requirement: Self-hosted fonts

All fonts SHALL be self-hosted (served from the site's own origin), with no third-party font CDN, to comply with the strict CSP `font-src 'self'`.

#### Scenario: No external font requests

- **WHEN** any page loads
- **THEN** no requests are made to third-party font hosts (e.g. Google Fonts), and all font files are served from the site origin

### Requirement: Font loading performance

Fonts SHALL load without blocking text rendering and SHALL not regress load performance. Font face declarations SHALL use `font-display: swap`, and the primary fonts SHALL be preloaded.

#### Scenario: Swap and preload

- **WHEN** a page loads on a slow connection
- **THEN** text is visible immediately using a fallback (via `font-display: swap`) and the primary typefaces are preloaded

#### Scenario: Only required weights shipped

- **WHEN** the build runs
- **THEN** only the font weights actually used by the design are included
