---
name: scaffolding-components
description: Scaffolds a new Astro component (or Preact island) for brokenrobot.xyz to the repo's conventions — feature-folder placement, typed props, scoped token-driven styles, both-theme readiness, and the correct interactivity choice. Use when adding a new UI component so it matches the existing tree instead of drifting.
compatibility: Scaffolding itself needs only a checkout of this repo's Astro + Tailwind + Preact tree. Step 4's verification needs Node and npm at the package.json engine versions with dependencies installed, and Docker for the visual-regression half.
model: claude-sonnet-5
metadata:
    author: brokenrobot.xyz
    version: '1.0'
---

Create a new component that matches the existing codebase exactly, so reviews don't bounce on convention drift. Decide the **interactivity tier first**, then scaffold.

Everything below is distilled from [docs/development/conventions/coding-conventions.md](../../../docs/development/conventions/coding-conventions.md) — on conflict, that doc wins.

Copy this checklist into your reply and tick each item as you go:

```
Scaffold progress:
- [ ] 0. Choose the interactivity tier
- [ ] 1. Pick placement & name (list src/components/)
- [ ] 2/3. Scaffold the skeleton for the tier
- [ ] 4. Both-theme check + preflight
```

## 0 — Choose the tier (lightest tool that works)

- **No interactivity** → plain Astro component (zero JS). Default.
- **Small DOM wiring** (toggle a class, copy a value) → Astro component + a bundled `<script>` importing a `.ts` module (like `ThemeToggle.astro` + `theme-toggle.ts`). Loads from `self`, CSP-safe.
- **Real state** (search, mobile menu) → Preact island `.tsx` mounted `client:*`. Keep islands small and few — each ships the Preact runtime.
- Never add an inline script, because the site's CSP blocks it — the only one allowed is `BaseLayout`'s pre-paint theme-init.

## 1 — Placement & naming

- Group by feature: `src/components/<feature>/<Name>.astro` (PascalCase file). Feature folders are kebab-case (e.g. `blog-posts/`) — list `src/components/` for the current set.
- Reuse existing folders where the component belongs; only create a new feature folder if none fits.

## 2 — Astro component skeleton

```astro
---
type Props = {
    title: string;
    class?: string;
};

const { title, class: className } = Astro.props;
---

<section class:list={[className]}>
    <h2>{title}</h2>
    <slot />
</section>

<style>
    @reference '../../styles/base.css'; /* adjust depth to reach src/styles/ */

    section {
        @apply bg-surface text-text border-border rounded-lg border p-6;
    }
</style>
```

Conventions baked in above:

- Local `type Props`, destructured from `Astro.props` (alias `class` → `className`).
- Scoped `<style>` opens with `@reference '../../styles/base.css';` (adjust depth), then `@apply` Tailwind utilities — **Tailwind-first**.
- **Token utilities only** — any `--color-*` token in `src/styles/base.css` (`bg-bg`, `bg-surface`, `bg-surface-2`, `text-text`, `text-muted`, `text-accent`, `text-accent-ink`, `border-border`); no hard-coded colors, so light/dark both work. When no token covers the request, ask which one to use rather than hard-coding a value.
- Use `InternalLink` / `ExternalLink` (from `@components/links/`) for anchors, never raw `<a>` — a raw one loses the shared hover style, and an external one also loses `target`/`rel` and the external-link icon.
- Import with path aliases (`@components/*`, `@layouts/*`, `@assets/*`, `@styles/*`).

## 3 — Preact island skeleton (only if stateful)

```tsx
import { useState } from 'preact/hooks';

type Props = {
    label: string;
};

export function Thing({ label }: Props) {
    const [open, setOpen] = useState(false);

    return (
        <button
            type="button"
            class="bg-surface text-text border-border rounded border px-3 py-2"
            aria-expanded={open}
            onClick={() => setOpen((v) => !v)}
        >
            {label}
        </button>
    );
}
```

- Preact JSX (`jsxImportSource: preact`), idiomatic `class` attribute, token utilities for styling.
- Same strict rules as `.ts` (no `any`, explicit booleans, `import type` for types) plus jsx-a11y.
- Mount in an `.astro` with the lightest directive that works (`client:visible`, `client:idle`, …).

## 4 — Don't forget

- **Both themes:** sanity-check the component reads well in light and dark (token usage, not hard-coded values). New UI needs both-theme snapshot + a11y coverage — see the `testing-visual-regression` skill.
- Keep it **surgical** — scaffold only what the task needs; no speculative props or configurability.
- Run the `running-preflight-checks` skill (or `type:check` / `lint:check`) before handing off, and format the files you touched with `npx prettier --write` — never `npm run format:fix`, which reformats files your change never touched.
