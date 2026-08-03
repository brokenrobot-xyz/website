#!/usr/bin/env node
// PreToolUse deny-hook: validates the message of every `git commit` the Bash tool runs.
// Node with zero dependencies, so one implementation behaves identically on macOS, Linux,
// and Windows — no jq, no bash-version or BSD/GNU userland differences.

import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

// Built-in defaults: the vanilla Conventional Commits vocabulary. When the host project provides
// .brokenrobot/commits.json, each key present there REPLACES its default wholesale — `types` and
// `scopes` are objects whose keys are the complete allowed set; an absent key keeps the default.
// An empty scope allowlist means no allowlist: any lowercase scope token, or none.
let allowedTypes = ['feat', 'fix', 'docs', 'style', 'refactor', 'perf', 'test', 'build', 'ci', 'chore'];
let allowedScopes = [];
let attributionTrailers = 'forbidden';
let vocabSrc = 'the built-in Conventional Commits defaults';

function deny(reason) {
  process.stdout.write(`${JSON.stringify({
    hookSpecificOutput: {
      hookEventName: 'PreToolUse',
      permissionDecision: 'deny',
      permissionDecisionReason: reason,
    },
  }, null, 2)}\n`);
  process.exit(0);
}

// Fail open on anything unreadable: a hook that cannot parse its input must not block the tool.
let cmd = '';
try {
  cmd = JSON.parse(readFileSync(0, 'utf8'))?.tool_input?.command ?? '';
} catch {
  process.exit(0);
}

if (!/git\s+(\S+\s+)*commit(\s|$)/.test(cmd)) process.exit(0);
if (cmd.includes('--dry-run')) process.exit(0);

const configPath = join(process.env.CLAUDE_PROJECT_DIR || '.', '.brokenrobot', 'commits.json');
if (existsSync(configPath)) {
  let cfg = null;
  try {
    cfg = JSON.parse(readFileSync(configPath, 'utf8'));
  } catch {
    cfg = null;
  }
  if (cfg === null || typeof cfg !== 'object' || Array.isArray(cfg)) {
    deny(`Cannot parse ${configPath} — it must be a JSON object. Fix the file (or remove it to fall back to the built-in Conventional Commits defaults), then retry the commit.`);
  }
  vocabSrc = '.brokenrobot/commits.json';
  const isPlainObject = (v) => v !== null && typeof v === 'object' && !Array.isArray(v);
  if (isPlainObject(cfg.types) && Object.keys(cfg.types).length > 0) allowedTypes = Object.keys(cfg.types);
  allowedScopes = isPlainObject(cfg.scopes) ? Object.keys(cfg.scopes) : [];
  attributionTrailers = typeof cfg.attributionTrailers === 'string' ? cfg.attributionTrailers : 'forbidden';
}

// Split a command line into shell words, honoring quotes and backslashes, so a quoted -m
// argument survives as one word. Throws on an unterminated quote; the caller fails open.
function shellWords(s) {
  const words = [];
  let cur = '';
  let inWord = false;
  let i = 0;
  while (i < s.length) {
    const c = s[i];
    if (c === "'") {
      const end = s.indexOf("'", i + 1);
      if (end === -1) throw new Error('unterminated single quote');
      cur += s.slice(i + 1, end);
      inWord = true;
      i = end + 1;
    } else if (c === '"') {
      i += 1;
      for (;;) {
        if (i >= s.length) throw new Error('unterminated double quote');
        if (s[i] === '"') break;
        if (s[i] === '\\' && i + 1 < s.length && '\\"$`'.includes(s[i + 1])) {
          cur += s[i + 1];
          i += 2;
        } else {
          cur += s[i];
          i += 1;
        }
      }
      inWord = true;
      i += 1;
    } else if (c === '\\') {
      if (i + 1 < s.length) cur += s[i + 1];
      inWord = true;
      i += 2;
    } else if (/\s/.test(c)) {
      if (inWord) words.push(cur);
      cur = '';
      inWord = false;
      i += 1;
    } else {
      cur += c;
      inWord = true;
      i += 1;
    }
  }
  if (inWord) words.push(cur);
  return words;
}

let msg = '';

