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
| Deploy                    | `deploy.yml` releases to production (the release gate is not yet configured)                     |

Nothing is automatic: each agent hands back to you, and **you** hold the three gates — the proposal
before any code, the implementation before it merges, and the production release.

## OpenSpec — the artifacts and commands

[OpenSpec](https://github.com/Fission-AI/OpenSpec) is the spec layer, driven from Claude Code through
slash commands:

- **`/opsx:explore "<topic>"`** — the optional Explore phase; never writes application code.
- **`/opsx:propose "<idea>"`** — reads the specs and codebase, then writes a change folder under
  `openspec/changes/<name>/`: `proposal.md` (why + scope), `tasks.md` (the work), an optional
  `design.md`, and spec deltas under `specs/`.
- **`/opsx:update`** — revises an existing change's plan in place and reconciles the sibling
  artifacts, without crossing into implementation. Use it when review moves the goalposts.
- **`/opsx:apply`** — implements the tasks against the agreed proposal.
- **`/opsx:sync`** — reconciles a change's spec deltas with what was actually built, before archiving.
- **`/opsx:archive`** — merges the change's spec deltas into the living `openspec/specs/` tree and
  moves the change to `openspec/changes/archive/`.

`openspec list`, `openspec status --all`, and `openspec validate` inspect changes and specs from the CLI;
`openspec show <change> --diff` renders a change's delta requirements against the main spec they modify.

Two per-change markers live in `openspec/changes/<name>/.openspec.yaml` and change what validation
and archive will accept:

- **`skip_specs: true`** — the change deliberately has no spec deltas (a pure refactor, tooling, docs,
  or a dependency bump). Without it `openspec validate` rejects a zero-delta change. Reach for it
  instead of inventing a requirement to satisfy the validator; specs describe behavior, so if no
  behavior changes, no spec should.
- **`retire_capabilities: true`** — the change's `REMOVED` entries take a capability's last
  requirement, and archive should delete that capability's `spec.md` rather than abort. It is opt-in
  because the deletion is recoverable only from git.

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
- **CI is two workflows: one that checks, one that ships.**
  [`pipeline.yml`](../../.github/workflows/pipeline.yml) holds every check as a named job — **Verify
  site** (`format:check` / `lint:check` / `type:check` / `specs:check` / `designmd:check` /
  `tokens:check`), **Verify Terraform**, **Build site** (with `thirdparty:check`), and **Test site**
  (the e2e suite) — the same gates the `running-preflight-checks` and `testing-visual-regression`
  skills run locally. It runs on every pull request **and** on every push to `main`, unfiltered, so
  a merge always gets the full picture rather than only the parts a path filter thought were
  affected. [`deploy.yml`](../../.github/workflows/deploy.yml) ships the result.
- **`infra/` is checked, but only shallowly.** **Verify Terraform** is one job with a
  `working-directory` of `infra/cloudflare`, running `fmt -check -recursive`, `init -backend=false`,
  and `validate`; `running-preflight-checks` runs the same `fmt` and `validate` locally as its
  `terraform:check` step, against the devcontainer's Terraform 1.15.8 pin. What neither covers is
  what an apply would do — no plan runs, and the apply itself belongs to Terraform Cloud — so a
  change that is well-formed, valid, and wrong still reaches production on a human read alone.
- **Merge to `main` deploys, but only on a wholly green Pipeline.** No release branches.
  `deploy.yml` triggers on Pipeline finishing successfully on `main` and takes the `dist/` artifact
  from that run, so the bytes deployed are the bytes tested. A workflow only concludes `success`
  when every job did, so keeping the Terraform check inside Pipeline is what makes one trigger the
  whole gate: anything wrong on `main`, nothing ships. Splitting that check back into its own
  workflow would silently reopen the hole. See [tech-stack](../tech-stack.md) for the target.
- **The release gate** (the third human gate) is meant to be a required approval on the `Cloudflare`
  GitHub Environment. It is not yet configured — a planned change.

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

## The skills (`.claude/skills/` and marketplace plugins)

Procedure skills the agents (or you) invoke, alongside the `openspec-*` lifecycle skills. Most are
committed under `.claude/skills/`; three (marked **external plugin** below) live in
[brokenrobot-xyz/agent-skills](https://github.com/brokenrobot-xyz/agent-skills) and are installed
via the marketplace config in `.claude/settings.json` (`extraKnownMarketplaces` +
`enabledPlugins`).

**Naming convention:** skill names use **gerund form** — verb-ing plus object, e.g.
`checking-dev-env`, `running-preflight-checks` — per Anthropic's skill-authoring guidance
(preferred form; lowercase/hyphens only). Generated skills (`openspec-*`, `opsx:*`) keep their
vendored names. The `reviewing-claude-skills` skill enforces this as checklist item `R6`.

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
- **`committing-conventionally`** (external plugin) — stage the working tree and author one
  Conventional-Commits commit conforming to
  [commit-conventions](../development/conventions/commit-conventions.md), inferring type and scope
  from the changed paths. The plugin also carries the commit-message deny-hook; both read the
  vocabulary from [`.brokenrobot-xyz/commits.json`](../../.brokenrobot-xyz/commits.json).
- **`updating-dependencies`** — refresh npm dependencies: detect what's outdated, bucket into
  patch/minor/major, apply patches directly, and research minor/major bumps (one
  `dependency-update-researcher` run per bump) before recommending them. Delegates verification to
  `running-preflight-checks` and `testing-visual-regression`.
- **`reviewing-claude-skills`** (external plugin) — review a skill (its SKILL.md, evals, and
  referenced files) against Anthropic's skill-authoring and prompting best practices plus the host
  project's conventions, producing a severity-ranked gap analysis and optionally applying approved
  fixes. It holds no reference to this repository; how this project applies it — which documents
  its project-scoped criteria resolve to — is recorded in
  [conventions/skill-conventions.md](conventions/skill-conventions.md).
- **`writing-simplified-technical-english`** (external plugin) — revise agent-facing prose (skill
  bodies, agent definitions, OpenSpec artifacts, `docs/`) so an agent cannot read a sentence two
  ways, and check prose without editing it. It applies twelve conventions adapted from ASD-STE100
  Issue 9 — the standard's ambiguity rules without its controlled dictionary or its sentence-length
  caps. It carries those conventions and their examples in its own bundle and holds no reference to
  this repository; how this project applies it is recorded in
  [conventions/writing-conventions.md](conventions/writing-conventions.md).

## MCP servers (`.mcp.json`)

Project-scoped and committed, so the team shares them. Every server's version is pinned in
[`.mcp.json`](../../.mcp.json) — in the `npx` command for the node servers, in the image tag for the
Docker ones — and is **deliberately not repeated here**. That file is the single source of truth;
a number copied into prose only rots. Version numbers below name a release where behaviour
_changed_, which stays true no matter what is pinned today.

- **`astro-docs`** (http) — Astro's documentation, for framework questions during propose/implement.
- **`playwright`** — Microsoft's `@playwright/mcp`, driving **host Chrome**
  (`--browser=chrome --headless --isolated`). The `frontend-qa-engineer` uses it for the manual-preview Verify
  item (theme flash, console, interactions, 375px); it also serves interactive exploration and
  locating selectors when authoring specs. Host rendering is **non-authoritative** — pixel baselines
  stay in the devcontainer suite. Approve it once in `/mcp`.
- **`chrome-devtools`** — Google's `chrome-devtools-mcp`, host Chrome headless.
  Performance traces (Core Web Vitals) and a `lighthouse_audit` (a11y / SEO / best-practices) against the
  local preview — the perf/SEO angle that axe and visual-regression don't cover. Local-preview scores
  are a **relative regression signal**, not prod-authoritative.
- **`codegraph`** — `@colbymchenry/codegraph`, a code-intelligence
  knowledge graph over the workspace, queried instead of grep/read loops. How it's pinned, enabled, and
  used across worktrees lives in [code-intelligence.md](code-intelligence.md).
- **`terraform`** — HashiCorp's official `terraform-mcp-server` (Docker, `--toolsets=registry`).
  Public Terraform Registry docs — Cloudflare provider and module lookup — for authoring `infra/`. Docs
  lookup only; CI still runs `fmt`/`validate`. Needs Docker running.
- **`github`** — GitHub's official `github-mcp-server` (Docker), forced **read-only**
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
it. The split is deliberate: **all project-specific prose lives in `openspec/config.yaml`** (upgrade-proof
— OpenSpec's supported extension points), and **the schema fork stays upstream-verbatim except two
template seeds** (cheap to reconcile):

- **`openspec/config.yaml` → `context`** — the site's enduring guardrails, injected into every
  artifact's generation. Their canonical home is the project docs ([architecture](../architecture.md),
  [coding-conventions](../development/conventions/coding-conventions.md), [vision](../vision.md)); `config.yaml` points the
  propose flow at them rather than redefining them.
- **`openspec/config.yaml` → `rules`** — per-artifact constraints, appended to that artifact's
  composed instructions as a `<rules>` block: the proposal's **Non-Goals** and blog-prose scope
  check, the specs domain flavor, and the tasks **primitives-first** rule (a slice that uses a
  `.btn`/`.tag`/`.card`/… primitive must establish it first — the foundation shipped tokens only).
- **`openspec/schemas/frontend-change/`** — a project-local schema. Its `schema.yaml` is a verbatim
  copy of the built-in `spec-driven` schema except the `name:` and `description:` lines, and only
  two of its templates diverge: `templates/proposal.md` adds the **Non-Goals** heading and
  `templates/tasks.md` pre-seeds the mandatory **Verify** group. `config.yaml` selects it via
  `schema: frontend-change`. (OpenSpec has no schema inheritance — a project schema must be a
  complete copy, which is why the fork exists at all: templates only load from the schema's own
  directory.)
- **`openspec/config.yaml` → `operations`** — advisory guidance attached to the **apply** and
  **archive** operations only, so branch/hand-off rules reach `/opsx:apply` and delta-merge rules
  reach `/opsx:archive` without padding every artifact's context. Read it back with
  `openspec instructions apply|archive`. Each `rules`/`guidance` entry must be a **string**: quote
  any bullet containing a `key: value` pair, or YAML parses it as a map and OpenSpec silently drops
  the whole list with a warning on stderr.

`openspec instructions tasks --change <name>` prints the composed result (template + schema
instruction + context). The seeded Verify section is:

```markdown
## N. Verify

- [ ] Visual + a11y snapshots pass in **both themes** for every touched view (testing-visual-regression skill)
- [ ] All eight gate steps pass — `type:check`, `lint:check`, `format:check`, `specs:check`, `designmd:check`, `tokens:check`, `build`, `thirdparty:check` (running-preflight-checks skill)
- [ ] Manual preview: no theme flash, interactions work, console clean, responsive at 375px
```

This shapes _generation_. Structural validity is also **enforced** in CI: the `verify` job runs
`npm run specs:check` (`openspec validate --all --strict`, then `openspec validate --archived`), so
malformed proposals or spec deltas fail a PR, as does an archived change with unticked tasks. The _content_ rules above (the Verify section, primitives-first) are generation-shaped
only — not hard-checked — so the `frontend-code-reviewer` and your review are the backstop.

The schema fork is OpenSpec-experimental and needs reconciling when OpenSpec updates its upstream
schema. Because the fork is upstream-verbatim, that's mechanical (last done against **1.11.0**):

1. `cp node_modules/@fission-ai/openspec/schemas/spec-driven/schema.yaml openspec/schemas/frontend-change/schema.yaml`,
   then restore the `name: frontend-change` and `description:` lines.
2. Diff the four templates against `node_modules/@fission-ai/openspec/schemas/spec-driven/templates/`;
   `design.md` and `spec.md` should stay identical, `proposal.md` keeps only the added **Non-Goals**
   section, `tasks.md` keeps only the appended **Verify** group and its keep-last comment.
3. `config.yaml` (`context`/`rules`/`operations`) is untouched by upgrades — but skim the release
   notes for new config capabilities worth adopting.
4. Verify with a throwaway change: `openspec new change probe`, then
   `openspec instructions proposal|tasks --change probe` must show the `<rules>` block and the
   seeded Verify group; delete the change and run `npm run specs:check`.

## Setup

OpenSpec is pinned as a **devDependency** (`@fission-ai/openspec`), so `npm ci` installs it for both
CI and local use, and `npm run specs:check` runs that pinned version — it's what CI gates on. It is
dev-only (not part of the build or runtime), and `audit:check` omits devDependencies.

For **interactive** authoring the `opsx` slash commands call `openspec` directly on your `PATH`, so
also install the CLI on the host (`npm install -g @fission-ai/openspec`, Node ≥ 20.19). Its Claude
Code integration lives in `.claude/skills/` and `.claude/commands/opsx/`; run
`openspec init --tools claude` (or `openspec update` after a CLI upgrade) to install or refresh it.
The customized schema (`openspec/schemas/frontend-change/`) and the rest of the `openspec/` tree are
committed to the repository.

Two settings live in the **machine-global** config (`~/.config/openspec/config.json`), not the repo,
so each machine sets them once:

- **`openspec config profile core`** — installs the full six-workflow set (propose, explore, apply,
  update, sync, archive). Without it a machine that once generated a subset is pinned to a `custom`
  profile, and `openspec update` keeps regenerating only those workflows.
- **`openspec config set telemetry.enabled false`** — turns off anonymous telemetry **and** the npm
  update check `openspec update` otherwise performs. Worth setting: the update check writes to that
  global config on every run, which fails outright under the agent sandbox (see
  [sandbox.md](sandbox.md)).

Regenerating the Claude integration is a **host** job for the same reason — the sandbox denies writes
to both `.claude/skills/` and `~/.config/`, so `openspec update` has to be run by you, not the agent.

The local sandbox that constrains the agents is documented in [sandbox.md](sandbox.md).
