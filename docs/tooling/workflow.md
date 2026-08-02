# How we run the workflow

The mechanics behind the [development workflow](../development-workflow.md). We implement it with
**OpenSpec** for the artifacts, **role-based Claude Code agents** for the phases, a few **skills** for
the repeatable procedures, and **scaled trunk-based** development (one change = one short-lived
branch = one PR). Each phase maps to a concrete tool:

| Phase                     | How it's run                                                                                     |
| ------------------------- | ------------------------------------------------------------------------------------------------ |
| Explore                   | `/opsx:explore` (or the `openspec-explore` skill)                                                |
| Propose                   | `spec-architect` agent / `/opsx:propose`                                                         |
| Review the proposal       | **you** read and approve the change folder                                                       |
| Implement                 | `frontend-engineer` agent / `/opsx:apply`, on a `<type>/<change-name>` branch                    |
| Verify                    | `frontend-qa-engineer` agent + `running-preflight-checks` skill                                  |
| Archive                   | `/opsx:archive` (on the branch, so the PR carries code + spec)                                   |
| Review the implementation | the pull request: CI runs the gates, `frontend-code-reviewer` surfaces findings, **you** approve |
| Integrate                 | merge the PR into `main`                                                                         |
| Deploy                    | `pipeline.yml` releases to production (the release gate is not yet configured)                   |

Nothing is automatic: each agent hands back to you, and **you** hold the three gates — the proposal
before any code, the implementation before it merges, and the production release.

## OpenSpec — the artifacts and commands

[OpenSpec](https://github.com/Fission-AI/OpenSpec) is the spec layer, driven from Claude Code through
slash commands:

- **`/opsx:explore "<topic>"`** — the optional Explore phase; never writes application code.
- **`/opsx:propose "<idea>"`** — reads the specs and codebase, then writes a change folder under
  `openspec/changes/<name>/`: `proposal.md` (why + scope), `tasks.md` (the work), an optional
  `design.md`, and spec deltas under `specs/`.
- **`/opsx:apply`** — implements the tasks against the agreed proposal.
- **`/opsx:archive`** — merges the change's spec deltas into the living `openspec/specs/` tree and
  moves the change to `openspec/changes/archive/`.

`openspec list` and `openspec validate` inspect changes and specs from the CLI.

```
openspec/
├── specs/      # the living record — how the site behaves today
├── changes/    # in-flight proposals; completed ones move to changes/archive/
└── schemas/    # the project-local workflow schema (see "How the proposer is customized")
```

## Branches, integration, and deploy

Each change is one short-lived branch and one pull request — the trunk-based half of the workflow.
The branch rules themselves (naming, worktrees, the push gate, squash-merging, branch deletion) are
in [branching-conventions](../development/conventions/branching-conventions.md); what the tooling
does with them:

- **Archive on the branch**, before opening the PR, so the pull request carries the code and the
  updated spec together — they land atomically.
- **The PR runs CI** ([`pipeline.yml`](../../.github/workflows/pipeline.yml)): `format:check` /
  `lint:check` / `type:check` / `specs:check` / `designmd:check` / `tokens:check` in the verify job,
  the build with its third-party-resource check (`thirdparty:check`), and the e2e suite — the same
  gates the `running-preflight-checks` and `testing-visual-regression` skills run locally.
- **`infra/` is unverified, in CI as well as locally.** The verify job has Terraform steps, but each
  `run:` starts its own shell, so its `cd infra/aws` and `cd infra/cloudflare` steps do not carry and
  `terraform fmt -check` and `terraform validate` execute against the repo root, where there is no
  Terraform to check. Terraform is not part of the local toolchain either, so a change under `infra/`
  reaches production having been read by a human and nothing else. Fixing the workflow (a
  `working-directory:` on each step) is a planned change.
- **Merge to `main` deploys.** No release branches; the deploy jobs ship to production on every merge
  — see [tech-stack](../tech-stack.md) for the targets.
- **The release gate** (the third human gate) is meant to be a required approval on the `Production`
  and `Cloudflare` GitHub Environments. It is not yet configured — a planned change.

## The agents (`.claude/agents/`)

Five role-based subagents, each with focused instructions and tool access. Invoke them with the
Agent/Task tool, or let the main session delegate.

- **`spec-architect`** (opus) — the architecture-aware proposer. Reads the specs, docs, and codebase
  and drives the propose flow to write a change (`proposal.md`, `tasks.md`, optional `design.md`,
  spec deltas). It deliberately does **not** carry the guardrails or the task structure itself — the
  `frontend-change` schema and `config.yaml` inject those (see below), so there's one source of truth.
  Writes only under `openspec/`; never application code.
- **`frontend-engineer`** (sonnet) — applies an agreed change's `tasks.md`: Astro/Preact/CSS to
  the repo's conventions (scoped `<style>` + `@reference`, token utilities, path aliases,
  `InternalLink`/`ExternalLink`). Surgical edits under `src/`; stops at the Verify step.
