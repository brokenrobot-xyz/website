# site-chrome Specification

## Purpose

The header and footer are the frame every page shares: the brand lockup, primary navigation, the theme toggle, and the site's outbound links. This capability defines what that chrome must contain, how it adapts on small screens, and the navigation contract it must preserve, so existing destinations, the RSS feed, and article permalinks keep working through redesigns.

## Requirements

### Requirement: Site header

The site SHALL render a header containing a logo (mascot head + "BrokenRobot" wordmark + a monospace `brokenrobot.xyz` line), primary navigation, and the theme toggle. The header SHALL be responsive and SHALL not overflow on small screens.

#### Scenario: Header contents

- **WHEN** any page renders
- **THEN** the header shows the logo, the primary nav links, and the theme toggle control

#### Scenario: Responsive header

- **WHEN** the viewport is phone-width
- **THEN** the header layout adapts (condensing secondary elements) without horizontal overflow

#### Scenario: Active nav state

- **WHEN** a reader is on a section's page
- **THEN** the corresponding nav item is visibly marked active

### Requirement: Site footer

The site SHALL render a footer containing the mascot, a short brand blurb, link columns (writing/about and elsewhere/social + RSS), and a sign-off line. Links SHALL use the existing internal/external link components and remain keyboard accessible.

#### Scenario: Footer contents

- **WHEN** any page renders
- **THEN** the footer shows the mascot, the blurb, the link columns including social and RSS, and the sign-off

#### Scenario: Footer responsive stacking

- **WHEN** the viewport is phone-width
- **THEN** the footer columns stack vertically and remain readable

### Requirement: Chrome preserves existing navigation contract

The redesigned header and footer SHALL preserve existing destinations and link semantics: navigation to home, the blog/writing index, and about; the RSS feed link; and stable `/blog/<slug>/` article URLs.

#### Scenario: Existing destinations intact

- **WHEN** a reader uses the header or footer links
- **THEN** they reach the same destinations as before (home, writing index, about, RSS), with no broken or changed permalinks
