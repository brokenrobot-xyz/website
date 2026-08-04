# Code intelligence

Two tools give Claude Code code-intelligence in this repo. Both run **on the host** (where the
interactive session runs, not the devcontainer), are **version-pinned in committed config** — one in
`package.json`, one in `.mcp.json` — so the setup is reproducible; but each is _enabled_ locally,
mirroring the existing
`.mcp.json` + `enabledMcpjsonServers` convention (see [sandbox.md](sandbox.md)).

## typescript-lsp (a Claude Code plugin)

The official [`typescript-lsp`](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/typescript-lsp)
plugin adds go-to-definition, find-references, and error-checking for `.ts/.tsx/.js/.jsx`.

- **Enabled** via `enabledPlugins` in [`.claude/settings.json`](../../.claude/settings.json)
  (committed). The `claude-plugins-official` marketplace is built into Claude Code, so this plugin
  needs no marketplace registration (`extraKnownMarketplaces`) — that's only for custom/third-party
  sources such as the [brokenrobot-xyz/agent-skills](https://github.com/brokenrobot-xyz/agent-skills)
  marketplace the skill plugins come from (see [workflow.md](workflow.md)).
- The plugin launches a fixed `typescript-language-server --stdio` from `PATH` — the command is set
  in the marketplace manifest and is **not** project-configurable. Claude Code's launch `PATH` does
  **not** include the repo's `node_modules/.bin`, so the server must be installed **globally on the
  host** (`npm i -g typescript-language-server typescript`) — a single install covers every worktree.
  See [../development-environment.md](../development-environment.md) for the setup step.
- We still pin `typescript-language-server` as a devDependency, but purely as a **version
  reference** — the plugin doesn't consume it. Inside this repo the server uses the project's own
  pinned `typescript`; the global `typescript` is only a fallback for projects without a local one.

## Codegraph (an MCP server)

[Codegraph](https://github.com/colbymchenry/codegraph) (`@colbymchenry/codegraph`) serves a
pre-indexed SQLite code graph so the agent gets symbols, call paths, and impact analysis in a single
call instead of grep/read loops. Indexing and queries are 100% local and need no credentials, and the
only network call left is `npx` fetching the pinned package the first time a machine runs it. Both of
codegraph's own outbound calls are off, through `CODEGRAPH_TELEMETRY=0` and the cross-tool
`DO_NOT_TRACK=1` in [`.claude/settings.json`](../../.claude/settings.json), alongside the other
tools' opt-outs. Two things follow: telemetry is on by default and its CLI opt-out is saved
per-machine (`~/.codegraph/telemetry.json`), so the committed env vars are what make "off"
reproducible; and `DO_NOT_TRACK` also silences the background update check, so a new codegraph
release is something to go looking for — it is not a devDependency either, so `npm outdated` will
not surface it.

- **Registered** in [`.mcp.json`](../../.mcp.json) as
  `npx -y @colbymchenry/codegraph@1.5.0 serve --mcp`, with the version pinned **in the command**.
  Claude Code launches MCP servers before anything can install dependencies, so a
  `node_modules/.bin/…` path is simply absent in a fresh worktree and the server never starts for
  that session; `npx` has no such dependency. The explicit `@version` is what keeps that from
  costing the pin — a bare `npx <pkg>` starts fine but silently fetches the latest release. Codegraph
  is deliberately **not** a devDependency: nothing loads it from `node_modules`, and keeping it out
  cuts a 293 MB platform binary from every worktree's install in favour of one `npx` cache per
  machine. **Enabled** by adding `"codegraph"` to `enabledMcpjsonServers` in your (gitignored)
  `.claude/settings.local.json`.
- We deliberately do **not** run `codegraph install` — that writes a global `~/.claude.json` entry
  pointing at a global binary, defeating the repo-scoped version pin.
- The index lives in `.codegraph/` (SQLite + a daemon lock). It is **checkout-specific** — the lock
  and DB are tied to the path that wrote them — so it is **gitignored** and never shared between
  worktrees.

### Session start

The [`SessionStart` hook](../../.claude/settings.json) runs
[`.claude/hooks/session-start.sh`](../../.claude/hooks/session-start.sh) at the start of **every**
Claude Code session (startup and resume), in whatever checkout it opens in — the main clone or a
worktree. It's idempotent and cheap on the common path; a fresh worktree is simply the case where it
has real work to do, since it contains only tracked files and so starts with neither `node_modules/`
nor `.codegraph/`. It runs three steps and ends every session with a short step report — successes
and failures alike — delivered to both the user and the model (Claude Code reads hook output only
once the script exits, so the report arrives at the end rather than streaming):

1. **Tool sanity check** (report-only): presence of `git`, `node`, `npm`, `jq` and the global
   `typescript-language-server`; `node` is validated against `.node-version`, and the codegraph
   version pin is cross-checked between the lib, `.mcp.json` and the `codegraph:*` npm scripts.
   Problems point at the `checking-dev-env` skill, whose fix guide is built from
   [development-environment.md](../development-environment.md#troubleshooting)'s Troubleshooting
   entries — the hook diagnoses, it does not install tools.
2. **Dependencies**: `npm install`, but only when `node_modules/` is missing or
   `package-lock.json` has changed since the last successful install — a stamp inside
   `node_modules/` holds the lockfile's git hash, so a partial or wiped install self-invalidates.
   It's `npm install` rather than `npm ci` because the sandbox denies deleting one path inside
   `node_modules`, which `npm ci`'s wipe trips over; with the lockfile intact both resolve to the
   same tree. The same denial surfaces during install as a
   `npm warn tar TAR_ENTRY_ERROR EPERM … .vscode/settings.json` — benign: npm skips that one file
   and the install succeeds.
3. **Codegraph index**: `codegraph status --json` as the health probe — healthy ⇒ `sync -q`
   (~0.2s) to catch between-session drift (e.g. edits or `git switch`/`pull`/`rebase` made while
   no session's file watcher was running); uninitialized ⇒ `init`; built by an older codegraph or
   unreadable ⇒ `index` rebuild.

While a session is open, `codegraph serve --mcp` runs a file watcher that auto-syncs on save, so the
hook's job is really the first-run build plus between-session catch-up.

The hook is Claude Code's entry point only — it reads `CLAUDE_PROJECT_DIR` and has no `npm run`
equivalent. Its probes, though, live in
[`.claude/hooks/lib/dev-env-checks.sh`](../../.claude/hooks/lib/dev-env-checks.sh), shared with the
`checking-dev-env` skill and runnable by hand (`bash .claude/hooks/lib/dev-env-checks.sh` — read-only,
exits non-zero on any ✗). The mutating steps stay manual: run `npm install` and
`npm run codegraph:init` yourself; `npm run codegraph:status` reports the index/sync state.

> In a fresh worktree the server is up before the index exists, because Claude Code launches it
> before this hook can build one. Queries in that window answer with "no index — use Read/Grep/Glob"
> rather than failing or guessing, and the running server picks the index up on its own once the
> hook finishes — no restart needed.

> A worktree **nested inside the main checkout** — which is where Claude Code puts them,
> `.claude/worktrees/<name>/` (see [sandbox.md](sandbox.md)) — currently gets **no index of its
> own**: codegraph's project detection walks up from the worktree, anchors on the main checkout's
> `.codegraph/`, and while any session's MCP server holds that database, both the health probe and a
> rebuild fail with "database file is in use". The hook handles it as designed — it reports "NO
> usable index — use the normal file-reading tools" and continues; dependencies still install. The
> failure is specific to nesting: a checkout with no `.codegraph/` in any ancestor probes
> `initialized:false` and inits normally. Observed with codegraph 1.5.0 (July 2026); whether a
> nested worktree indexes correctly with no parent session running is unverified.
