# Architecture & conventions

How the codebase is organized today, and the architectural guidance for the overhaul
(especially theming). Descriptive sections reflect the current repo.

## Directory layout

```
src/
  components/      Reusable Astro components, grouped by feature
    blog-posts/    BlogPosts, CompactBlogPosts, ReadingTime, PublishDate
    layout/        Header, Footer
    links/         InternalLink, ExternalLink
    picture/       BlogPostPicture
    seo/           meta-og/, meta-twitter/, rich-results/ (JSON-LD)
  content/blog/    One folder per post: index.mdx + collocated images
  layouts/         BaseLayout, PageLayout, ArticleLayout
  pages/           File-based routes
  styles/          base.css (global styles, tokens)
  utils/           readingTimePlugin.ts, codeBlockFocusPlugin.ts (Sätteri plugins)
  consts.ts        Centralized site metadata
  content.config.ts Content collection schema
public/            Static assets (favicon, robots.txt)
tests/             Playwright specs + visual snapshots
infra/             Terraform (Cloudflare) + Kubernetes
```

**Path aliases** (`tsconfig.json`): `@assets/*`, `@components/*`, `@layouts/*`, `@styles/*`.
Prefer these over deep relative imports.

## Layouts

A three-level hierarchy:

- **`BaseLayout.astro`** — HTML root: `<head>`, global styles, `Header`, `Footer`, the
  `<html>` element (currently `class="scheme-light"`), and the `prose` wrapper for content.
- **`PageLayout.astro`** — extends Base; SEO metadata for standalone pages.
- **`ArticleLayout.astro`** — extends Base; article-specific SEO and structure for blog posts.

## Routing

File-based (Astro standard):

- `pages/index.astro` — homepage (recent posts).
- `pages/blog/index.astro` — blog listing.
- `pages/blog/[...slug].astro` — dynamic post route via `getStaticPaths()`. **These
  `/blog/<slug>/` permalinks must remain stable** (see [vision](vision.md)).
- `pages/about/index.astro`, `pages/404/index.astro`.
- `pages/rss.xml.ts` — RSS feed. Must keep working.

## Content model

Defined in `src/content.config.ts` via a `glob` loader (`**/[^_]*.{md,mdx}`) and a Zod schema:

| Field         | Type                      | Notes                                 |
| ------------- | ------------------------- | ------------------------------------- |
| `title`       | `string`                  |                                       |
| `excerpt`     | `string`                  | Summary / meta description            |
| `publishDate` | `string \| date` → `Date` | Transformed to `Date`                 |
| `heroImage`   | `image()`                 | Astro-optimized; collocated with post |
| `tags`        | `string[]`                |                                       |

Posts live at `src/content/blog/<slug>/index.mdx` with images in the same folder.

Markdown and MDX are rendered by **Sätteri**, Astro's native pipeline and the default since
Astro 7 (the remark/rehype pipeline is now opt-in via `@astrojs/markdown-remark`). Two Sätteri
plugins are wired through `markdown.processor` in `astro.config.ts`:

- `readingTimePlugin` (`src/utils/`) — an mdast plugin that injects `minutesRead` into
  frontmatter, consumed by the `ReadingTime` component. Sätteri visits nodes by type and has no
  document-level hook, so it accumulates text in the per-document data bag and rewrites the
  frontmatter on each visit; the value is read only once the document has finished compiling.
- `codeBlockFocusPlugin` (`src/utils/`) — a hast plugin adding `tabindex="0"` to `<pre>`, so
  horizontally scrollable code blocks stay keyboard-reachable (axe:
  `scrollable-region-focusable`). Shiki used to emit this attribute itself; Prism does not.

## Conventions

- **Component organization:** group by feature in subfolders (`seo/`, `blog-posts/`,
  `links/`, `layout/`, `mascot/`, `theme/`). PascalCase component files.
