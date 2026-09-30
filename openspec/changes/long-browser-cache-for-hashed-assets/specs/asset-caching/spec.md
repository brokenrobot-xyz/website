# Spec Delta

## Purpose

Defines how long a visitor's browser may keep each kind of response from the production site before
it asks the server again, so that repeat views are fast and a deploy never shows an old page.

## ADDED Requirements

### Requirement: Content-hashed build files are cached for one year without revalidation

A successful production response (status 200 or 304) for a file under `/_astro/` SHALL carry a
`Cache-Control` header whose `max-age` is `31536000` and which contains the `immutable` directive.
This holds regardless of the value of the `age` header on the same response.

A file under `/_astro/` has a hash of its content in its name, so a changed file SHALL be published
under a new URL, and a URL under `/_astro/` SHALL NOT serve different content after a deploy.

#### Scenario: A font under `/_astro/` carries the long lifetime

- **WHEN** a client requests a font file under `/_astro/fonts/` from production and receives status
  200
- **THEN** the `Cache-Control` header contains `max-age=31536000` and `immutable`

#### Scenario: A long `age` value does not expire the file

- **WHEN** production answers a request for a file under `/_astro/` with an `age` header above
  `14400`
- **THEN** the `Cache-Control` header still contains `max-age=31536000` and `immutable`, so the file
  is fresh when it arrives

#### Scenario: A revalidation answer keeps the long lifetime

- **WHEN** production answers a conditional request for a file under `/_astro/` with status 304
- **THEN** the `Cache-Control` header contains `max-age=31536000` and `immutable`, so the stored copy
  keeps the long lifetime

#### Scenario: A reload does not re-check a stored file

- **WHEN** a visitor reloads a page in a browser that stored its `/_astro/` files from a response
  that met this requirement
- **THEN** the browser sends no request for those files, where the same reload before this
  requirement produced a 304 for each file with an `age` value above `14400`

### Requirement: Pages and unhashed files keep a short browser cache lifetime

A production response for a page, or for a file published from `public/`, SHALL NOT contain the
`immutable` directive, and its `max-age` SHALL NOT exceed `14400`. A page keeps its URL across
deploys, so a long lifetime would show an old page after a deploy.

#### Scenario: The home page keeps its short lifetime

- **WHEN** a client requests `/` from production
- **THEN** the `Cache-Control` header has `max-age=14400` and does not contain `immutable`

#### Scenario: A file from `public/` keeps its short lifetime

- **WHEN** a client requests `/favicon.svg` from production
- **THEN** the `Cache-Control` header has `max-age=14400` and does not contain `immutable`

### Requirement: Missing files under `/_astro/` are not cached for one year

A production error response for a URL under `/_astro/` SHALL NOT contain the `immutable` directive,
and its `max-age` SHALL NOT exceed `14400`. A later deploy can publish a file under a URL that
returned 404 before, for example after a revert.

#### Scenario: A 404 under `/_astro/` keeps the short lifetime

- **WHEN** a client requests a URL under `/_astro/` that no file matches
- **THEN** production answers 404, and the `Cache-Control` header does not contain `immutable` and
  has a `max-age` no greater than `14400`
