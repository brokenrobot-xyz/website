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

`mdxToMdast(source, { position: true })` returns a materialized mdast whose nodes carry `position`
offsets. Those offsets index the JavaScript string, not the UTF-8 bytes: `source.slice(start, end)`
returns the node verbatim, while the same numbers applied to a `Buffer` drift by one position per
multi-byte character — and several posts carry emoji and typographic quotes, so a byte-based reading
would corrupt exactly those. The transform therefore splices the source string by range: `mdxjsEsm`
ranges are deleted, and each `mdxJsxFlowElement` named `BlogPostPicture` becomes `![alt](url)`, built
from attributes the parser has already separated. Everything outside a spliced range is copied
through untouched.

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

### Fail loudly on unknown component syntax, and on an image that does not resolve

The guard is a question about the tree, not a search of the text: if the walk ends with any
`mdxJsxFlowElement`, `mdxJsxTextElement`, `mdxFlowExpression`, or `mdxTextExpression` node the
transform did not handle — because a future post uses a new component — generation fails and names the
offending slug rather than publishing JSX to agents. Asking the parser what is left over is exact,
where scanning output for residual markup could only approximate it.

The same guard covers the image lookup below: an identifier that resolves to no asset fails
generation rather than emitting an empty or literal `{identifier}` target. This is the transform's
job rather than a post-build scan's, because here the failure is still attached to a post and an
identifier; downstream it is only a URL that looks wrong.

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
The spec requires it there, and requires it absolute, so it survives being read away from the origin.

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

### Three verification layers, each answering a different question

The layers are not three depths of the same check. Each answers a question the others cannot:

1. **Is the content right?** The generation-time guard, inside the transform. A post using an
   untaught component, or an image identifier that resolves to nothing, fails the build and names
   the post. Content faults belong here and nowhere else: this is the only point where the failure
   is still attached to a source file rather than to a line of output.
2. **Did the build produce the artifact?** `scripts/check-markdown-twins.mjs`, run as
   `npm run twins:check` in CI's Build job beside `thirdparty:check`. It is an auditor, not a
   content check: a twin beside every built post page and no orphans, each one non-empty, each one
   opening with frontmatter that parses. It runs where the artifact is made, so it fails before the
   Playwright job is even reached, and it needs no browser.
3. **Does the served site behave?** Playwright over HTTP — both discovery entry points and the fenced
   `<link` sample surviving verbatim.

The repo has no unit-test runner, and this change does not add one: testing here is Playwright
against a built preview server, and a new dependency for a single module is not warranted.

Layer 2's scope is deliberately narrow. Twins and pages are generated from one source on every build,
so they cannot drift apart — the failure worth auditing is not a wrong twin but a missing or empty
one, which is a real failure mode in the wild: sites serving `.md` that return 200 with no body,
where nothing looks broken to anyone. Its three-state exit codes follow
`check-third-party-resources.mjs` — 0 pass, 1 fail, and 2 "not verified" when `dist/` is missing or
holds nothing to scan, so a failed build cannot be reported as a passing check.

What no layer here asserts is the content type. That is not the artifact's property but the serving
layer's, it differs between local and production, and it is the follow-up work's to settle. A
Playwright assertion would have proved only the preview server's MIME table.

### Markdown is out of the third-party check's remit

`check-third-party-resources.mjs` scans every non-binary file in `dist/`, and one post's fenced code
sample is a `<link rel="canonical" href="https://www.my-website.com/…">` snippet. The HTML page
escapes it, so the check has never seen it; the twin carries it raw, and the check would report a
third-party resource request and fail the Build job.

The fix is to skip `.md`, not to special-case the sample. That check exists because a resource a
browser fetches from a third party is a page the site's own CSP silently breaks. A Markdown file is
data an agent reads, not a document a browser parses into requests, so nothing inside one can
produce a fetch — it is outside what the check is for, and narrowing it says so.

### Discovery through the existing `seo` slot

