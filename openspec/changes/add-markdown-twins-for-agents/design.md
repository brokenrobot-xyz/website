## Context

See `proposal.md` — Why for the motivation and the Cloudflare cost analysis.

Constraints and current state that shape the approach:

- **Static output only.** No SSR, no Pages Functions, no zone Transform Rules. Everything is decided
  at build time. This is what rules out `Accept: text/markdown` negotiation entirely.
- **Precedent exists.** `src/pages/llms.txt.ts` is already a static `APIRoute` that assembles
  Markdown from the `blog` collection and returns a `Response` with an explicit content type. The
  new endpoint should read as a sibling of it.
- **Source is MDX, not Markdown.** All ten posts are `src/content/blog/<slug>/index.mdx`. The bodies
  are nearly clean Markdown. The only component used in body content is `BlogPostPicture`, taking
  `src` and `alt` — 10 occurrences across 4 posts, every one of them spanning four lines — plus the
  `import` lines binding those `src` identifiers to image files. Those files are not always the
  post's own: `url-redirect-with-amazon-cloudfront-and-amazon-route-53` imports two images from
  `../advanced-static-website-hosting-with-amazon-s3-and-cloudfront/`, so the asset lookup spans the
  blog tree rather than one post folder. One `<link` occurrence exists but sits _inside a fenced code
  block_, so it is article content and must survive untouched.
- **The repo already owns an MDX parser.** `@astrojs/mdx` compiles through
  `@astrojs/markdown-satteri` → `satteri`, a declared dependency; there is no `@mdx-js` in the tree.
  Whatever this change does to MDX, it can do with the same parser Astro runs on these exact files.
- **Verified during design:** `@astrojs/sitemap` already omits non-HTML endpoints — neither
  `llms.txt` nor `rss.xml` appears in the built `sitemap-0.xml`, so the twins inherit that exclusion
  with no configuration.
- **Verified during design:** the collection's `entry.body` holds the body _without_ frontmatter —
  the glob loader splits `{ body, data }` before the collection sees it. The endpoint therefore works
  from the raw file, read through an eager `import.meta.glob(…, { query: '?raw' })`, which carries
  frontmatter and body in one string and one offset space. Nothing here depends on `retainBody`.

## Goals / Non-Goals

**Goals:**

- One Markdown twin per post, derived from authored source, with no site chrome.
- A transform whose failure mode is loud (a build/test failure), not silent leakage of component
  syntax into published content.
- No drift between the endpoint, `llms.txt`, and the HTML `alternate` link — they must agree on the
  twin's URL by construction.

**Non-Goals:**

- A general-purpose MDX→Markdown converter. The transform targets the component vocabulary this blog
  actually uses, and should fail loudly rather than silently mishandle anything else.
- Byte-perfect equivalence with the rendered page. Rendered extras (reading time, hero image markup,
  syntax-highlighting spans) are presentation, not article content.

## Decisions

### Generate from MDX source, not from rendered HTML

The alternative — rendering each post to HTML and converting back to Markdown, which is what
Cloudflare's paid feature does — is a lossy round trip of content this repo already owns in its
authored form. Working from source keeps code fences, link text, and emphasis exactly as written and
avoids importing an HTML→Markdown dependency. It also means the twins stay correct if the site's
visual rendering changes.

### URL shape `/blog/<slug>/index.md`, via `src/pages/blog/[...slug].md.ts`

The llms.txt spec puts a page's Markdown twin at the page's own URL with `.md` appended or the
extension replaced — and for URLs without a filename, at `index.md` under that URL. This site's
canonical URLs have no filename: production 308-redirects `/blog/<slug>` to `/blog/<slug>/`, and the
page's own `rel="canonical"` is the trailing-slash form. So the twin sits beside the `index.html` it
mirrors, and the canonical it names is that same directory URL — there is no second URL form to
reconcile.

This needs no new route. `src/pages/blog/[...slug].md.ts` is a single endpoint file whose
`getStaticPaths()` appends `/index` to each post's id when returning the `slug` param. The rest
parameter matches slashes, so the route generator yields `/blog/<slug>/index.md`, and Astro writes
endpoints to `dirname + basename` — `dist/blog/<slug>/index.md`. It sits beside the existing
`[...slug].astro` without competing for the same route.

Rejected: `/blog/<slug>.md`. Equally spec-valid, and the shape to use if these URLs ever lose their
trailing slash, but today it would make the twin a sibling of the directory rather than of the page.

### Parse with satteri, then splice the source at node offsets

