# Development environment

How to set up a machine to work on brokenrobot.xyz. This is the human counterpart to the root
[README](../README.md) quickstart (`npm install` / `npm start`): it covers the prerequisites, the
tooling that `npm ci` doesn't install, and how the pieces fit together. It **links** the sources of
truth rather than restating them, so versions and commands live in one place.

## Prerequisites

| Tool | Version       | Source of truth                                |
| ---- | ------------- | ---------------------------------------------- |
| Node | **26.2.0**    | [`.node-version`](../.node-version)            |
| npm  | **≥ 11.13.0** | `engines` in [`package.json`](../package.json) |

[`.npmrc`](../.npmrc) sets `engine-strict=true`, so installs **fail** if your Node/npm fall below
those floors — this is intentional, keeping everyone on the pinned toolchain. It also sets
`save-exact=true` (dependencies are pinned to exact versions, no `^`).

## Node version management

The repo commits a [`.node-version`](../.node-version) file and does **not** mandate a manager — any
tool that reads it works (fnm, nvm, asdf, volta). Using [fnm](https://github.com/Schniz/fnm) as the
worked example:

```sh
fnm install # installs the version named in .node-version (26.2.0)
fnm use     # switches the current shell to it
```

Enable `fnm`'s `--use-on-cd` shell hook and it will switch automatically when you `cd` into the repo.
With nvm the equivalent is `nvm install && nvm use`; asdf/volta read `.node-version` similarly.

## Install

```sh
git clone git@github.com:brokenrobot-xyz/website.git
cd website
npm ci    # reproducible install from the committed package-lock.json
npm start # dev server on http://localhost:4321
```

Use `npm ci` (not `npm install`) for a clean, lockfile-exact install. The common scripts:
`npm run type:check`, `npm run lint:check`, `npm run format:check`, `npm run build` — see
[`package.json`](../package.json) for the full list.

### The dev server in the background

Since Astro 7, `astro dev` **detaches automatically when it detects an AI coding agent**, so it
does not block the agent's terminal. Started that way it is managed through subcommands rather
than Ctrl-C:

```sh
npx astro dev status  # URL, PID, uptime
npx astro dev logs -f # stream the log (also at .astro/dev.log)
npx astro dev stop    # SIGTERM, escalating to SIGKILL after 5s
```

A lock file at `.astro/dev.json` (gitignored) records the URL, port and PID, and stops a second
server being started for the same project. Related flags: `--background` to detach explicitly,
`--force` to replace a running server, and `--ignore-lock` to start one _alongside_ an existing
server — the latter is untracked, so `stop`/`status`/`logs` will not see it. Set
`ASTRO_DEV_BACKGROUND=0` to opt out and run in the foreground.

The dev server also exposes `/_astro/status`, returning `{"ok":true}` — a better readiness check
than sleeping. It exists only in dev, never in a build.

Running a dev server per worktree is fine (each has its own `.astro/`, so the locks are
independent), but they all default to port 4321 — give each one `--port`.

> **Caveat when an agent starts the server on the host.** See
> [sandbox](tooling/sandbox.md#the-dev-server-lock-file) — the lock file is not written under the
> Claude Code sandbox, which leaves the server unmanageable by `astro dev stop`.

## Host vs. devcontainer

Do day-to-day development — and run your Claude Code session — **on the host**. The
[devcontainer](../.devcontainer/devcontainer.json) exists for **one** job: the Playwright
visual-regression e2e suite, which must render in a Linux environment matching CI (host macOS
rendering is not authoritative). Drive it through the npm scripts:

```sh
npm run dc:up           # bring the devcontainer up (installs deps + Playwright browsers)
npm run test:e2e:check  # build + run the visual-regression / a11y suite inside it
npm run test:e2e:update # regenerate snapshots for an intentional visual change
```

Why git and Docker behave the way they do under the agent sandbox is documented in
[tooling/sandbox.md](tooling/sandbox.md).

## Code-intelligence tools (Claude Code)

Two tools give Claude Code code intelligence in this repo; the full rationale is in
[tooling/code-intelligence.md](tooling/code-intelligence.md). One requires a manual host step:

- **typescript-lsp plugin** — install the language server **globally on the host**, once:

    ```sh
    npm i -g typescript-language-server typescript
    ```

    This is **required**, not optional: the plugin launches a bare `typescript-language-server` from
    your shell `PATH`, which can't reach the repo's `node_modules/.bin`. A single host install covers
    **every** worktree. When you're inside this repo the server still uses the project's own pinned
    `typescript`; the global `typescript` is only a fallback for projects without a local one. (The
    repo also pins `typescript-language-server` as a devDependency, but purely as a version reference —
    the plugin doesn't consume it.)

- **Codegraph MCP server** — needs no manual step; the `SessionStart` hook described below builds its
  index.

## Worktrees

This repo is worked on in git worktrees. A fresh worktree checks out only tracked files, so it starts
with **no `node_modules/` and no `.codegraph/`** (both gitignored). Claude Code brings one up to speed
automatically: its `SessionStart` hook — which runs in every session, worktree or not — installs
dependencies when `node_modules/` is missing or `package-lock.json` has changed, then builds or
refreshes the Codegraph index (with a caveat for nested worktrees — see the note in
[tooling/code-intelligence.md](tooling/code-intelligence.md)). Outside a session, run `npm install`
yourself.

Details, including the between-session sync behavior, are in
[tooling/code-intelligence.md](tooling/code-intelligence.md); why worktrees sit under
`.claude/worktrees/` and how the sandbox treats them is in [tooling/sandbox.md](tooling/sandbox.md).

## Editor

Formatting is governed by [`.editorconfig`](../.editorconfig) (LF, UTF-8, final newline, 4-space
indent — 2 for `.tf`/`.yml`, tabs for `Makefile`). The [devcontainer](../.devcontainer/devcontainer.json)
declares the recommended extensions, worth installing in your host editor too:

- **EditorConfig**, **Prettier**, **ESLint** — formatting and linting parity with CI.
- **Astro**, **Tailwind CSS**, **MDX** — first-class support for the stack.
- **Terraform**, **YAML** — infrastructure and CI config.
- **Playwright** — running/debugging the e2e suite.

## Verify

After setup, confirm the environment:

```sh
node -v && npm -v                    # 26.2.0 / ≥ 11.13.0
npm run type:check                   # Astro + tsc, no errors
npm run lint:check                   # ESLint clean
npm run format:check                 # Prettier clean
npm run build                        # production build succeeds
typescript-language-server --version # global LSP present
npm run codegraph:status             # "Index is up to date"
```

In Claude Code, `/plugin` should list **typescript-lsp** as enabled, and `/mcp` should show
**codegraph** connected.

## Troubleshooting

The symptoms below are the ✗ lines emitted by the Claude Code `SessionStart` report and by the
`checking-dev-env` skill — both run the same probes,
[`.claude/hooks/lib/dev-env-checks.sh`](../.claude/hooks/lib/dev-env-checks.sh). Per this doc's
charter each entry links the fix rather than restating it; the skill turns matching entries into
an ordered setup guide. (Detection wording lives in the lib; keep these headings in step with it.)

### ✗ git missing · ✗ jq missing

Install with Homebrew: `brew install git jq`.

### ✗ node missing · ✗ node is … but .node-version pins … · ✗ no node version manager detected

Install a version manager and the pinned Node — see
[Node version management](#node-version-management).

### ✗ npm missing

npm ships with Node; fixing the Node install above fixes this too. If npm is present but too old,
`npm install -g npm` brings it to the `engines` floor.

### ✗ dependencies: node_modules missing or stale · ✗ npm install failed

Run `npm ci` from the checkout — see [Install](#install). Inside a Claude Code session the
`SessionStart` hook installs on the next session start by itself.

### ✗ typescript-language-server missing

One global install per machine: `npm i -g typescript-language-server typescript` — the why is in
[Code-intelligence tools](#code-intelligence-tools-claude-code).

### ✗ typescript-lsp plugin not enabled

The plugin is committed in [`.claude/settings.json`](../.claude/settings.json) under
`enabledPlugins`, so a ✗ means this checkout's settings diverged — restore
`"typescript-lsp@claude-plugins-official": true` there, or re-enable it via `/plugin` in a session.

### ✗ codegraph MCP not enabled

[`.mcp.json`](../.mcp.json) registers the server (committed); enabling it is per-machine — add
`"codegraph"` to `enabledMcpjsonServers` in `.claude/settings.local.json`. Background in
[tooling/code-intelligence.md](tooling/code-intelligence.md).

### ✗ codegraph pins drifted

The version is pinned in three committed places — `CODEGRAPH_VERSION` in
[`.claude/hooks/lib/dev-env-checks.sh`](../.claude/hooks/lib/dev-env-checks.sh), the `codegraph`
server in [`.mcp.json`](../.mcp.json), and the `codegraph:*` scripts in
[`package.json`](../package.json) — align them to one version.

### ✗ codegraph: no index · index unreadable · built by an older codegraph

Run `npm run codegraph:init` in the checkout, or start a Claude Code session and let the
`SessionStart` hook rebuild it. Caveats (nested worktrees, the fresh-worktree race) are in
[tooling/code-intelligence.md](tooling/code-intelligence.md).

### ✗ docker missing · ✗ docker daemon not running · ✗ devcontainer CLI missing

Only the e2e/visual-regression suite needs these — see
[Host vs. devcontainer](#host-vs-devcontainer). Install and start Docker Desktop; the
devcontainer CLI ships as a devDependency, so a plain `npm ci` provides it.

### ✗ dependencies: not checked · ✗ codegraph: not checked · ✗ claude code integration: not checked · ✗ cannot enter …

Cascades, not separate problems: a missing prerequisite (node, npm, or jq — named in the line's
parentheses) kept that probe from running at all. Fix the root-cause ✗ in the entries above and
these clear on the next run. The `cannot enter` line means the checkout path itself was
inaccessible — re-run from the repo root.

### Verify-suite failures (`type:check`, `lint:check`, `format:check`, `build`)

Those are code problems, not environment ones — this section ends where the `running-preflight-checks`
skill (or [`package.json`](../package.json)'s scripts run by hand) takes over.
