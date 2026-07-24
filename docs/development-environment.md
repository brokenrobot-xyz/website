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
git clone git@github.com:mezeitamas/brokenrobot.xyz.git
cd brokenrobot.xyz
npm ci    # reproducible install from the committed package-lock.json
npm start # dev server on http://localhost:4321
```

Use `npm ci` (not `npm install`) for a clean, lockfile-exact install. The common scripts:
`npm run type:check`, `npm run lint:check`, `npm run format:check`, `npm run build` — see
[`package.json`](../package.json) for the full list.

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
dependencies when `node_modules/` is missing, then builds or refreshes the Codegraph index. Outside a
session, run `npm ci` yourself.

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
