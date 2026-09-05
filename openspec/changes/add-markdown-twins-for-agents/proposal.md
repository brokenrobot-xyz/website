## Why

Cloudflare's Agent Readiness report flags the site for not serving "AI-optimized text formats".
Investigating the recommendation showed the check is narrower — and more self-serving — than it
looks:

- It scores exactly one behaviour: whether the origin does content negotiation on
  `Accept: text/markdown`.
- It **explicitly ignores `llms.txt`** ("we only check whether the site correctly handles Markdown
  content negotiation, and do not check for llms.txt"), which this site already serves.
- Cloudflare's turnkey remedy, "Markdown for Agents", is available only on Pro, Business and
  Enterprise — roughly $25/month per domain — while this zone is on Free. The report's own
  remediation button links to that upgrade.

Paying to satisfy a vendor's scorecard is poor value for a ten-post personal blog, and the vendor
feature would serve agents a lossy HTML→Markdown re-derivation of Markdown this repo already owns.
The underlying goal is still legitimate, though: agents parse Markdown more cheaply and more
reliably than rendered HTML. So this change pursues the goal directly, from source, at no cost and
with no vendor coupling — and accepts that Cloudflare's check stays red.

## What Changes

- Add a static endpoint emitting a Markdown twin at `/blog/<slug>/index.md` for every blog post,
  generated from the post's real MDX source rather than from rendered HTML.
- Add a source-to-Markdown transform that strips `import` lines, rewrites
  `<BlogPostPicture src={ident} alt="..." />` into a standard Markdown image with an absolute image
  URL, and is fenced-code-aware so code samples in articles are never rewritten.
- Give each twin YAML frontmatter (`title`, `excerpt`, `publishDate`, `tags`, `canonical`) and the
  same copyright/attribution line `llms.txt` already carries, so licensing terms travel with the
  file.
- Advertise each twin from its HTML page via
  `<link rel="alternate" type="text/markdown" href="/blog/<slug>/index.md">`, alongside the existing RSS
  `alternate` link.
- Extend `/llms.txt` so every post entry also points at its `.md` twin.
- Add a build-output guardrail — `npm run twins:check` — that validates every generated twin in
  `dist/` and joins the CI gate beside the existing third-party-resource check. Twin corruption is
  silent in exactly the way CSP breakage is: agents receive broken content and no human ever opens
  the file.
- Record in the docs that the Cloudflare Agent Readiness "Content" check is knowingly left red, and
  why, so the decision is not re-litigated at every dashboard scan.

No breaking changes: `/blog/<slug>/` permalinks, `rss.xml`, and the sitemap are untouched, and
`/blog/<slug>` keeps redirecting to the trailing-slash form as it does today. Each twin is a new file
inside the post's existing directory, beside the `index.html` it mirrors; only `index.html` carries
special meaning to the host, so nothing is shadowed.

## Non-Goals

- **Not** enabling Cloudflare "Markdown for Agents" or upgrading the zone off the Free plan.
- **Not** implementing `Accept: text/markdown` content negotiation. Doing so would require zone
  Transform Rules or a Pages Function, pushing request-time behaviour into a site whose enduring
  principle is static-by-design. Consequence, accepted deliberately: the Cloudflare check stays red.
- **Not** adding `llms-full.txt`. The per-post twins plus `llms.txt` already give agents discovery
  and full text; an aggregate would duplicate every article into a second file that must stay in
  sync.
- **Not** adding twins for Home, About, or the blog index. About is hand-authored Astro markup with
  no Markdown source, so a twin would duplicate prose and drift; Home and the blog index are link
  lists `llms.txt` already describes.
- **Not** emitting a `Link:` HTTP header for discovery — that would add a second, competing place
  where response headers are defined, next to the existing zone rulesets.
- **Not** authoring or editing article prose.
- **Not** changing the CSP, adding dependencies, or adding third-party resources.

## Capabilities

### New Capabilities

- `agent-content`: how the site exposes its content in machine-readable form for AI agents and other
  non-browser clients — the Markdown representation of blog posts, the frontmatter and licensing
  metadata those representations carry, and how agents discover them from the HTML pages and from
  the `llms.txt` index.

### Modified Capabilities

None. The existing capabilities (`brand-mascot`, `site-chrome`, `theming`, `typography`) cover
visual and chrome behaviour; none describes machine-readable content, and none changes here.

## Impact

**New code**

- `src/pages/blog/[...slug].md.ts` — static endpoint, one twin per post, following the existing
  `src/pages/llms.txt.ts` endpoint style.
- A transform module under `src/utils/` converting MDX source to agent-facing Markdown, using the
  `satteri` parser Astro already compiles these posts with.
- `scripts/check-markdown-twins.mjs` — post-build validation of every twin, modelled on the existing
  `scripts/check-third-party-resources.mjs`.

**Modified code**

- `src/pages/llms.txt.ts` — post entries gain their `.md` twin URL.
- `src/layouts/ArticleLayout.astro` — adds the `alternate` link via the existing `seo` slot.
- `package.json` — adds the `twins:check` script and `yaml` 2.9.0 as a dependency, used to edit each
  post's own frontmatter block rather than re-serializing it. It is already in the tree at that
  version, deduped via Vite and `@astrojs/yaml2ts`, so this declares what is installed rather than
  adding an install.
- `.github/workflows/pipeline.yml` — runs `twins:check` in the Build job, after `thirdparty:check`.
- The `running-preflight-checks` skill — only its frontmatter `description`, which names the checks
  in prose. Its body needs no change: it reads the gate from checks.md.

**Docs**

- `docs/development/checks.md` — registers `twins:check`: its own section under **Build output
  (`dist/`)**, the command in the preflight-gate block, and the check in the CI pipeline's **Build
  site** row. This page is the only place the checks are listed, so nothing else grows a copy.
- A short note recording the deliberate red Cloudflare check and the reasoning behind it.

**Build & verification**

- Output grows by ten `.md` files; no new dependencies and no CSP change, so
  `npm run thirdparty:check` is unaffected.
- The added `<link>` is a `<head>` element with no rendered output, so Playwright visual baselines
  and axe accessibility results are expected to be unchanged.
