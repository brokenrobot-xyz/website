## Purpose

Defines how the site exposes its writing in machine-readable form for AI agents and other
non-browser clients: a Markdown representation of each blog post, the metadata and licensing terms
those representations carry, and how an agent discovers them from an HTML page or from the site's
`llms.txt` index — without disturbing the contracts human readers and feed consumers depend on.

## ADDED Requirements

### Requirement: Markdown representation of every blog post

The site SHALL publish a Markdown representation of every published blog post at a stable,
predictable URL derived from that post's permalink. Every post SHALL have exactly one such
representation, and it SHALL be available without any request header, query parameter, or
negotiation on the client's part.

How that representation is identified to a client — the content type it is served with — is a
property of the serving layer rather than of the built artifact, and is out of scope here.

#### Scenario: Every post has a Markdown representation

- **WHEN** the site is built
- **THEN** each published blog post has a corresponding Markdown representation, and no post is
  missing one

#### Scenario: Reachable without negotiation

- **WHEN** a client requests the Markdown URL directly, sending no `Accept` header preference
- **THEN** the Markdown representation is returned

### Requirement: Markdown representations are faithful to the authored article

The Markdown representation SHALL be derived from the authored article source rather than from
rendered HTML, and SHALL contain the article's prose only — no site chrome such as header,
navigation, footer, or theme controls. Code samples SHALL be reproduced exactly as authored,
including any markup that appears inside them. Images that appear in the article SHALL be
represented as standard Markdown images whose targets are absolute URLs resolvable outside the site,
and SHALL retain their alternative text. No authoring-tool syntax — component markup or module
imports — SHALL remain in the output.

#### Scenario: No site chrome

- **WHEN** an agent reads a post's Markdown representation
- **THEN** it contains the article's prose and no header, navigation, footer, or theme-control
  content

#### Scenario: Code samples are untouched

- **WHEN** an article contains a fenced code sample that itself contains markup resembling component
  syntax
- **THEN** that sample appears in the Markdown representation exactly as authored, unmodified

#### Scenario: Images become resolvable Markdown images

- **WHEN** an article embeds an image
- **THEN** the Markdown representation renders it as a Markdown image with its alternative text and
  an absolute URL that resolves to the published image

#### Scenario: No authoring syntax leaks

- **WHEN** an agent reads any post's Markdown representation
- **THEN** it contains no component markup and no module import statements

### Requirement: Markdown representations carry metadata and licensing terms

Each Markdown representation SHALL begin with structured metadata identifying at least the article's
title, summary, publication date, tags, hero image, and the canonical URL of the human-readable page.
Any image the metadata names SHALL be an absolute URL resolvable outside the site, not a path
relative to the article's source. The metadata SHALL also state the copyright and attribution terms,
so that the terms travel with the content when it is consumed detached from the site.

#### Scenario: Metadata present

- **WHEN** an agent reads a post's Markdown representation
- **THEN** it finds the title, summary, publication date, tags, hero image, and canonical page URL in
  structured metadata at the top of the file

#### Scenario: Metadata images resolve away from the site

- **WHEN** an agent reads a post's Markdown representation away from the origin
- **THEN** the hero image it names is an absolute URL that resolves to the published image

#### Scenario: Terms travel with the content

- **WHEN** an agent reads a post's Markdown representation
- **THEN** the copyright and attribution terms are stated within that file, consistent with the terms
  published in the site's `llms.txt`

### Requirement: Agents can discover the Markdown representation

An agent SHALL be able to find a post's Markdown representation from two independent starting
points: the post's own HTML page, which SHALL advertise the Markdown URL as an alternate
representation of itself; and the site's `llms.txt` index, which SHALL list the Markdown URL
alongside each post's human-readable URL. Discovery SHALL NOT require the agent to guess a URL
pattern.

#### Scenario: Discoverable from the HTML page

- **WHEN** an agent fetches a post's HTML page
- **THEN** the page advertises that post's Markdown URL as an alternate `text/markdown`
  representation

#### Scenario: Discoverable from the index

- **WHEN** an agent fetches the site's `llms.txt`
- **THEN** each listed post entry includes its Markdown URL in addition to its human-readable URL

#### Scenario: Existing index content preserved

- **WHEN** an agent fetches `llms.txt` after this change
- **THEN** the site summary, page listings, licensing note, and feed and sitemap references it
  carried before are still present

### Requirement: Existing reader and crawler contracts are preserved

Adding Markdown representations SHALL NOT change any URL, feed, or document that readers, feed
consumers, or search engines already rely on. The Markdown URLs are additive. Because they duplicate
article content, they SHALL NOT be advertised to search engines as indexable destinations, and each
SHALL name the human-readable page as its canonical source.

#### Scenario: Permalinks and feed unchanged

- **WHEN** a reader or feed consumer requests an existing article permalink or the RSS feed
- **THEN** it responds exactly as it did before this change, with no altered or broken URLs

#### Scenario: Twins stay out of the sitemap

- **WHEN** a search engine reads the site's sitemap
- **THEN** the sitemap lists the human-readable pages and does not list the Markdown
  representations

#### Scenario: Canonical page identified

- **WHEN** any client reads a post's Markdown representation
- **THEN** that file names the corresponding human-readable page URL as canonical
