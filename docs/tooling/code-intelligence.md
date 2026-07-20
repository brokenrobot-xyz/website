# Code intelligence

Two tools give Claude Code code-intelligence in this repo. Both run **on the host** (where the
interactive session runs, not the devcontainer), are **version-pinned via `package.json`**, and are
**committed** so the setup is reproducible — but each is _enabled_ locally, mirroring the existing
`.mcp.json` + `enabledMcpjsonServers` convention (see [sandbox.md](sandbox.md)).

## typescript-lsp (a Claude Code plugin)

The official [`typescript-lsp`](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/typescript-lsp)
plugin adds go-to-definition, find-references, and error-checking for `.ts/.tsx/.js/.jsx`.

- **Enabled** via `enabledPlugins` in [`.claude/settings.json`](../../.claude/settings.json)
  (committed). The `claude-plugins-official` marketplace is built into Claude Code, so no marketplace
  registration (`extraKnownMarketplaces`) is needed — that's only for custom/third-party sources.
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
call instead of grep/read loops. It runs 100% locally — no network, no credentials.

- **Registered** in [`.mcp.json`](../../.mcp.json) as `node_modules/.bin/codegraph serve --mcp` — the
  direct bin path, so it always runs the pinned local devDependency and fails fast if it's missing
  (no `npx` registry fallback that could pull an unpinned version). **Enabled** by adding
  `"codegraph"` to `enabledMcpjsonServers` in your (gitignored) `.claude/settings.local.json`.
- We deliberately do **not** run `codegraph install` — that writes a global `~/.claude.json` entry
  pointing at a global binary, defeating the repo-scoped version pin.
- The index lives in `.codegraph/` (SQLite + a daemon lock). It is **checkout-specific** — the lock
  and DB are tied to the path that wrote them — so it is **gitignored** and never shared between
  worktrees.

### Per-worktree bootstrap

A fresh git worktree contains only tracked files, so it starts with neither `node_modules/` nor
`.codegraph/`. The [`SessionStart` hook](../../.claude/settings.json) runs
[`scripts/worktree-init.sh`](../../scripts/worktree-init.sh) on every session start to keep
a worktree ready — it's idempotent and cheap on the common path:

- **No `node_modules`** (brand-new worktree) → runs `npm ci`.
- **No `.codegraph/`** (first session after install) → runs `codegraph init` to build the index.
- **Index present** → runs `codegraph sync -q` (~0.2s) to catch up on any between-session drift
  (e.g. edits or `git switch`/`pull`/`rebase` made while no session's file watcher was running).

While a session is open, `codegraph serve --mcp` runs a file watcher that auto-syncs on save, so the
bootstrap's job is really the first-run build plus between-session catch-up.

Run the same steps by hand any time with `npm run worktree:init`. `npm run codegraph:status` reports
the index/sync state.

> The bootstrap installs dependencies only when `node_modules` is missing — it does **not** detect a
> changed `package-lock.json` in an already-installed worktree. After pulling a lockfile change, run
> `npm ci` (or `npm run worktree:init` after removing `node_modules`) yourself.
