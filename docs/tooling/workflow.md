# How we run the workflow

The mechanics behind the [development workflow](../development-workflow.md). We implement it with
**OpenSpec** for the artifacts, **role-based Claude Code agents** for the phases, a few **skills** for
the repeatable procedures, and **scaled trunk-based** development (one change = one short-lived
branch = one PR).

## The process

One owner per step, skills as the owner's capabilities, every output a file. A step starts from the
files the step before it left on disk and its delegation message, and nothing else, so that stale
reasoning and rejected directions cannot steer it. The main session is the router: it delegates
each step to its owner, relays the owner's short message, and stops at every **you** row. The
`coordinating-changes` skill is the runbook for this table, with one entry point for starting a
change and one for applying a named one.

| Step                  | Input                                        | Output on disk                                                  | Owner                        | Skills                                                  |
| --------------------- | -------------------------------------------- | --------------------------------------------------------------- | ---------------------------- | ------------------------------------------------------- |
| Explore               | the idea, the codebase                       | `brief.md`                                                      | main session, with **you**   | `openspec-explore` (`/opsx:explore`)                    |
| Propose               | the brief                                    | proposal, specs, design, tasks                                  | `frontend-planner`           | `openspec-propose`, `openspec-update-change`            |
| Proposal review       | the planning artifacts, the brief, the specs | `review.md`                                                     | `frontend-proposal-reviewer` | none                                                    |
| _Gate_                | the change folder                            | your approval                                                   | **you**                      |                                                         |
| Implement             | tasks, the rest of the folder                | code and ticked tasks, on a `<type>/<change-name>` branch       | `frontend-engineer`          | `openspec-apply-change`, `scaffolding-components`       |
| Verify                | the code, the tasks Verify group             | `verify-report.md`, ticked Verify items                         | `frontend-qa-engineer`       | `testing-visual-regression`, `running-preflight-checks` |
| Implementation review | the diff, the change folder, the conventions | `code-review.md`                                                | `frontend-code-reviewer`     | none                                                    |
| _Gate_                | the two reports, the diff                    | your approval, the manual-preview tick                          | **you**                      |                                                         |
| Commit the code       | the approved diff, the touched-files list    | a commit                                                        | a general-purpose subagent   | `committing-conventionally`                             |
| Archive               | the change folder                            | merged specs, the archived folder                               | main session                 | `openspec-archive-change` (`/opsx:archive`)             |
| _Look_                | the merged specs                             | your go                                                         | **you**                      |                                                         |
| Commit the specs      | the archive diff                             | a commit                                                        | a general-purpose subagent   | `committing-conventionally`                             |
| Integrate             | the pull request; CI runs the gates          | the merge into `main`                                           | **you**                      |                                                         |
| Deploy                | the merge                                    | the production release (the release gate is not yet configured) | `deploy.yml`                 |                                                         |

The three report files — `review.md`, `verify-report.md`, `code-review.md` — live in the change
folder, so archive moves them with it and the folder is the change's audit log. `review.md` is a
declared artifact that `apply` requires, so OpenSpec refuses to apply a change nobody reviewed; it
proves a review ran, not that it passed, so the proposal is reviewed again after every Update. The
other two are undeclared, because declaring them would put Verify and the implementation review
inside the artifact graph, where `apply` would demand them before the code they describe exists.