`ArticleLayout` already fills `BaseLayout`'s `seo` slot, and `BaseLayout` already emits
`<link rel="alternate" type="application/rss+xml">`. The Markdown link follows that established
pattern rather than introducing a new mechanism. No CSP implications: a `<link>` with these relations
fetches nothing.

Two relations go in, because the llms.txt spec recommends them as a pair: `alternate` with
`type="text/markdown"` names this page's twin, and `describedby` names the index that covers the
page. `describedby` is a registered IANA relation, defined by POWDER as "a resource providing
information about the link's context"; pointing it at `llms.txt` is the llms.txt proposal's
convention rather than a web standard. Nothing in a browser consumes either one, so the payoff is
confined to agents that already know the convention — which is the audience the twins exist for.

### The index links the Markdown, not the page

The llms.txt spec states that the links in an llms.txt file should point to LLM-friendly content,
because an agent is expected to search the index and then follow its links. Listing both URLs per
post would double every line to carry one that is derivable: each twin names its own `canonical`, so
an agent that needs the human page is one hop away. Home, About, and the blog index keep their page
links — they have no twin, and the rule only reaches as far as content that has one.

This also settles the URL form. The current entries link `/blog/<slug>`, which production redirects
to `/blog/<slug>/`; a twin URL is an exact file path, so no redirect is involved.

## Risks / Trade-offs

- **A future post uses a new component, and the transform doesn't know it** → the loud-failure guard
  turns this into a build error with the offending slug named, so it is caught before publication.
- **satteri's mdast API moves before 1.0** — it is at 0.10.5, and this is the first place the repo
  touches it directly → it is already a hard dependency of every build and the Astro Markdown packages
  move as a unit, so the exposure is not new; `twins:check` and the Playwright specs turn a shape
  change into a red build rather than a corrupted twin.
- **The `yaml` round-trip renders a scalar differently from how it was authored** → the document model
  preserves scalar styles, and `twins:check` asserts every twin's frontmatter still parses. The
  corpus's `: `-bearing titles and quote-bearing excerpts are the cases this covers.
- **An exotic construct is mishandled** (component syntax indented inside a list, a four-space-indented
  code block) → the published output is asserted directly: the corpus already contains a fenced code
  sample holding `<link` markup, and a spec pins that it survives verbatim. The guard catches the rest.
- **An image identifier resolves to nothing** — the most fragile step, since it crosses from parsed
  text to Astro's hashed asset output → the generation-time guard fails the build and names the post
  and the identifier. A stale URL is a narrower worry than it first appears: the twin and the page
  read the same `ImageMetadata`, so an asset URL that is wrong in the twin is wrong on the page too,
  where the visual suite already fails.
- **The raw-source glob stops matching** if posts are ever laid out differently under
  `src/content/blog/` → the endpoint reads the raw file rather than `entry.body`, so its coupling is to
  the file layout, not to the collection's `retainBody` option; noted here so it is visible when either
  is next touched.
- **Duplicate content concerns** → twins stay out of the sitemap (verified behaviour, not
  configuration) and are not HTML. The `canonical` in frontmatter states the relationship for a human
  or an agent reading the file; it is not a signal any crawler consumes, so the sitemap exclusion is
  what actually carries this.
- **Cloudflare's Agent Readiness check stays red** → accepted and documented; this is the deliberate
  outcome of the decision in `proposal.md`, not an unfinished task.
- **Twins can go stale relative to a post** only if generation is bypassed; they are built from the
  same source on every build, so this cannot drift independently.

## Migration Plan

Purely additive: new URLs, no data migration and no change to existing routes. Deploy is the normal
Pages build. Rollback is deleting the endpoint and reverting the `llms.txt`, layout, and check-script
edits; nothing external depends on the twins, and no existing URL changes, so rollback carries no
reader-visible consequence.

## Open Questions

None. Two were settled while planning: the twin's frontmatter does not carry reading time — it is a
rendering convenience, not article metadata — and the content type the twins are served with is out
of scope here, belonging to the follow-up work on platform parity.