- **`frontend-qa-engineer`** (sonnet) — runs Playwright visual-regression + axe in **both** themes (in
  the devcontainer, so rendering matches CI), regenerates baselines for intentional changes, and
  reports diffs. Also drives an **agent-assisted manual preview** via the Playwright MCP (host Chrome):
  console clean, no theme flash, interactions, 375px — plus an **advisory perf/SEO audit** via the Chrome
  DevTools MCP (SEO/best-practices + Core Web Vitals, not a gate). It **ticks the automated Verify items
  in `tasks.md`** (visual/a11y, the gate, build), marking partial ones — e.g. _light only_ while dark is
  deferred. It reports the manual-preview findings but leaves that checkbox for the human at the review gate. Read-only
  on `src/`; hands styling bugs back to the engineer.
- **`frontend-code-reviewer`** (opus) — a read-only guardrail gate over the diff before commit, grouping
  findings as Blocking / Should-fix / Nits. Flags CSP, theming, interactivity-ladder, and convention
  violations the implementer missed.
- **`dependency-update-researcher`** (opus) — read-only research on a single npm dependency bump
  (current → target version): reads the changelog, checks how the repo actually uses the package, and
  returns a compatibility verdict with the concrete edits the bump would require. Invoked per
  minor/major bump by the `updating-dependencies` skill; never edits files or runs installs.

## The skills (`.claude/skills/`)

Procedure skills the agents (or you) invoke, alongside the `openspec-*` lifecycle skills.

**Naming convention:** skill names use **gerund form** — verb-ing plus object, e.g.
`checking-dev-env`, `running-preflight-checks` — per Anthropic's skill-authoring guidance
(preferred form; lowercase/hyphens only). Generated skills (`openspec-*`, `opsx:*`) keep their
vendored names. The `reviewing-skills` skill enforces this as checklist item `R6`.

- **`testing-visual-regression`** — run/update Playwright visual + a11y in light **and** dark (in the
  devcontainer), with the baseline-review steps. Knows the both-theme dependency on the dark
  Playwright projects.
- **`scaffolding-components`** — scaffold a new Astro component or Preact island to convention
  (placement, typed props, scoped token-driven styles, the right interactivity tier).
- **`running-preflight-checks`** — run the non-visual gate (`type:check` + `lint:check` +
  `format:check` + `specs:check` + `designmd:check` + `tokens:check` + `build` +
  `thirdparty:check`) and summarize failures. Matches CI's verify and build jobs, so a green gate
  predicts a green PR.
- **`checking-dev-env`** — audit host readiness (toolchain against the pins, dependencies, the
  Codegraph index, Claude Code integration, Docker/devcontainer) and turn any ✗ into an ordered fix
  guide sourced from development-environment.md's Troubleshooting section. Read-only — it never
  installs or fixes anything.
- **`committing-conventionally`** — stage the working tree and author one Conventional-Commits
  commit conforming to [commit-conventions](../development/conventions/commit-conventions.md),
  inferring type and scope from the changed paths.
- **`updating-dependencies`** — refresh npm dependencies: detect what's outdated, bucket into
  patch/minor/major, apply patches directly, and research minor/major bumps (one
  `dependency-update-researcher` run per bump) before recommending them. Delegates verification to
  `running-preflight-checks` and `testing-visual-regression`.
