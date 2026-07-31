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
// `diff` prints { baseline, new, resolved, preExisting } as JSON and exits 1 when `new` is
// non-empty, 0 otherwise. The baseline defaults to a path in the OS temp dir keyed to the working
// directory, so the two invocations find each other without coordination while concurrent runs
// in different worktrees stay isolated.
//
// Both modes audit the WHOLE tree, devDependencies included. This is deliberately wider than
// `npm run audit:check`, which omits dev because dev packages never ship to the static site. An
// upgrade is a different question: it changes what runs at build time, so a build-time advisory the
// update pulls in is the update's fault and has to surface. Roughly half this repo's direct
// dependencies are dev, so omitting them would let most runs report a clean audit they had not
// earned.
//
// `diff` echoes the baseline's provenance — the commit it was taken at and when — so a report can
// never present an earlier run's baseline as this run's.

import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const AUDIT_ARGS = ['audit', '--package-lock-only', '--json'];

// A dependency update runs to completion within one session. A baseline older than a day was left
// behind by an earlier run, and diffing against it would blame this update for that run's
// advisories, so `diff` refuses it rather than reporting a confident wrong attribution.
const MAX_BASELINE_AGE_MS = 24 * 60 * 60 * 1000;

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
    const head = execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim();
    const baseline = { head, takenAt: new Date().toISOString(), ids };
    writeFileSync(baselinePath, `${JSON.stringify(baseline, null, 4)}\n`);
    console.log(`Baseline: ${ids.length} advisories at ${head.slice(0, 12)} -> ${baselinePath}`);
} else if (mode === 'diff') {
    let baseline;
    try {
        baseline = JSON.parse(readFileSync(baselinePath, 'utf8'));
    } catch (error) {
        if (error.code === 'ENOENT') {
            console.error(`No baseline found at ${baselinePath} — run \`snapshot\` first (Step 1).`);
            process.exit(2);
        }
        throw error;
    }
    const takenAtMs = Date.parse(baseline?.takenAt ?? '');
    if (!Array.isArray(baseline?.ids) || !Number.isFinite(takenAtMs)) {
        console.error(`Baseline at ${baselinePath} is not in the current format — run \`snapshot\` again (Step 1).`);
        process.exit(2);
    }
    const ageMs = Date.now() - takenAtMs;
    if (ageMs > MAX_BASELINE_AGE_MS) {
        const ageHours = Math.round(ageMs / (60 * 60 * 1000));
        console.error(
            `Baseline at ${baselinePath} was taken ${ageHours}h ago (${baseline.takenAt}) and belongs to an earlier run — run \`snapshot\` again (Step 1).`
        );
        process.exit(2);
    }
    const baselineIds = new Set(baseline.ids);
    const current = currentAdvisories();
    const added = [...current.values()].filter((advisory) => !baselineIds.has(advisory.id));
    const resolved = [...baselineIds].filter((id) => !current.has(id)).sort();
    const preExisting = [...current.keys()].filter((id) => baselineIds.has(id)).sort();
    const provenance = { head: baseline.head, takenAt: baseline.takenAt };
    console.log(JSON.stringify({ baseline: provenance, new: added, resolved, preExisting }, null, 4));
    process.exit(added.length > 0 ? 1 : 0);
} else {
    console.error('Usage: node audit-diff.mjs <snapshot|diff> [baseline.json]');
    process.exit(2);
}