- **Interactivity: Preact islands for stateful UI, Astro scripts for simple DOM wiring.**
  Non-interactive UI is plain Astro (zero JS). For stateful widgets, add a Preact component
  (`.tsx`) and mount it `client:*` (page phase: search, mobile menu, code-copy). For small
  behavior, prefer a bundled Astro `<script>` importing a `.ts` module — e.g. the theme toggle
  (`ThemeToggle.astro` + `theme-toggle.ts`). Keep client JS small; it loads from `self`
  (CSP-friendly).
- **SEO / structured data:** OpenGraph (`meta-og/`), Twitter cards (`meta-twitter/`), and
  JSON-LD (`rich-results/`, typed with `schema-dts`). Fonts use the native Astro Fonts
  API (`fonts` in `astro.config.ts`), resolved offline from the installed
  `@fontsource/*` packages via the `local` provider (`fontProviders.local()`) and emitted via
  `<Font>` in `BaseLayout` (`@font-face` + preload generated at build).
- **Links:** use `InternalLink` / `ExternalLink` rather than raw `<a>`.
- **Site metadata:** centralized in `src/consts.ts` (`SITE_METADATA`) — title, description,
  author, socials, image breakpoints. Add new global constants here.

## Theming architecture

The light/dark system, as implemented in the foundation:

- **Design tokens as CSS custom properties** in `src/styles/base.css` under `@layer base`:
  light values on `:root`, dark overrides on `html[data-theme="dark"]`. They express the
  semantic roles from [brand](brand.md) (`--bg`, `--surface`, `--surface-2`, `--text`,
  `--muted`, `--border`, `--accent`, `--accent-ink`, code colors, shadows, `--ff-*`).
  The **colour token values** are the source of truth in `DESIGN.md` / `DESIGN.dark.md` and are
  generated into `src/styles/tokens.generated.css` (imported by `base.css`) by
  `npm run tokens:generate`; shadows, `--ff-*`, and `color-mix` derivations stay hand-authored in
  `base.css`. See [design-md-assessment](design-md-assessment.md).
- **Tokens exposed to Tailwind** via `@theme inline` (e.g. `--color-bg: var(--bg)`), so
  utilities like `bg-bg`/`text-muted` and the `prose` mapping (`--tw-prose-*`) follow the
  theme.