- **`reviewing-skills`** — review a skill (its SKILL.md, evals, and referenced files) against
  Anthropic's skill-authoring and prompting best practices plus the host project's conventions,
  producing a severity-ranked gap analysis and optionally applying approved fixes. It holds no
  reference to this repository and is written to be published as a plugin; how this project applies
  it — which documents its project-scoped criteria resolve to — is recorded in
  [conventions/skill-conventions.md](conventions/skill-conventions.md).
- **`writing-simplified-technical-english`** — revise agent-facing prose (skill bodies, agent
  definitions, OpenSpec artifacts, `docs/`) so an agent cannot read a sentence two ways, and check
  prose without editing it. It applies twelve conventions adapted from ASD-STE100 Issue 9 — the
  standard's ambiguity rules without its controlled dictionary or its sentence-length caps. It
  carries those conventions and their examples in its own bundle, holds no reference to this
  repository, and is written to be published as a plugin; how this project applies it is recorded in
  [conventions/writing-conventions.md](conventions/writing-conventions.md).

## MCP servers (`.mcp.json`)

Project-scoped and committed, so the team shares them:

- **`astro-docs`** (http) — Astro's documentation, for framework questions during propose/implement.
- **`playwright`** — Microsoft's `@playwright/mcp` (version pinned in the `npx` command), driving **host Chrome**
  (`--browser=chrome --headless --isolated`). The `frontend-qa-engineer` uses it for the manual-preview Verify
  item (theme flash, console, interactions, 375px); it also serves interactive exploration and
  locating selectors when authoring specs. Host rendering is **non-authoritative** — pixel baselines
  stay in the devcontainer suite. Approve it once in `/mcp`.
- **`chrome-devtools`** — Google's `chrome-devtools-mcp` (version pinned in the `npx` command), host Chrome headless.
  Performance traces (Core Web Vitals) and a `lighthouse_audit` (a11y / SEO / best-practices) against the
  local preview — the perf/SEO angle that axe and visual-regression don't cover. Local-preview scores
  are a **relative regression signal**, not prod-authoritative.
- **`codegraph`** — `@colbymchenry/codegraph` (version pinned in the `npx` command), a code-intelligence
  knowledge graph over the workspace, queried instead of grep/read loops. How it's pinned, enabled, and
  used across worktrees lives in [code-intelligence.md](code-intelligence.md).
- **`terraform`** — HashiCorp's official `terraform-mcp-server` (Docker, pinned `:0.5.2`, `--toolsets=registry`).
  Public Terraform Registry docs — AWS/Cloudflare provider and module lookup — for authoring `infra/`. Docs
  lookup only; CI still runs `fmt`/`validate`. Needs Docker running.
- **`github`** — GitHub's official `github-mcp-server` (Docker, pinned `:v1.2.0`), forced **read-only**
  (`GITHUB_READ_ONLY=1`) with the `context,repos,issues,pull_requests,actions` toolsets. Lets the agent
  inspect PRs, diffs, CI/Actions runs and logs, and issues during local work — e.g. debugging a red PR
  check. Read-only by design: it cannot comment, merge, or otherwise write. Needs Docker running and a
  token (see below).

### Administering the `github` server

Unlike the other servers, `github` needs a credential. Keep it read-only and out of version control.