`mdxToMdast(source, { position: true })` returns a materialized mdast whose nodes carry byte offsets.
The transform walks that tree and rewrites the raw source by range: `mdxjsEsm` ranges are deleted, and
each `mdxJsxFlowElement` named `BlogPostPicture` becomes `![alt](url)`, built from attributes the
parser has already separated. Every byte outside a spliced range is copied through untouched.

This costs no new dependency, and it means the twin's idea of "what is inside a code fence" is by
construction the one that renders the site, rather than a second notion that can drift from it.

Rejected: a hand-rolled fence-aware line scanner. It has to re-implement fence tracking, buffer
multi-line elements, and tell an aliased import (`@components/picture/BlogPostPicture.astro`) from
relative image ones — three chances to be wrong about a grammar the repo can already parse exactly.

Rejected: a remark/unified pipeline. The `remark-*` and `mdast-util-*` packages in `node_modules`
arrive only through `@google/design.md`, a devDependency, so using them means promoting four packages
to real dependencies and running a second MDX parser beside satteri. `remark-stringify` also
re-serializes the whole document — bullet characters, emphasis markers, escaping, wrapping — which
defeats the goal of reproducing the article as authored.

The trade-off taken instead is a coupling to satteri's mdast API at 0.10.5, before 1.0.

### Fail loudly on unknown component syntax

The guard is a question about the tree, not a search of the text: if the walk ends with any
`mdxJsxFlowElement`, `mdxJsxTextElement`, `mdxFlowExpression`, or `mdxTextExpression` node the
transform did not handle — because a future post uses a new component — generation fails and names the
offending slug rather than publishing JSX to agents. Asking the parser what is left over is exact,
where scanning output for residual markup could only approximate it.

### Resolve image URLs through an eager asset map

Body images are referenced by identifier (`src={targetArchitecture}`), bound by an `import` to a
relative specifier — not always one inside the post's own folder. The raw text alone cannot yield the
emitted asset URL, because Astro hashes and rewrites image filenames. The endpoint therefore builds a
lookup of processed image URLs via an eager `import.meta.glob` over the blog tree's image files, and
resolves each identifier through the specifier the parser reports. Absolute URLs are produced against
the configured `site`, so the twin is self-contained when read away from the origin.

`mdxjsEsm` nodes group consecutive import lines, so one node can carry several statements: the map is
built from the statements, not from the nodes. Aliased specifiers such as
`@components/picture/BlogPostPicture.astro` are skipped — they bind components, not images.

The hero image is not part of the body — the non-goals above count it as presentation — so it stays in
frontmatter, rewritten to an absolute URL from the `heroImage` the collection schema already resolves.

### Keep the author's frontmatter, edit two fields in it

The twin's frontmatter is the post's own block, not a rebuild of it from `post.data`. `title` and
`excerpt` are free text — three titles contain `: `, one excerpt contains embedded double quotes — so
re-emitting them means owning YAML escaping for values that are already known-valid, since Astro
parses that exact block on every build. Passing them through removes the whole class of bug.

Two fields cannot pass through: `heroImage` is a repo-relative source path that resolves to nothing
for a detached reader, and `canonical` does not exist in the source at all. Both are set through
`yaml`'s document model — `parseDocument`, `set('heroImage', …)`, `set('canonical', …)`, `toString()`.

This adds `yaml` as a declared dependency, pinned at 2.9.0. It is already in the tree at that version,
deduped, arriving through Vite and `@astrojs/yaml2ts`, so declaring it costs a `package.json` line
rather than an install.

Rejected: line surgery on the raw block. Deleting and appending whole lines needs no dependency and
cannot corrupt a neighbouring value, but it is a hand-written edit to a grammar the document model
already handles. The trade accepted with `yaml` instead is that the block is round-tripped rather than
copied: scalar styles are preserved, so authored quoting survives in practice, but the guarantee is
faithfulness, not byte-identity.

### The twin opens with an H1

No post body contains an H1 — all ten top out at `##` — because the title lives in frontmatter and the
page layout renders it. A twin built from the body alone would carry a headless outline, so the
transform emits `# <title>` as the first line of the body, above the article's own prose.

### Share URL construction and the licensing notice

The twin URL is derived in one place and used by the endpoint, `llms.txt`, and the layout's
`alternate` link. The copyright/attribution sentence currently inlined in `llms.txt.ts` moves beside
it so both emit the same text. This is what keeps the three discovery surfaces from disagreeing.

### Three verification layers, not one

