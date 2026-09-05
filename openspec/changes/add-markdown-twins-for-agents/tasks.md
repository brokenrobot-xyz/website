## 1. Source-to-Markdown transform

- [ ] 1.1 Add a transform module under `src/utils/` that parses a post's raw MDX with satteri's
      `mdxToMdast(source, { position: true })` and rewrites the source by splicing at node offsets:
      `mdxjsEsm` ranges are deleted, each `mdxJsxFlowElement` named `BlogPostPicture` is replaced with
      `![alt](url)` built from its parsed `attributes`, and everything outside a spliced range is
      copied through untouched. Splice the JavaScript string, not a `Buffer`: the offsets index the
      string, so a byte-based reading drifts on the posts carrying emoji and typographic quotes.
      Verify `npm run type:check` and `npm run lint:check` pass, and that a transformed post keeps its
      fenced code samples character-for-character.
- [ ] 1.2 Build the identifier → specifier map from the import statements the `mdxjsEsm` nodes carry —
      the parser groups consecutive imports, so one node can hold several — keeping relative
      specifiers and skipping aliased ones such as `@components/picture/BlogPostPicture.astro`. Verify
      the map for `advanced-static-website-hosting-with-amazon-s3-and-cloudfront` resolves all five of
      its image identifiers, and that `url-redirect-with-amazon-cloudfront-and-amazon-route-53`, whose
      images live in another post's directory, resolves its three too.
- [ ] 1.3 Add the loud-failure guard, covering both content faults: if the walk ends with any
      `mdxJsxFlowElement`, `mdxJsxTextElement`, `mdxFlowExpression`, or `mdxTextExpression` node the
      transform did not handle, or if an image identifier resolves to no asset, fail with the
      offending post slug rather than emitting it. Verify by temporarily adding an unknown component
      to a post body that `npm run build` fails and names that slug, then by pointing an image
      identifier at a missing file and seeing the same, then reverting both.

## 2. Twin endpoint

- [ ] 2.1 Create `src/pages/blog/[...slug].md.ts` as a static endpoint with `getStaticPaths()` over
      the `blog` collection, in the style of the existing `src/pages/llms.txt.ts`. Append `/index` to
      each post's id when returning the `slug` param, so the rest parameter — which matches slashes —
      yields `/blog/<slug>/index.md` from this one endpoint file, with no nested route. Read each
      post's raw source through an eager `import.meta.glob(…, { query: '?raw' })` rather than
      `entry.body`, which the loader has already stripped of frontmatter. Set
      `Content-Type: text/markdown; charset=utf-8` on the `Response` for the dev server's benefit, and
      note in a comment that a prerendered endpoint writes only its body, so the served type comes
      from the platform, not from here. Verify `npm run build` emits `dist/blog/<slug>/index.md` for
      all ten posts, beside each post's existing `index.html`.
- [ ] 2.2 Build the processed-image lookup with an eager `import.meta.glob` over the blog tree's image
      files and resolve each body image to an absolute URL against the configured `site`. Verify the
      four image-bearing posts' twins contain `![alt](https://www.brokenrobot.xyz/...)` and no
      unresolved `{identifier}` placeholders.
- [ ] 2.3 Add `yaml` (2.9.0, exact-pinned) as a dependency and emit the twin's frontmatter from the
      post's own block: `parseDocument`, then `set('heroImage', …)` to the built asset's absolute URL
      and `set('canonical', …)` to the post's page URL — the trailing-slash directory URL the page's
      own `rel="canonical"` already declares, which is the directory the twin sits in. Verify a built
      twin carries every authored field with its original quoting — including a `: `-bearing title and
      the excerpt containing double quotes — plus the rewritten `heroImage` and the new `canonical`.
- [ ] 2.4 Assemble the body: `# <title>` as its first line, then the transformed prose, then the
      shared copyright/attribution line. Verify a built twin opens with an H1 matching that post's
      title and that no post's own headings were demoted or renumbered.

## 3. Discovery

- [ ] 3.1 Extract twin-URL construction and the copyright/attribution sentence into one shared
      module, and have the endpoint use it. Verify `npm run type:check` passes and the sentence is no
      longer duplicated between the endpoint and `llms.txt.ts`.