Nothing is automatic: each agent hands back to you, and **you** hold the three gates — the proposal
before any code, the implementation before it merges, and the production release — plus the look at
the merged specs before they are committed. Both review loops keep you in them: findings come to
you, you decide which go back, and the reviewer runs again. The shaping the planner applies lives in
OpenSpec's own configuration — see [How the proposer is customized](#how-the-proposer-is-customized).

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
  site**, **Verify infrastructure**, **Verify tooling**, **Build site**, and **Test site**. Which check
  belongs to which job is in
  [checks.md](../development/checks.md#the-ci-pipeline); it is close to what the
  `running-preflight-checks` and `testing-visual-regression` skills run locally, but CI runs more. It runs on every pull request **and** on every push to `main`, unfiltered, so
  a merge always gets the full picture rather than only the parts a path filter thought were
  affected. [`deploy.yml`](../../.github/workflows/deploy.yml) ships the result.
- **`infra/` is checked, but only shallowly.** **Verify infrastructure** is one job with a
  `working-directory` of `infra/cloudflare`, running `fmt -check -recursive`, `init -backend=false`,
  and `validate`; `running-preflight-checks` runs the same `fmt` and `validate` locally as its
  `terraform:check` step, against the devcontainer's Terraform 1.16.0 pin. What neither covers is
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

Six role-based subagents, each with focused instructions and tool access. The `coordinating-changes`
skill delegates to them step by step; you can also invoke one directly with the Agent/Task tool.
The three that review or verify each write one report file into the change folder and hold
themselves to that path by instruction, the way their unrestricted `Bash` grant is already held —
the diff at the gate is the check.

- **`frontend-planner`** (opus) — writes a change's planning artifacts from its `brief.md` by driving
  the vendored `openspec-propose` skill inside its own context, and revises them with
  `openspec-update-change` when review findings come back. Its input is the brief plus the disk, by
  design: it never sees the Explore conversation. It cannot ask, so a question that would change
  scope comes back in its report, the answer is appended to the brief's **Answers** section, and
  the same planner is resumed. Writes only under the change folder; never edits code.
- **`frontend-proposal-reviewer`** (opus) — attacks the change folder before you read it: untestable
  scenarios, requirements that contradict the living specs, tasks that use a primitive nobody
  establishes, a missing tier decision, unnamed scope, a `skip_specs` claim that hides a behaviour
  change. The attack list lives in the schema's `review.md` template. Writes the change's
  `review.md` — the declared artifact `apply` requires — and nothing else.
- **`frontend-engineer`** (sonnet) — implements an agreed change by driving `/opsx:apply` inside its
  own context, so a long implementation's file reads, lint output, and edits stay out of the main
  session. It carries no guardrails of its own: `openspec instructions apply` returns both the
  `context` block and the `operations.apply` guidance from `openspec/config.yaml`, and the agent
  reads `architecture.md` and the coding conventions before its first edit. The trade is deliberate:
  a subagent cannot ask, because Claude Code strips `AskUserQuestion` from every subagent, so an
  ambiguous task comes back **unticked, with the question**, and the main thread re-delegates with
  the answer. Ticks tasks as it goes; stops at the Verify group; never commits.
- **`frontend-qa-engineer`** (sonnet) — owns all of Verify. Runs Playwright visual-regression + axe
  in **both** themes (in the devcontainer, so rendering matches CI), regenerates baselines for
  intentional changes through `test:e2e:update`, and runs the preflight gate through
  `running-preflight-checks`. Also drives an **agent-assisted manual preview** via the Playwright MCP
  (host Chrome): console clean, no theme flash, interactions, 375px — plus an **advisory perf/SEO
  audit** via the Chrome DevTools MCP (SEO/best-practices + Core Web Vitals, not a gate). Writes the
  change's `verify-report.md` and **ticks the Verify items its own evidence supports** in `tasks.md`,
  marking partial ones — e.g. one theme covered and the other not run — as unsupported. The
  manual-preview checkbox stays yours at the review gate. Hands styling bugs back to the engineer.
- **`frontend-code-reviewer`** (opus) — the guardrail gate over the diff, at either placement: the
  working tree before commit, or the branch at the pull-request gate (the delegation says which, and
  the agent reads `git diff HEAD` or `git diff main...HEAD` accordingly). Groups findings as
  Blocking / Should-fix / Nits in the change's `code-review.md`, and writes nothing else. Flags CSP,
  theming, interactivity-ladder, and convention violations the implementer missed.
- **`dependency-update-researcher`** (external plugin, from `frontend-toolkit`) — read-only research
  on a single npm dependency bump (current → target version): reads the changelog, checks how the
  repo actually uses the package, and returns a compatibility verdict with the concrete edits the
  bump would require. Invoked per selected bump by the `updating-dependencies` skill; never edits
  files or runs installs.

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

- **`coordinating-changes`** — the runbook for [the process](#the-process): two entry points, start
  a change and apply a named change, each naming the owner, input files, output file, and human
  stops of every step, plus the rules that belong to no single agent — the main session never
  invokes the three procedure skills below during a change, a planner question is answered through
  the brief, the proposal is reviewed again after every Update, and commits are delegated and each
  follows a human stop. Runs in the main session by design: it routes, so it has nothing to isolate.
  `CLAUDE.md` carries one pointer line to it, the backstop for a missed trigger.
- **`testing-visual-regression`** — run/update Playwright visual + a11y in light **and** dark (in the
  devcontainer), with the baseline-review steps. Knows the both-theme dependency on the dark
  Playwright projects.
- **`scaffolding-components`** — scaffold a new Astro component or Preact island to convention
  (placement, typed props, scoped token-driven styles, the right interactivity tier).
- **`running-preflight-checks`** — run the non-visual gate
  ([checks.md](../development/checks.md#the-preflight-gate)) and summarize failures. Matches CI's
  verify and build jobs, so a green gate predicts a green PR.
- **`checking-dev-env`** — audit host readiness (toolchain against the pins, dependencies, the
  Codegraph index, Claude Code integration, Docker/devcontainer) and turn any ✗ into an ordered fix
  guide sourced from development-environment.md's Troubleshooting section. Read-only — it never
  installs or fixes anything.
- **`committing-conventionally`** (external plugin) — stage the working tree and author one
  Conventional-Commits commit conforming to
  [commit-conventions](../development/conventions/commit-conventions.md), inferring type and scope
  from the changed paths. The plugin also carries the commit-message deny-hook; both read the
  vocabulary from [`.brokenrobot-xyz/commits.json`](../../.brokenrobot-xyz/commits.json).
- **`updating-dependencies`** (external plugin) — refresh npm dependencies: detect what's outdated,
  bucket into patch/minor/major, research the bumps you select (one `dependency-update-researcher`
  run per bump), and apply only the ones you approve. It edits `package.json`, the lockfile, and the
  source a migration requires, and never commits. It holds no reference to this repository, so run
  `running-preflight-checks` and `testing-visual-regression` afterwards yourself.
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

## MCP servers

They arrive from two places. Most are project-scoped and committed in
[`.mcp.json`](../../.mcp.json), so the team shares them. The two browser servers come from the
`frontend-toolkit` plugin instead, which is why their tools carry a
`mcp__plugin_frontend-toolkit_…` prefix; the plugin owns their pins, and this repository does not.

Every version is pinned where its server is declared — in the `npx` command for the node servers, in
the image tag for the Docker ones — and is **deliberately not repeated here**. The declaring file is
the single source of truth; a number copied into prose only rots. Version numbers below name a
release where behaviour _changed_, which stays true no matter what is pinned today.

- **`astro-docs`** (http) — Astro's documentation, for framework questions during propose/implement.
- **`playwright`** (from `frontend-toolkit`) — Microsoft's `@playwright/mcp`, driving **host Chrome**
  (`--browser=chrome --headless --isolated`). The `frontend-qa-engineer` uses it for the manual-preview Verify
  item (theme flash, console, interactions, 375px); it also serves interactive exploration and
  locating selectors when authoring specs. Host rendering is **non-authoritative** — pixel baselines
  stay in the devcontainer suite. Approve it once in `/mcp`.
- **`chrome-devtools`** (from `frontend-toolkit`) — Google's `chrome-devtools-mcp`, host Chrome headless.
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

The proposal/task shaping lives in OpenSpec's own customization, so any agent running the standard
`/opsx:propose` flow produces it — no prompt carries it. The split is deliberate: **all
project-specific prose lives in `openspec/config.yaml`** (upgrade-proof
— OpenSpec's supported extension points), and **the schema fork stays upstream-verbatim except two
template seeds** (cheap to reconcile):

- **`openspec/config.yaml` → `context`** — the site's enduring guardrails, injected into every
  artifact's generation. Their canonical home is the project docs ([architecture](../architecture.md),
  [coding-conventions](../development/conventions/coding-conventions.md), [vision](../vision.md)); `config.yaml` points the
  propose flow at them rather than redefining them.
- **`openspec/config.yaml` → `rules`** — per-artifact constraints, appended to that artifact's
  composed instructions as a `<rules>` block. Read `config.yaml` for the current set; it shapes the
  proposal (**Non-Goals**, the blog-prose scope check, cross-change dependencies, and the
  `retire_capabilities` marker described above), the specs (domain flavor), the design (site-fitted
  inclusion criteria, and the **interactivity-tier decision** recorded with rationale), and the
  tasks (**primitives-first** — a slice that uses a `.btn`/`.tag`/`.card`/… primitive must
  establish it first, since the foundation shipped tokens only).
- **`openspec/schemas/frontend-change/`** — a project-local schema. Its `schema.yaml` is a verbatim
  copy of the built-in `spec-driven` schema except the `name:` and `description:` lines and two
  declared artifacts upstream does not have: **`brief`**, first in the graph and required by
  `proposal`, so every change starts from a written Explore record; and **`review`**, requiring
  `tasks` and listed in `apply.requires`, so `apply` reports a change not ready until its
  `review.md` exists. Each has a template of its own (`templates/brief.md`, `templates/review.md`);
  of the four upstream templates only two diverge: `templates/proposal.md` adds the **Non-Goals**
  heading and `templates/tasks.md` pre-seeds the mandatory **Verify** group. `config.yaml` selects
  it via `schema: frontend-change`. (OpenSpec has no schema inheritance — a project schema must be a
  complete copy, which is why the fork exists at all: templates only load from the schema's own
  directory.)
- **`openspec/config.yaml` → `operations`** — advisory guidance attached to the **apply** and
  **archive** operations only, so branch/hand-off rules reach `/opsx:apply` and delta-merge rules
  reach `/opsx:archive` without padding every artifact's context. Read it back with
  `openspec instructions apply|archive --change <name>`. Each `rules`/`guidance` entry must be a **string**: quote
  any bullet containing a `key: value` pair, or YAML parses it as a map and OpenSpec silently drops
  the whole list with a warning on stderr.

`openspec instructions tasks --change <name>` prints the composed result (template + schema
instruction + context). The seeded Verify section is:

```markdown
## N. Verify

- [ ] Visual + a11y snapshots pass in **both themes** for every touched view (testing-visual-regression skill)
- [ ] All preflight gate checks pass — the set in `docs/development/checks.md` (running-preflight-checks skill)
- [ ] Manual preview: no theme flash, interactions work, console clean, responsive at 375px
```

View-dependent Verify items are marked **N/A** (with a short note) on a change that touches no
views; the gate steps always run.

Verify is the change-wide gate over the finished change, not the place a task list collects its
testing. Since **1.13.2** the upstream schema requires each task group to land the tests and
documentation its own work calls for, so a group that adds a view carries its Playwright coverage
and its docs in that group; the `tasks` rule in `config.yaml` says the same in this project's terms.

How coding conventions reach the generated code is deliberately split, and the split is the reason
no prompt restates them: conventions a machine enforces (types, lint, formatting, token drift,
third-party resources) are left to the gate; conventions that need judgment mid-plan ride the
artifact `rules` above (the interactivity-tier decision in design, tier naming and primitives-first
in tasks); scaffolding conventions ride the `scaffolding-components` skill at implementation time;
the `frontend-code-reviewer` and the human review gates backstop the rest.

This shapes _generation_. Structural validity is also **enforced** in CI: the `verify` job runs
`npm run specs:check` (`openspec validate --all --strict`, then `openspec validate --archived`), so
malformed proposals or spec deltas fail a PR, as does an archived change with unticked tasks. The _content_ rules above (the Verify section, primitives-first) are generation-shaped
only — not hard-checked — so the `frontend-code-reviewer` and your review are the backstop.

The schema fork is OpenSpec-experimental and needs reconciling when OpenSpec updates its upstream
schema. Because the fork is upstream-verbatim apart from the two declared artifacts, that's
mechanical (last done against **1.13.2**):

1. `cp node_modules/@fission-ai/openspec/schemas/spec-driven/schema.yaml openspec/schemas/frontend-change/schema.yaml`,
   then restore the `name: frontend-change` and `description:` lines.
2. Restore the two declared artifacts from git: the `brief` entry (first in `artifacts`,
   `requires: []`, and `proposal` requiring `brief`) and the `review` entry (after `tasks`,
   requiring `tasks`, and `review` added to `apply.requires`). Their templates, `brief.md` and
   `review.md`, have no upstream counterpart and are left as they are.
3. Diff the four upstream templates against `node_modules/@fission-ai/openspec/schemas/spec-driven/templates/`;
   `design.md` and `spec.md` should stay identical, `proposal.md` keeps only the added **Non-Goals**
   section, `tasks.md` keeps only the appended **Verify** group and its keep-last comment.
4. `config.yaml` (`context`/`rules`/`operations`) is untouched by upgrades — but skim the release
   notes for new config capabilities worth adopting.
5. Verify with a throwaway change: `openspec new change probe`, then
   `openspec status --change probe` must list `brief` first and `review` last,
   `openspec instructions proposal|tasks --change probe` must show the `<rules>` block and the
   seeded Verify group, and `openspec instructions apply --change probe` must report `review`
   missing; delete the change and run `npm run specs:check`.

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
  profile, and `openspec update` keeps regenerating only those workflows. The `SessionStart`
  report flags any profile other than `core`.
- **`openspec config set telemetry.enabled false`** — turns off anonymous telemetry **and** the npm
  update check `openspec update` otherwise performs. Worth setting: the update check writes to that
  global config on every run, which fails outright under the agent sandbox (see
  [sandbox.md](sandbox.md)).

Regenerating the Claude integration is a **host** job for the same reason — the sandbox denies writes
to both `.claude/skills/` and `~/.config/`, so `openspec update` has to be run by you, not the agent.

The local sandbox that constrains the agents is documented in [sandbox.md](sandbox.md).
