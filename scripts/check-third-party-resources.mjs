// Fails when built output requests a resource from a third party, so a page that the site's own
// CSP would block is caught before it reaches production rather than after.
//
// The site serves `default-src 'none'` with every fetch directive at `'self'` or `'none'`, so a
// third-party resource in the output is a silently broken page, not a style preference. Runs
// locally as `npm run thirdparty:check` and in CI's Build job after `astro build`.
//
//   node scripts/check-third-party-resources.mjs [dist/]
//
// Exit codes:
//   0 — pass: no third-party resource request found.
//   1 — FAIL: at least one found; each is printed as `path` then the offending URL.
//   2 — not verified: the directory is missing or holds nothing to scan, so the run proves
//       nothing. A failed `astro build` leaves `dist/` emptied or half-written and lands here,
//       which keeps an empty result from being reported as a pass.

import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

const OWN_HOST = 'brokenrobot.xyz';

// Git's own binary heuristic reads the first 8000 bytes; a NUL byte in that window means the file
// is not text output and there is nothing in it for these patterns to match.
const BINARY_SNIFF_BYTES = 8000;

// Each pattern matches a position that makes the browser fetch the URL. `href` is deliberately
// confined to `<link>`: an outbound `<a href>` in prose is a link the reader clicks, not a request
// the page makes. The attribute patterns allow either quote character and whitespace around `=`,
// because `.prettierrc.json` sets `singleQuote` and an `is:inline` script body reaches the output
// verbatim, so `img.src = 'https://…'` is as real a request as `src="https://…"`.
const RESOURCE_CONTEXTS = [
    /(?:src|srcset|poster)\s*=\s*(['"])[\s\S]*?\1/gi,
    /<link\b[^>]*?\bhref\s*=\s*(['"])[\s\S]*?\1[^>]*>/gi,
    /url\([^)]*\)/gi,
    /\b(?:fetch|import)\([^)]*\)/gi
];

// Every URL inside a matched context, including each candidate of a `srcset` list. A
// protocol-relative URL is only read as one when it opens a quoted attribute value, because bare
// `//` is also how every JavaScript line comment starts.
const URL_IN_CONTEXT = /https?:\/\/[^"'\s,)>]+/gi;
const PROTOCOL_RELATIVE_ATTRIBUTE = /=\s*(['"])(\/\/[^"'\s,)>]+)/gi;

function isOwnHost(host) {
    return host === OWN_HOST || host.endsWith(`.${OWN_HOST}`);
}

function textFiles(dir) {
    const found = [];
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
        const path = join(dir, entry.name);
        if (entry.isDirectory()) {
            found.push(...textFiles(path));
            continue;
        }
        if (!entry.isFile()) {
            continue;
        }
        const contents = readFileSync(path);
        if (contents.subarray(0, BINARY_SNIFF_BYTES).includes(0)) {
            continue;
        }
        found.push({ path, text: contents.toString('utf8') });
    }
    return found;
}

// A URL that will not parse is reported rather than skipped: this check exists to catch a request
// that would otherwise reach production unnoticed, so an unreadable candidate is the caller's to
// look at, not the script's to discard.
function thirdPartyUrls(text) {
    const raws = new Set();
    for (const pattern of RESOURCE_CONTEXTS) {
        for (const [context] of text.matchAll(pattern)) {
            for (const [url] of context.matchAll(URL_IN_CONTEXT)) {
                raws.add(url);
            }
            for (const [, , url] of context.matchAll(PROTOCOL_RELATIVE_ATTRIBUTE)) {
                raws.add(url);
            }
        }
    }
    const external = [];
    for (const raw of raws) {
        let host;
        try {
            host = new URL(raw.startsWith('//') ? `https:${raw}` : raw).host;
        } catch {
            external.push(`${raw} (unparseable URL — check it by hand)`);
            continue;
        }
        if (!isOwnHost(host)) {
            external.push(raw);
        }
    }
    return external.sort();
}

const [dir = 'dist/'] = process.argv.slice(2);

try {
    if (!statSync(dir).isDirectory()) {
        console.error(`not verified: ${dir} is not a directory`);
        process.exit(2);
    }
} catch {
    console.error(`not verified: ${dir} does not exist — run \`npm run build\` first`);
    process.exit(2);
}

const files = textFiles(dir);
if (files.length === 0) {
    console.error(`not verified: ${dir} holds no scannable output — the build did not complete`);
    process.exit(2);
}

let violations = 0;
for (const { path, text } of files) {
    for (const url of thirdPartyUrls(text)) {
        console.log(`${path}\n    ${url}`);
        violations += 1;
    }
}

if (violations > 0) {
    console.error(`FAIL: ${violations} third-party resource request(s) in ${dir}`);
    process.exit(1);
}

console.log(`pass: no third-party resource requests in ${dir} (${files.length} file(s) scanned)`);
