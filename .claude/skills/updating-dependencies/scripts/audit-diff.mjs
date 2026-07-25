// Snapshots and diffs npm audit advisories so a dependency update is judged only on the
// advisories it introduces, not on the whole tree's pre-existing baseline.
//
// Used by the updating-dependencies skill: `snapshot` runs before any package changes and records
// the advisory IDs present at HEAD; `diff` runs at each verification pass and classifies the
// current advisories against that baseline. Only `new` advisories block a commit.
//
//   node .claude/skills/updating-dependencies/scripts/audit-diff.mjs snapshot [baseline.json]
//   node .claude/skills/updating-dependencies/scripts/audit-diff.mjs diff [baseline.json]
//
// `diff` prints { new, resolved, preExisting } as JSON and exits 1 when `new` is non-empty,
// 0 otherwise. The baseline defaults to a path in the OS temp dir keyed to the working
// directory, so the two invocations find each other without coordination while concurrent runs
// in different worktrees stay isolated. Both modes run the same audit command (the JSON form of
// `npm run audit:check`) so the comparison is like-for-like.

import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const AUDIT_ARGS = ['audit', '--package-lock-only', '--omit=dev', '--json'];

// Key the baseline to the repo/worktree the run is in (both modes run from the repo root).
const cwdKey = createHash('sha256').update(process.cwd()).digest('hex').slice(0, 12);

const [mode, baselinePath = join(tmpdir(), `npm-audit-baseline-${cwdKey}.json`)] =
    process.argv.slice(2);

function currentAdvisories() {
    let out;
    try {
        out = execFileSync('npm', AUDIT_ARGS, { encoding: 'utf8' });
    } catch (error) {
        // npm audit exits non-zero when advisories exist; the JSON is still on stdout.
        out = error.stdout;
        if (!out) {
            console.error(`npm audit produced no output: ${error.message}`);
            process.exit(1);
        }
    }
    const { vulnerabilities = {} } = JSON.parse(out);
    const advisories = new Map();
    for (const [pkg, vuln] of Object.entries(vulnerabilities)) {
        for (const via of vuln.via ?? []) {
            if (typeof via !== 'object' || !via.url) {
                continue;
            }
            const id = String(via.url).split('/').pop();
            advisories.set(id, { id, severity: via.severity, title: via.title, package: pkg });
        }
    }
    return advisories;
}

if (mode === 'snapshot') {
    const ids = [...currentAdvisories().keys()].sort();
    writeFileSync(baselinePath, `${JSON.stringify(ids, null, 4)}\n`);
    console.log(`Baseline: ${ids.length} advisories -> ${baselinePath}`);
} else if (mode === 'diff') {
    let baselineIds;
    try {
        baselineIds = JSON.parse(readFileSync(baselinePath, 'utf8'));
    } catch (error) {
        if (error.code === 'ENOENT') {
            console.error(`No baseline found at ${baselinePath} — run \`snapshot\` first (Step 1).`);
            process.exit(2);
        }
        throw error;
    }
    const baseline = new Set(baselineIds);
    const current = currentAdvisories();
    const added = [...current.values()].filter((advisory) => !baseline.has(advisory.id));
    const resolved = [...baseline].filter((id) => !current.has(id)).sort();
    const preExisting = [...current.keys()].filter((id) => baseline.has(id)).sort();
    console.log(JSON.stringify({ new: added, resolved, preExisting }, null, 4));
    process.exit(added.length > 0 ? 1 : 0);
} else {
    console.error('Usage: node audit-diff.mjs <snapshot|diff> [baseline.json]');
    process.exit(2);
}