The failure modes differ in when they can be caught, so verification is layered:

1. **Generation-time guard**, inside the transform — fails the build when a post uses a component the
   transform has not been taught. Catches the unknown-unknown at the earliest possible moment.
2. **Post-build artifact check** — `scripts/check-markdown-twins.mjs`, run as `npm run twins:check`,
   walks every twin in `dist/`: one twin per built post page, no residual authoring syntax outside
   code fences, frontmatter that parses with a `canonical` matching its page, every image URL
   absolute _and_ present in `dist/`, no unresolved identifiers, and no twin in the sitemap. Fast, no
   browser, runs in CI's Build job beside `thirdparty:check`.
3. **Behavioural specs over HTTP** — Playwright asserts content type, both discovery entry points,
   and the fenced `<link` sample surviving verbatim.

The repo has no unit-test runner, and this change does not add one: testing here is Playwright
against a built preview server, and a new dependency for a single module is not warranted. All three
layers test the contract the spec states — what an agent receives — rather than an internal function
signature.

Layer 2 follows a precedent this repo already set. `check-third-party-resources.mjs` exists because a
CSP violation in built output is _silent_ — the page simply breaks and nothing complains. A corrupted
twin is silent in the same way, and worse: its audience is machines, so no human is ever surprised by
it. That script's three-state exit codes are adopted with it — 0 pass, 1 fail, and 2 "not verified"
when `dist/` is missing or holds nothing to scan, so a failed build cannot be reported as a passing
check.

Layer 2 is also the only place image resolution is proven end to end: layers 1 and 3 can both pass
while a twin points at an asset URL that does not exist.

### Discovery through the existing `seo` slot

`ArticleLayout` already fills `BaseLayout`'s `seo` slot, and `BaseLayout` already emits
`<link rel="alternate" type="application/rss+xml">`. The Markdown link follows that established
pattern rather than introducing a new mechanism. No CSP implications: `<link rel="alternate">` fetches
nothing.

## Risks / Trade-offs

- **A future post uses a new component, and the transform doesn't know it** → the loud-failure guard
  turns this into a build error with the offending slug named, so it is caught before publication.
- **satteri's mdast API moves before 1.0** — it is at 0.10.5, and this is the first place the repo
  touches it directly → it is already a hard dependency of every build and the Astro Markdown packages
  move as a unit, so the exposure is not new; `twins:check` and the Playwright specs turn a shape
  change into a red build rather than a corrupted twin.
- **The `yaml` round-trip renders a scalar differently from how it was authored** → the document model
  preserves scalar styles, and `twins:check` asserts every twin's frontmatter parses and carries the
  values it should. The corpus's `: `-bearing titles and quote-bearing excerpts are the cases this
  covers.
- **An exotic construct is mishandled** (component syntax indented inside a list, a four-space-indented
  code block) → the published output is asserted directly: the corpus already contains a fenced code
  sample holding `<link` markup, and a spec pins that it survives verbatim. The guard catches the rest.
- **An image identifier resolves to nothing, or to a stale asset URL** — the most fragile step, since
  it crosses from parsed text to Astro's hashed asset output → `twins:check` asserts every image URL
  is absolute and that the file it names exists in `dist/`, which is the only check in the plan that
  proves this end to end.
- **The raw-source glob stops matching** if posts are ever laid out differently under
  `src/content/blog/` → the endpoint reads the raw file rather than `entry.body`, so its coupling is to
  the file layout, not to the collection's `retainBody` option; noted here so it is visible when either
  is next touched.
- **Duplicate content concerns** → twins stay out of the sitemap (verified behaviour, not
  configuration), are not HTML, and name the canonical page in frontmatter.
- **Cloudflare's Agent Readiness check stays red** → accepted and documented; this is the deliberate
  outcome of the decision in `proposal.md`, not an unfinished task.
- **Twins can go stale relative to a post** only if generation is bypassed; they are built from the
  same source on every build, so this cannot drift independently.

## Migration Plan

Purely additive: new URLs, two modified files, no data migration and no change to existing routes.
Deploy is the normal Pages build. Rollback is deleting the endpoint and reverting the `llms.txt` and
`ArticleLayout` edits; nothing external depends on the twins, and no existing URL changes, so
rollback carries no reader-visible consequence.

## Open Questions

- Whether the twin's frontmatter should also carry reading time (available via
  `remarkPluginFrontmatter.minutesRead`). Deferrable: it adds a metadata field without affecting the
  specs, the approach, or the task breakdown.
