// Generates `src/styles/tokens.generated.css` from the DESIGN.md token source of truth.
//
// DESIGN.md (light) and DESIGN.dark.md (dark) own the site's colour token *values*. This script
// reads them through `@google/design.md`'s `json-tailwind` export and emits the `:root` and
// `html[data-theme='dark']` custom-property blocks that `base.css` imports. The rest of `base.css`
// (the `@theme inline` mapping, fonts, shadows, `color-mix` derivations, `.prose`) stays
// hand-authored.
//
//   node scripts/generate-tokens.mjs            # write the generated CSS
//   node scripts/generate-tokens.mjs --check    # fail (exit 1) if the file on disk is stale
//
// Do not hand-edit the generated file — change the DESIGN files and regenerate.
//
// ---------------------------------------------------------------------------
// Why a script, and not just `design.md export` in package.json?
// ---------------------------------------------------------------------------
// The tool's `export --format css-tailwind` cannot produce what base.css needs.
// As of @google/design.md 0.3.0 the export always emits a single, flat Tailwind
// v4 `@theme { --color-*: <value> }` block, with no flags for the selector, the
// variable prefix, or emitting light/dark modes — the DESIGN.md format has no
// theme/mode dimension. Our theming needs two things it can't express:
//
//   1. Two attribute-switched blocks — `:root { --bg }` and
//      `html[data-theme='dark'] { --bg }`. We switch themes by swapping the
//      custom-property VALUES on `data-theme` (resolved pre-paint to avoid a
//      flash), not via Tailwind's `dark:` variant. Two flat `@theme` blocks
//      would clobber each other, not switch.
//   2. Our raw `--bg` names, not `--color-bg`. The `@theme inline` mapping in
//      base.css (`--color-bg: var(--bg)`) is the indirection that makes utilities
//      theme-aware; the export's static `--color-bg` has no per-theme override
//      hook.
//
// So this script still leans ENTIRELY on the tool for token resolution (it calls
// `export --format json-tailwind` below) and only adds the multi-theme/selector
// *reshaping* the format intentionally omits. The alternatives were rejected: a
// pure `export > file` script breaks dark mode; an `export | sed` one-liner is
// the same reshape in fragile shell; re-architecting onto Tailwind's `dark:`
// variant would undo the no-flash pre-paint design. See
// docs/design-md-assessment.md ("The dual light/dark catch") for the full record.

import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const cli = fileURLToPath(import.meta.resolve('@google/design.md'));
const target = join(repoRoot, 'src', 'styles', 'tokens.generated.css');

// Colours that exist only for tooling (e.g. the linter's `missing-primary` rule) and must NOT
// become CSS custom properties consumed by the site.
const SKIP_COLORS = new Set(['primary']);

const THEMES = [
    { file: 'DESIGN.md', selector: ':root', mode: 'light' },
    { file: 'DESIGN.dark.md', selector: "html[data-theme='dark']", mode: 'dark' }
];

// `<meta name="theme-color">` takes a literal colour — it cannot read a CSS custom property — so
// BaseLayout hard-codes the light and dark `--bg` values. Nothing regenerates those two literals,
// so `--check` compares them against the tokens; without this the browser chrome silently keeps the
// old background after a DESIGN file changes.
const layout = join(repoRoot, 'src', 'layouts', 'BaseLayout.astro');

function colorsFor(file) {
    const json = execFileSync(process.execPath, [cli, 'export', '--format', 'json-tailwind', join(repoRoot, file)], {
        encoding: 'utf8'
    });
    const colors = JSON.parse(json).theme?.extend?.colors ?? {};
    return Object.entries(colors).filter(([name]) => !SKIP_COLORS.has(name));
}

function block(selector, colors) {
    const lines = colors.map(([name, value]) => `        --${name}: ${value};`).join('\n');
    return `    ${selector} {\n${lines}\n    }`;
}

function themeColorMetas() {
    const html = readFileSync(layout, 'utf8');
    const found = {};
    for (const [meta] of html.matchAll(/<meta\b[^>]*name="theme-color"[^>]*\/>/g)) {
        const mode = /media="\(prefers-color-scheme:\s*(light|dark)\)"/.exec(meta)?.[1];
        const content = /content="([^"]+)"/.exec(meta)?.[1];
        if (mode !== undefined && content !== undefined) {
            found[mode] = content;
        }
    }
    return found;
}

function themeColorDrift(themes) {
    const metas = themeColorMetas();
    return themes.flatMap(({ mode, colors }) => {
        const bg = colors.find(([name]) => name === 'bg')?.[1];
        if (bg === undefined || metas[mode] === bg) {
            return [];
        }
        return [`  ${mode}: theme-color is ${metas[mode] ?? '(missing)'}, --bg is ${bg}`];
    });
}

const header =
    '/* AUTO-GENERATED — do not edit.\n' +
    '   Source of truth: DESIGN.md (light) and DESIGN.dark.md (dark).\n' +
    '   Regenerate with `npm run tokens:generate`. */\n';

const themes = THEMES.map(({ file, selector, mode }) => ({ selector, mode, colors: colorsFor(file) }));
const body = themes.map(({ selector, colors }) => block(selector, colors)).join('\n\n');
const output = `${header}\n@layer base {\n${body}\n}\n`;

if (process.argv.includes('--check')) {
    let current = '';
    try {
        current = readFileSync(target, 'utf8');
    } catch {
        // missing file counts as stale
    }
    if (current !== output) {
        console.error('tokens.generated.css is out of date. Run `npm run tokens:generate` and commit the result.');
        process.exit(1);
    }
    const drift = themeColorDrift(themes);
    if (drift.length > 0) {
        console.error(
            `BaseLayout.astro theme-color meta tags do not match the --bg tokens:\n${drift.join('\n')}\n` +
                'Update the `content` values in src/layouts/BaseLayout.astro to match.'
        );
        process.exit(1);
    }
    console.log('tokens.generated.css is up to date, and the theme-color metas match --bg.');
} else {
    writeFileSync(target, output);
    console.log(`Wrote ${target}`);
}