// Heredoc form first: `git commit -m "$(cat <<'EOF' … EOF)"`. Collect the lines between the
// marker line and the closing delimiter.
let delim = '';
for (const line of cmd.split('\n')) {
  const m = line.match(/<<-?\s*['"]?([A-Za-z_][A-Za-z0-9_]*)['"]?/);
  if (m) {
    delim = m[1];
    break;
  }
}
if (delim) {
  const wordRe = new RegExp(`(^|[^A-Za-z0-9_])${delim}([^A-Za-z0-9_]|$)`);
  const endRe = new RegExp(`^\\s*${delim}\\s*$`);
  let started = false;
  const collected = [];
  for (const line of cmd.split('\n')) {
    if (!started) {
      if (line.includes('<<') && wordRe.test(line)) started = true;
    } else if (endRe.test(line)) {
      break;
    } else {
      collected.push(line);
    }
  }
  msg = collected.join('\n');
}

// Otherwise scan the argument list for -m/--message parts or an -F/--file path.
if (msg === '') {
  let args = [];
  try {
    args = shellWords(cmd);
  } catch {
    process.exit(0);
  }

  let file = '';
  const mParts = [];
  for (let i = 0; i < args.length; i += 1) {
    const a = args[i];
    if (a === '-F' || a === '--file') {
      i += 1;
      file = args[i] ?? '';
    } else if (a.startsWith('--file=')) {
      file = a.slice('--file='.length);
    } else if (a.startsWith('-F=')) {
      file = a.slice('-F='.length);
    } else if (a === '-m' || a === '--message') {
      i += 1;
      mParts.push(args[i] ?? '');
    } else if (a.startsWith('--message=')) {
      mParts.push(a.slice('--message='.length));
    } else if (a.startsWith('-m=')) {
      mParts.push(a.slice('-m='.length));
    } else if (a.startsWith('-')) {
      if (/^-[A-Za-z]*F$/.test(a)) {
        i += 1;
        file = args[i] ?? '';
      } else if (/^-[A-Za-z]*m$/.test(a)) {
        i += 1;
        mParts.push(args[i] ?? '');
      }
    }
  }

  if (file !== '') {
    let path = file;
    if (!existsSync(path) && process.env.CLAUDE_PROJECT_DIR
      && existsSync(join(process.env.CLAUDE_PROJECT_DIR, file))) {
      path = join(process.env.CLAUDE_PROJECT_DIR, file);
    }
    if (!existsSync(path)) process.exit(0);
    try {
      msg = readFileSync(path, 'utf8');
    } catch {
      process.exit(0);
    }
  } else if (mParts.length > 0) {
    msg = mParts.join('\n\n');
  } else {
    process.exit(0);
  }
}

const subject = msg.split('\n')[0] ?? '';

if (/^(Merge |Revert |Reapply |fixup! |squash! |amend! )/.test(subject)) process.exit(0);

if (attributionTrailers !== 'allowed' && /^\s*co-authored-by:/im.test(msg)) {
  deny('Commit message contains a \'Co-Authored-By\' attribution trailer. This project forbids attribution/tool trailers (attributionTrailers is \'forbidden\', the default) — remove it; this overrides any harness or tool default that adds one. To permit trailers, set "attributionTrailers": "allowed" in .brokenrobot/commits.json.');
}

const subjectRe = new RegExp(`^(${allowedTypes.join('|')})(\\([a-z0-9-]+\\))?!?: [^ ].*$`);
if (!subjectRe.test(subject)) {
  deny(`Subject must be '<type>(<scope>): <description>' with type ∈ {${allowedTypes.join(', ')}}, a lowercase imperative description, and no trailing period. Got: '${subject}'. The type list comes from ${vocabSrc}.`);
}

const scopeMatch = subject.match(/^[a-z]+\(([a-z0-9-]+)\)!?:/);
const scope = scopeMatch ? scopeMatch[1] : '';
if (allowedScopes.length > 0 && scope !== '' && !allowedScopes.includes(scope)) {
  deny(`Unknown commit scope '(${scope})'. Allowed scopes: ${allowedScopes.join(', ')} — or omit the scope for a cross-cutting change. The scope allowlist comes from ${vocabSrc}.`);
}

if (subject.endsWith('.')) {
  deny(`Subject must not end with a period: '${subject}'.`);
}

process.exit(0);