- **Theme selection on `<html>`** via the `data-theme` attribute. A tiny **inline script** in
  `BaseLayout`'s `<head>` (passed as a string via `set:html`) resolves the theme before paint
  (localStorage → `prefers-color-scheme` → light) to avoid a flash. It is CSP-safe because
  `BaseLayout` registers its SHA-256 hash into the page's policy via
  `Astro.csp.insertScriptHash()` (Astro only hashes scripts it processes itself, never
  author-written `is:inline` scripts) — not because inline scripts are allowed; they are not
  (see [Content-Security-Policy](#content-security-policy)). It uses no inline `on*` handlers,
  which the policy blocks outright.
- **The toggle is a bundled Astro client-side script** (`ThemeToggle.astro` importing
  `theme-toggle.ts`): the correct sun/moon icon is chosen by CSS from `html[data-theme]` (so
  it's right on the first frame — no flash), and the script only wires the click (flip
  `data-theme`, persist, update `aria-pressed`). It is deliberately **not** a Preact island —
  an island renders before it knows the theme, which flashes the wrong icon on load.
- **Both themes are first-class** — every component, the mascot, and `prose` article styling
  must read well in light and dark (see [coding-conventions](development/conventions/coding-conventions.md) for
  snapshot coverage).

> **View Transitions caveat (future).** This works because every navigation is a full page
> load, so both the inline init and the toggle's bundled script re-run per page. If we ever
> adopt View Transitions (`<ClientRouter />`), bundled module scripts run only once and are
> **not** re-executed on client-side navigation — so the toggle's click listener would need
> re-binding via `astro:page-load`, and the theme should be re-applied in an `astro:after-swap`
> listener to avoid a flash on navigation. See the
> [Astro view-transitions docs](https://docs.astro.build/en/guides/view-transitions/#script-behavior-with-view-transitions).

## Content-Security-Policy

The policy is delivered in **two layers**, and browsers enforce both — a resource must satisfy
each one.

1. **A `<meta>` policy in every page**, generated by `security.csp` in `astro.config.ts`. This is
   the strict layer: `script-src`/`style-src` carry SHA-256 content hashes of the page's scripts
   and styles and **no `unsafe-inline`**, so an injected inline script does not run. Because the
   hashes are per-page and follow the content, only the build can produce this layer — and
   because it lives in the HTML, it travels unchanged to any host.
2. **An edge header**, defined in three places that must stay byte-identical: the
   `Content-Security-Policy` header in `infra/cloudflare/modules/domain/main.tf` (Cloudflare —
   production), `nginx.conf` (Kubernetes), and `server.headers` in `astro.config.ts` (what
   `astro preview`, and therefore the Playwright suite, serves). This layer carries what a
   `<meta>` element cannot express — `frame-ancestors` — and additionally covers non-HTML
   responses and host-generated error pages, starting from the first byte rather than from the
   meta tag.

    A third copy is a third chance to drift, and the drift is quiet: the site keeps rendering
    because the inline CSS survives, while fonts and every bundled script fail. When the
    Cloudflare stack was first stood up it carried a single-layer policy copied from another
    site, which intersected with the `<meta>` layer to block `font-src` outright and admit no
    script at all. Check all three when changing any.

The header keeps `'unsafe-inline'` on `script-src`/`style-src` **deliberately**: a static header
cannot carry per-page hashes, so without it this layer would block the very inline scripts the
`<meta>` layer has already vetted. It is the permissive half of an intersection, so it does not
weaken the strict half. Do not "tidy" it away.

Two consequences worth knowing:

- **Syntax highlighting must not use inline styles.** Shiki colours tokens with `style`
  attributes, which a hash-based policy cannot admit; the site uses **Prism**, which colours by
  class (see the `--syntax-*` tokens in `DESIGN.md`). This is also what lets the header set
  `style-src-attr 'none'`.
- **A `<meta>` policy only governs what the parser reaches after it.** Anything earlier in
  `<head>` is covered by the header alone — notably the theme-init script, which sits first in
  `<head>`: its hash is registered in the `<meta>` policy (keeping that policy complete), but at
  parse time only the header's `'unsafe-inline'` admits it. Closing that window would require
  emitting the union of all page hashes into the edge config at build time; we have not done
  that.

Astro's CSP does not work in `dev` (the Vite dev server injects its own inline assets) — verify
with `npm run build` and `npm run serve`.

### The one third-party script

`script-src` names exactly one external host, `https://static.cloudflareinsights.com`, in **both**
layers: the Cloudflare Web Analytics beacon, injected at the edge by `auto_install` on
`cloudflare_web_analytics_site`. Three things about it are easy to get wrong:

- **`npm run thirdparty:check` cannot see it.** The guardrail scans `dist/`, and the beacon is
  added by the edge after the build, so `scriptDirective.resources` in `astro.config.ts` is the
  only place this dependency is written down. Nothing fails if it is removed — analytics just
  goes quiet.
- **The host is named without a path.** The beacon is served from a versioned URL,
  `/beacon.min.js/v<id>`. A CSP source whose path does not end in `/` must match exactly, so
  naming the file would block every version of it.
- **`connect-src` needs nothing.** Because the beacon is auto-installed rather than embedded, it
  reports to the same-origin `/cdn-cgi/rum`, which `connect-src 'self'` already covers. A
  manually embedded beacon would post to `cloudflareinsights.com` instead and would need that
  host added.

Astro's `scriptDirective.resources` **replaces** its default sources rather than extending them,
so `'self'` is repeated in that list. Dropping it there would block every bundled script on the
site while leaving the beacon working — a confusing failure worth recognizing.
