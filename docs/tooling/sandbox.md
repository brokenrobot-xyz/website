# Claude Code sandbox & permissions

How this repository constrains the Claude Code agent: what it may read, write, run, and reach on
the network, and why the rules are shaped the way they are. The configuration lives in
[`.claude/settings.json`](../../.claude/settings.json); this document explains the intent so the
config can stay free of comments (it's strict JSON) without becoming a set of magic incantations.

## Two independent layers

Two separate mechanisms enforce the rules, and it helps to keep them apart:

1. **`permissions`** (harness level) — decides which tool calls auto-run, prompt, or are blocked.
   The `permissions.deny` list is the real safety net for the irreversible and outbound actions:
   `git push` / `fetch` / `pull` / `clone`, `gh`, `rm -rf`, `git reset --hard`, remote edits, and
   `python`. These hold regardless of the OS sandbox.
2. **`sandbox`** (OS level) — what any spawned process can physically read, write, or reach on the
   network. This is the `denyRead` / `allowRead` / `denyWrite` / `allowWrite` / `network` block.

## Filesystem model: locked writes, open reads, denied secrets

The read and write rules are deliberately **asymmetric** — writes are where damage happens, so
that's where the isolation sits:

- **Writes are default-deny.** Only an explicit `allowWrite` list is writable: the project (`.`),
  the repo's `.git` (so git works in a worktree — see below), the npm cache (`~/.npm`), the buildx
  state dir (`~/.docker/buildx`, for the devcontainer build — `~/.docker/config.json` stays
  read-only), the OS temp area, and a couple of tool-pref dirs. A process cannot modify anything
  outside the project.
- **Reads are open, except secrets.** `denyRead` lists a focused set of credential locations
  (`~/.ssh`, `~/.aws`, `~/.gnupg`, `~/.kube`, `~/.netrc`, `~/.npmrc`, `~/.config/gh`,
  `~/.config/gcloud`, `~/.git-credentials`, `~/Library/Keychains`); everything else is readable.
  The list is the obvious extension point — add a path here to deny it.

### Why reads are open rather than locked to the project

Claude Code runs in a **worktree nested at `.claude/worktrees/<name>/`**, and the Node toolchain
constantly walks _up_ the directory tree (browserslist hunting for a config, ESLint cascading
configs, `tsc` looking for `tsconfig`, …). With the whole home directory denied, every such walk
hit `EPERM` on a parent directory it couldn't read, breaking `type:check`, `build`, and `lint`.

The choice was: scatter a per-tool workaround into the **application's** config for each walker, or
move the isolation to the layer that actually matters. We chose the latter — reads are open (minus
secrets), and **writes** carry the isolation. This keeps the application config pristine: the only
related change is `root: true` in [`.eslintrc.json`](../../.eslintrc.json), which is a correct,
standard setting for any project-root ESLint config (it stops config cascade into ancestor
directories) — not a sandbox workaround.

This does trade away read-isolation of non-secret files. The trade is acceptable here because the
Docker socket (below) already makes the filesystem sandbox a guard against accidents rather than a
hard wall — so denying non-secret reads bought little while costing constant friction. The
protections that carry real weight are unchanged: **writes locked to the project, the network
allow-list, the `permissions.deny` list, and secrets denied.**

### Precedence: allow wins

`sandbox.filesystem` is **allow-wins, not longest-match.** If a path sits under an `allowRead`
entry, it stays readable even if a more specific `denyRead` entry also matches it. That's why the
secret denials are absolute: nothing in `allowRead` covers them (it only lists `.`). The corollary
— **don't put a secret deny _inside_ an allowed directory and expect it to take effect.** To deny
something within an allowed tree (e.g. `.env` inside the project), use a `permissions.deny`
`Read(<path>)` rule, which _does_ override allows. That is how `.env` stays blocked inside the
otherwise-readable project.

## The `../../../.git` carve-out

When Claude Code runs in a worktree, git's real database — objects, refs, this worktree's index and
HEAD — lives in the **main repo's `.git`**, not in the worktree (which holds only a one-line
pointer file). Reads of it are covered by the open read policy; **writes** need an explicit grant,
so `../../../.git` appears in `allowWrite`: from the worktree cwd, the repo root is exactly three
levels up.

It's deliberately **relative**, so the committed config is portable across machines and checkout
locations. In a normal (non-worktree) checkout the entry is a harmless no-op — `.` already covers
`./.git`, and `../../../.git` points above the repo at nothing relevant.

## The real trust boundary: the Docker socket

`network.allowAllUnixSockets: true` exposes the Docker socket, and **the Docker socket is
effectively host-root**: anything that can talk to it can launch a container that bind-mounts the
whole home directory as root and read or write anything — bypassing every filesystem rule above.

Docker is kept **deliberately**. The end-to-end tests run Playwright inside a devcontainer so the
visual-regression snapshots render in a consistent Linux environment that matches CI; running them
on the macOS host would produce different pixel output and break the tight snapshot tolerance
(`maxDiffPixelRatio: 0.01`). That is a load-bearing reason, not incidental Docker use.