- **Token.** Create a [fine-grained PAT](https://github.com/settings/personal-access-tokens) scoped to
  this repo, with an **expiry**, and **read-only** permissions: Metadata (required), Contents, Pull
  requests, Issues, Actions, Commit statuses. Nothing more — the server runs read-only and write actions
  are out of scope.
- **Where it lives.** Put it in `.claude/settings.local.json` (gitignored), whose `env` block Claude Code
  injects into the session. The variable carries a `BROKEN_ROBOT_XYZ_` prefix so per-project tokens can
  coexist (e.g. in the machine-global `~/.claude/settings.json`); `.mcp.json` maps it onto the
  `GITHUB_PERSONAL_ACCESS_TOKEN` name the server's Docker container expects:

    ```json
    { "env": { "BROKEN_ROBOT_XYZ_GITHUB_PERSONAL_ACCESS_TOKEN": "github_pat_…" } }
    ```

    Use this file — **not** `.zshrc` (a Dock/Finder launch of the desktop app doesn't source it) and **not**
    the committed `.claude/settings.json` (that would commit the secret). `.claude/settings.local.json` is
    ignored by the repo `.gitignore`. **Restart Claude Code** after adding or changing the token so the
    server reconnects.

- **Rotation.** The token is plaintext at rest and is visible to the session environment (including the
  agent's shell). Use an expiring PAT, rotate periodically, and revoke immediately (github.com → Settings
  → Developer settings) if it is ever exposed.
- **Bumping the image.** Check the latest release at `github.com/github/github-mcp-server/releases`,
  update the `:vX.Y.Z` tag in `.mcp.json`, and restart. You can't verify the tag with
  `docker manifest inspect` from inside the sandbox — its TLS interception breaks the registry handshake
  (`x509` / OSStatus error); the server itself runs on the **host** (launched by Claude Code, outside the
  sandbox), so it pulls normally.
- **Write access.** Out of scope by default. It would need a write-scoped PAT and dropping
  `GITHUB_READ_ONLY` — and any outward action (commenting, merging) is a deliberate, per-action decision,
  not something to enable ambiently.
- **Troubleshooting — `mcp__github__*` tools don't appear:** token unset in the environment Claude was
  launched with (most common — especially a GUI launch; confirm it's in `.claude/settings.local.json` and
  restart); Docker not running or the pinned image can't be pulled; or a config change that needs a
  restart to take effect.

## How the proposer is customized

Rather than living in the `spec-architect` prompt, the proposal/task shaping is baked into OpenSpec's
own customization, so the standard `/opsx:propose` flow (any agent, not just `spec-architect`) produces
it. One source of truth:

- **`openspec/config.yaml` → `context`** — the site's enduring guardrails, injected into every
  artifact's generation. Their canonical home is the project docs ([architecture](../architecture.md),
  [coding-conventions](../development/conventions/coding-conventions.md), [vision](../vision.md)); `config.yaml` points the
  propose flow at them rather than redefining them.
- **`openspec/schemas/frontend-change/`** — a project-local schema (forked from `spec-driven`). Its
  `templates/tasks.md` pre-seeds the mandatory **Verify** section, and its `tasks` instruction
  carries the **primitives-first** rule (a slice that uses a `.btn`/`.tag`/`.card`/… primitive must
  establish it first — the foundation shipped tokens only). `config.yaml` selects it via
  `schema: frontend-change`.

`openspec instructions tasks --change <name>` prints the composed result (template + schema
instruction + context). The seeded Verify section is:

```markdown
## N. Verify

- [ ] Visual + a11y snapshots pass in **both themes** for every touched view (testing-visual-regression skill)
- [ ] All eight gate steps pass — `type:check`, `lint:check`, `format:check`, `specs:check`, `designmd:check`, `tokens:check`, `build`, `thirdparty:check` (running-preflight-checks skill)
- [ ] Manual preview: no theme flash, interactions work, console clean, responsive at 375px
```

This shapes _generation_. Structural validity is also **enforced** in CI: the `verify` job runs
`npm run specs:check` (`openspec validate --all --strict`), so malformed proposals or spec deltas
fail a PR. The _content_ rules above (the Verify section, primitives-first) are generation-shaped
only — not hard-checked — so the `frontend-code-reviewer` and your review are the backstop. The schema
fork is OpenSpec-experimental: it's pinned in the repo and may need reconciling when OpenSpec updates
its upstream templates.

## Setup

OpenSpec is pinned as a **devDependency** (`@fission-ai/openspec`), so `npm ci` installs it for both
CI and local use, and `npm run specs:check` runs that pinned version — it's what CI gates on. It is
dev-only (not part of the build or runtime), and `audit:check` omits devDependencies.

For **interactive** authoring the `opsx` slash commands call `openspec` directly on your `PATH`, so
also install the CLI on the host (`npm install -g @fission-ai/openspec`, Node ≥ 20.19). Its Claude
Code integration lives in `.claude/skills/`; run `openspec init --tools claude` (or `openspec update`
after a CLI upgrade) to install or refresh it. The customized schema (`openspec/schemas/frontend-change/`)
and the rest of the `openspec/` tree are committed to the repository.

The local sandbox that constrains the agents is documented in [sandbox.md](sandbox.md).
