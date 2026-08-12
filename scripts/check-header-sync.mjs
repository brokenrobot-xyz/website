// Fails when the three copies of the Content-Security-Policy edge header drift apart, so the
// quiet failure mode documented in docs/architecture.md — the site keeps rendering while fonts
// and every bundled script fail in one environment — is caught before it ships rather than after.
//
// The header is authored in three places that must stay byte-identical: `server.headers` in
// astro.config.ts (what `astro preview`, and therefore the Playwright suite, serves), nginx.conf
// (Kubernetes), and the domain module in infra/cloudflare (Cloudflare — production). The suite
// only ever exercises the astro.config.ts copy, so drift in the other two passes every test and
// surfaces in production alone. Runs locally as `npm run headers:check` and in CI's Verify job.
//
//   node scripts/check-header-sync.mjs
//
// Exit codes:
//   0 — pass: all three copies are byte-identical.
//   1 — FAIL: the copies differ; each value is printed with the first divergent byte marked.
//   2 — not verified: a copy could not be read or extracted, so the run proves nothing. A
//       refactor that moves a header or changes its quoting style lands here rather than
//       passing silently.

import { readFileSync } from 'node:fs';

// Each pattern anchors on the header name rather than a line position, so unrelated edits to the
// file do not break extraction. Capture group 1 is the header value.
const SOURCES = [
    {
        file: 'astro.config.ts',
        pattern: /'Content-Security-Policy':\s*`([^`]*)`/
    },
    {
        file: 'nginx.conf',
        pattern: /add_header\s+Content-Security-Policy\s+"((?:[^"\\]|\\.)*)"/
    },
    {
        file: 'infra/cloudflare/modules/domain/main.tf',
        pattern: /"Content-Security-Policy"\s*=\s*\{[^}]*?value\s*=\s*"((?:[^"\\]|\\.)*)"/
    }
];

function firstDivergence(values) {
    const longest = Math.max(...values.map((v) => v.length));
    for (let i = 0; i < longest; i += 1) {
        if (new Set(values.map((v) => v.slice(i, i + 1))).size > 1) {
            return i;
        }
    }
    return -1;
}

const extracted = [];
for (const { file, pattern } of SOURCES) {
    let text;
    try {
        text = readFileSync(file, 'utf8');
    } catch {
        console.error(`not verified: ${file} could not be read — run from the repo root`);
        process.exit(2);
    }
    const match = text.match(pattern);
    if (match === null) {
        console.error(
            `not verified: no Content-Security-Policy header found in ${file} — the extraction pattern in scripts/check-header-sync.mjs no longer matches; update it alongside the header refactor`
        );
        process.exit(2);
    }
    extracted.push({ file, value: match[1] });
}

const values = extracted.map(({ value }) => value);
if (new Set(values).size === 1) {
    console.log(
        `pass: the Content-Security-Policy header is byte-identical across ${extracted.length} files (${values[0].length} bytes)`
    );
    process.exit(0);
}

const at = firstDivergence(values);
console.error(`FAIL: the Content-Security-Policy copies differ (first divergence at byte ${at}):`);
for (const { file, value } of extracted) {
    console.error(`  ${file} (${value.length} bytes)`);
    console.error(`      …${value.slice(Math.max(0, at - 40), at + 40)}…`);
}
console.error('Keep the three copies byte-identical — see docs/architecture.md § Content-Security-Policy.');
process.exit(1);