- [ ] 3.2 Extend `src/pages/llms.txt.ts` so each post entry also lists its `.md` twin URL, using the
      shared construction. Verify `dist/llms.txt` lists ten `.md` URLs and still carries its summary,
      Pages section, licensing note, and RSS/sitemap references.
- [ ] 3.3 Add `<link rel="alternate" type="text/markdown" href="...">` to `ArticleLayout`'s `seo`
      slot, alongside the existing RSS alternate link. The layout receives only the post's
      frontmatter today, so pass the post's id to it from `src/pages/blog/[...slug].astro` and widen
      its `Props`. Verify a built post's HTML contains the link with that post's correct twin URL.

## 4. Published-output coverage

- [ ] 4.1 Add a Playwright spec that, for every post, requests `/blog/<slug>/index.md` and asserts a
      200 response, frontmatter present, a `# ` H1 as the body's first line, and no `import ` line or
      `<BlogPostPicture` anywhere in the body. The content type is deliberately not asserted: the
      preview server's MIME table is not any deployment target's, and the served type belongs to the
      follow-up work on platform parity.
- [ ] 4.2 Extend that spec to pin the fenced code sample in
      `url-redirect-with-amazon-cloudfront-and-amazon-route-53` — which contains `<link` markup —
      appearing verbatim in the twin, proving code samples are never rewritten.
- [ ] 4.3 Assert discovery from both entry points: a post's HTML page exposes its `alternate`
      Markdown link, and `/llms.txt` lists that post's `.md` URL.
- [ ] 4.4 Assert the twins stay out of `dist/sitemap-0.xml`, pinning the sitemap exclusion the design
      relies on so a future integration change cannot silently start indexing them.

## 5. Build-output audit

- [ ] 5.1 Create `scripts/check-markdown-twins.mjs` following `scripts/check-third-party-resources.mjs`
      — same argument shape, same header comment style, and the same three-state exit codes. It
      audits coverage, not content: a twin beside every built post page and no orphans, each twin
      non-empty, each opening with a frontmatter block that parses. Verify it passes on a clean build,
      exits 2 with a "not verified" message against a missing or empty `dist/`, and exits 1 naming the
      post when a twin is deleted from `dist/` and again when one is emptied.
- [ ] 5.2 Add the `twins:check` npm script and run it in the pipeline's Build job immediately after
      `thirdparty:check`. Verify `npm run twins:check` passes after `npm run build`, and that the
      Build job runs it.
- [ ] 5.3 Exclude `.md` from `scripts/check-third-party-resources.mjs`, with a comment recording why:
      a Markdown file is data an agent reads, not a document a browser parses into requests, so
      nothing in one can produce a fetch. Verify `npm run thirdparty:check` passes after a build that
      includes the twins — without the exclusion it fails on the `<link href="https://…">` sample in
      `url-redirect-with-amazon-cloudfront-and-amazon-route-53` — and still fails when a genuine
      third-party resource is introduced into an HTML page.
- [ ] 5.4 Register `twins:check` in `docs/development/checks.md` — its own section under **Build
      output (`dist/`)** documenting what it audits and what its exit codes mean, plus the command in
      the preflight-gate block and the check in the CI pipeline's **Build site** row — and name it in
      the `running-preflight-checks` skill's frontmatter `description`. Record the `.md` exclusion in
      the existing `thirdparty:check` section. Verify checks.md remains the only list: nothing else
      enumerates the checks, and the skill body, `docs/tooling/workflow.md`, and the tasks template
      still link to it rather than repeating it.

## 6. Documentation

- [ ] 6.1 Add a short note to `docs/tech-stack.md` under **Build & deployment**, beside the existing
      RSS and sitemap discoverability claims, recording that Cloudflare's Agent Readiness "Content"
      check is knowingly left red — the check scores only `Accept: text/markdown` negotiation, the
      native feature is Pro-plan only, and this site serves twins generated from source instead.
      Verify the note names the trade-off clearly enough that the decision does not need re-deriving
      at the next dashboard scan.

## 7. Verify

- [ ] Visual + a11y snapshots pass in **both themes** for every touched view (testing-visual-regression skill)
- [ ] All preflight gate checks pass — the set in `docs/development/checks.md` (running-preflight-checks skill)
- [ ] Manual preview: no theme flash, interactions work, console clean, responsive at 375px
