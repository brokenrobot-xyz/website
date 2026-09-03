# theming Specification

## Purpose

Light and dark are both first-class on brokenrobot.xyz. This capability defines the semantic design tokens components read instead of raw colors, how the two themes are selected and persisted, how the resolved theme is applied before first paint without weakening the strict CSP, and the control readers use to switch.

## Requirements

### Requirement: Semantic design tokens

The site SHALL define its visual style through semantic CSS custom properties (e.g. `--bg`, `--surface`, `--surface-2`, `--text`, `--muted`, `--border`, `--accent`, `--accent-ink`, `--code-bg`, `--code-text`, `--code-line`, shadow and font-family tokens) rather than hard-coded colors, so components reference roles, not raw values.

#### Scenario: Components reference tokens

- **WHEN** a component needs a color, surface, border, or shadow
- **THEN** it reads the corresponding CSS custom property (token) and never hard-codes a hex value for a themed role

#### Scenario: Accent is amber

- **WHEN** the light theme is active
- **THEN** `--accent` resolves to `#f59e0b` and `--accent-ink` to an AA-contrast amber suitable for text/links

### Requirement: Light and dark themes

The site SHALL provide both a light and a dark theme as first-class options, selected by a `data-theme` attribute (`"light"` or `"dark"`) on the root `html` element. Every themed token SHALL have a value defined for both themes.

#### Scenario: Dark theme overrides tokens

- **WHEN** `html[data-theme="dark"]` is set
- **THEN** every semantic token resolves to its dark value (deep charcoal background, light text), with no token left undefined

#### Scenario: WCAG AA contrast in both themes

- **WHEN** text, links, and UI controls are rendered in either theme
- **THEN** their color/background pairings meet WCAG AA contrast in both themes, and the automated accessibility (axe) checks pass (run against the light theme; dark-theme automated coverage is added with the page redesign)

### Requirement: Theme preference selection and persistence

The site SHALL determine the active theme from the reader's stored preference if present, otherwise from the operating system's `prefers-color-scheme`, defaulting to light. The reader's explicit choice SHALL persist across page loads.

#### Scenario: Honors system preference on first visit

- **WHEN** a reader with no stored preference loads the site and their OS prefers dark
- **THEN** the site renders in the dark theme

#### Scenario: Explicit choice persists

- **WHEN** a reader toggles the theme and later navigates to another page or returns to the site
- **THEN** the previously chosen theme is applied

### Requirement: No flash of incorrect theme

The site SHALL apply the resolved theme before first paint so that no flash of the wrong theme occurs on load. The mechanism SHALL comply with the existing strict Content-Security-Policy (no inline `on*` event handlers; only `script-src 'self' 'unsafe-inline'`).

#### Scenario: Dark reader sees no light flash

- **WHEN** a reader whose resolved theme is dark loads any page
- **THEN** the page renders dark from the first paint, with no momentary light flash

#### Scenario: CSP unchanged

- **WHEN** the theme initialization runs
- **THEN** it does so without weakening the existing CSP and without inline event-handler attributes

### Requirement: Theme toggle control

The site header SHALL provide an accessible control to switch between light and dark themes, reflecting the current theme.

#### Scenario: Toggle switches theme

- **WHEN** a reader activates the theme toggle
- **THEN** the active theme flips, the new choice is persisted, and the control's icon/label reflects the new state

#### Scenario: Toggle is accessible

- **WHEN** the toggle is reached by keyboard or screen reader
- **THEN** it is focusable, operable via keyboard, and has an accessible name describing its action
