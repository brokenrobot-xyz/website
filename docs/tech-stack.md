# Technology stack

[`package.json`](../package.json) is the authoritative source for exact dependencies,
versions, and script commands — this document does not duplicate it. Instead it captures what
that file can't: the _shape_ of the stack, why it looks the way it does, and how it shapes the
design overhaul.

## Shape of the stack

- **Astro** is the foundation — a static-site generator. Pages are Astro components rendered
  to static HTML at build time, shipping zero JS by default.
- **Preact** (via `@astrojs/preact`) is the standard for **stateful** interactive UI, added as
  hydrated **islands** (`client:*`) to minimize hand-written vanilla JS (planned for interactive
  features like search, a mobile menu, and code-copy). Non-interactive pages ship no JS. Simple DOM wiring
  (like the theme toggle) uses a bundled Astro `<script>` instead of an island, and the
  pre-paint theme-init is a tiny inline script (see below).
- **Content is Markdown/MDX**, authored as one folder per post under `src/content/blog/` and
  loaded through Astro's content collections (see [architecture](architecture.md)). Rendering
  goes through **Sätteri**, Astro's native pipeline and the default since Astro 7; a small
  Sätteri plugin adds reading-time to each post.
- **Code blocks are highlighted with Prism**, not Shiki, because Prism colours tokens with CSS
  classes rather than inline `style` attributes — a hash-based CSP cannot admit the latter (see
  [architecture](architecture.md)).
- **Styling is Tailwind CSS** (via the `@tailwindcss/vite` plugin) plus the typography plugin
  for long-form `prose`. There is no PostCSS step.
- **TypeScript runs in the strictest mode** — the type system is a first-class guardrail (see
  [coding-conventions](development/conventions/coding-conventions.md)).
- **Fonts are self-hosted** (Space Grotesk for display/UI, Newsreader for article prose, Space
  Mono for code/labels), not pulled from a third-party CDN.
- **Discoverability is built in:** an RSS feed and an XML sitemap are generated at build time,
  and structured data (JSON-LD) is typed.
- **Quality is automated:** ESLint + Prettier for static analysis and formatting; Playwright
  for end-to-end (e2e) and visual-regression tests, with axe-core for accessibility checks.
- **npm is the package manager**, configured for reproducibility (exact version pinning,
  engine-strict, committed lockfile).

## Build & deployment

- `astro build` produces a fully **static** `dist/`. HTML is compressed, stylesheets are
  **always inlined**, and images use responsive styles (see `astro.config.ts`).
- **CI/CD** runs in GitHub Actions (`.github/workflows/pipeline.yml`): a `verify` →
  `build` → `test` sequence (format, lint, type-check, OpenSpec validation, then build, then
  Playwright), followed by deployment from `main`.
- **Dual-cloud delivery:** the built site is published to both **AWS** (S3 sync + CloudFront
  invalidation) and **Cloudflare Pages**, on every merge to `main`. The deploy jobs target the
  `Production` and `Cloudflare` GitHub Environments; the release gate — a required approval on those
  environments — is intended but **not yet configured** (see [development-workflow](development-workflow.md)).

## Infrastructure & tooling

- **Infrastructure as code:** Terraform under `infra/` (AWS, Cloudflare) plus Kubernetes
  manifests. CI also runs `terraform fmt`/`validate`.
- **Container:** a `Dockerfile` serves `dist/` via unprivileged Nginx.
- **Dev container:** a reproducible environment with Node and Terraform pre-installed.

## Implications for the overhaul

- **Interactivity loads from `self`.** Both Preact islands and bundled Astro `<script>`s ship
  as external modules under `script-src 'self'` (no inline handlers). Stateful UI → Preact
  island; simple DOM wiring → an Astro `<script>` importing a `.ts` module (the theme toggle).
- **Theme set before paint by one inline script.** The pre-paint theme resolution (read
  preference → set `data-theme`) cannot be deferred to a module/island — it would flash. It
  stays a tiny inline script, CSP-safe because Astro emits a hash for it — inline scripts are
  **not** blanket-allowed — and it uses no inline `on*` handlers. The toggle's icon is then
  chosen by CSS from `data-theme`, so it's correct on the first frame. See
  [architecture](architecture.md).
- **Fonts stay self-hosted** (`font-src 'self'`, no third-party font CDNs), with preloading and
  `font-display: swap`; only the weights actually used are shipped.
- **Stylesheets are inlined**, so keep CSS lean; design tokens belong in `src/styles/base.css`
  (colour token values are generated from `DESIGN.md` — see [architecture](architecture.md)).
- **Everything is static** — there is no server runtime to lean on for theming or
  personalization.