The consequence to hold honestly: **with Docker enabled, the filesystem sandbox is a guard against
accidents, not a hard wall against a compromised or injected agent.** The real security rests on
the `permissions.deny` list, the `network.allowedDomains` allow-list, and the author reviewing what
the agent does. This is also _why_ opening non-secret reads (above) costs little.

## What protects what (summary)

- **Home secrets** (`~/.ssh`, `~/.aws`, `~/.npmrc`, the keychain, …) — the `denyRead` secret list,
  applied to every spawned process.
- **Secrets inside the project** (`.env*`) — `permissions.deny: Read(...)`, which overrides the
  readable project tree.
- **Writes outside the project** — default-denied; only the `allowWrite` list is writable.
- **Irreversible / outbound actions** (`git push` / `fetch`, `gh`, `rm -rf`, `python`) — the
  `permissions.deny` list.
- **Network egress** — the `network.allowedDomains` allow-list.
- **Git writes inside a worktree** — the `allowWrite` carve-out `../../../.git`.

## Operational notes

- A fresh worktree has no `node_modules`. Installing works once the npm cache is reachable; `~/.npm`
  is in both the read (via the open policy) and `allowWrite` lists, so `npm ci` / `npx` work
  normally.
- **`npm ci` cannot replace an existing `node_modules` here.** It wipes the tree before extracting,
  and the harness denies _unlinking_ `.vscode/settings.json` — a path a transitive dependency ships
  inside its own tarball. Creating it during extraction is fine, so a checkout with no
  `node_modules` installs cleanly and one with a tree fails partway, leaving it half-removed. The
  deny is Claude Code's own (it guards editor config as a persistence vector), not something
  `.claude/settings.json` declares, so it cannot be relaxed from this repo. The `SessionStart` hook
  therefore runs `npm ci` only when there is no tree and `npm install` to reconcile one that exists;
  by hand, reach for `npm install` after a lockfile change.
- These frictions are **local-only**. A normal checkout (CI, plain `git clone`) is not nested under
  a denied home, so `npm run format:check` / `type:check` / `lint:check` / `build` all run there
  without any of this — which is why none of the fixes live in application config.
- **Running the devcontainer e2e from the agent** works (via the `dc:*` npm scripts):
  `network.allowedDomains` includes `containers.dev` / `ghcr.io` /
  `pkg-containers.githubusercontent.com` / `mcr.microsoft.com` (the devcontainer CLI's direct
  feature/registry fetches — image layers and in-container installs go through the Docker daemon,
  outside the sandbox), and `~/.docker/buildx` is writable for buildx state. A worktree has no
  `.env` (which normally sets `BROKENROBOT_PORT`), so set it to `8080` (matching CI) when running the suite. See the
  `testing-visual-regression` skill.
- **The Playwright MCP** (`@playwright/mcp`, in `.mcp.json`) runs on the **host** with system Chrome
  (`--browser=chrome --headless --isolated`, so no Chromium download) and browses the local preview at
  `http://localhost:${BROKENROBOT_PORT}` — both already allowed. It backs the manual-preview Verify
  checks and interactive browsing; macOS rendering is non-authoritative, so pixel baselines stay in the
  devcontainer suite.
- **The `chrome-devtools` and `terraform` MCP servers** share that boundary: `chrome-devtools` drives host
  Chrome like Playwright; `terraform` runs as a short-lived Docker container (image pulled daemon-side) that
  queries the public Terraform Registry. Like all MCP servers they're launched by Claude Desktop, not the
  bash sandbox.

## The dev server lock file

Astro 7 detaches `astro dev` automatically when it detects an AI coding agent, and manages the
result through `astro dev status` / `logs` / `stop`, backed by a lock file at `.astro/dev.json`
(see [development-environment](../development-environment.md#the-dev-server-in-the-background)).

**Under the bash sandbox on the host, that lock file is not written.** The server starts and
serves correctly — `/_astro/status` answers, `.astro/dev.log` is written — but `astro dev status`
reports "No dev server is running", so `stop` cannot reach it. The sandbox also denies signalling
the process, so an agent cannot `kill` it either: the server survives until stopped from a real
terminal.

This is the sandbox, not Astro. The same auto-detect path (`CLAUDECODE=1`, no `--background`
flag) writes the lock file and works end to end inside the devcontainer, as does an explicit
`--background`. The precise mechanism is unknown — writes to `.astro/` are clearly not blocked
wholesale, since `dev.log` lands there.

Practical consequences for an agent working on the host:

- Prefer **`npm run serve`** (`astro preview`) when you just need the built site — it is what the
  Playwright suite uses, and it runs in the foreground under the agent's control.
- If you do start `astro dev`, **record the PID from its startup line**; it is the only handle you
  will get. Hand it to the user to `kill` rather than assuming `astro dev stop` will work.
- Inside the devcontainer the lifecycle commands behave normally.

## Possible future hardening

Neither is needed today; both are recorded so the trade-offs are explicit.

- **Scope the Docker socket** with a socket proxy that exposes only the container-lifecycle API the
  tests need (no host bind-mounts, no `--privileged`), turning "host root" into "can run test
  containers".
- **Move e2e into CI** (the same Linux Playwright image), so the test run is automatic on every
  pull request and the local agent rarely needs the Docker socket at all.
