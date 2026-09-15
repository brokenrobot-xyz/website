# Known gaps

Intent the site does not yet meet, or does not yet record.

Most intent starts undocumented. A principle is clear to the person holding it and written nowhere,
and it becomes visible only when something breaks it. This page is where that intent is captured
first, before it earns a place in [vision.md](vision.md), [architecture.md](architecture.md),
[tech-stack.md](tech-stack.md), or a spec.

## How to read an entry

Each entry states three things:

- **Intent** — what the site is supposed to do. State it even when no other document says it. This
  is the part that evaporates, so it is the part worth writing first.
- **Reality** — what the site does today.
- **Resolves by** — change the code, change the intent, or undecided. Undecided is a valid answer,
  and it is usually the honest one when the gap is found.

An entry has two exits, and they are independent. The intent graduates into the document that owns
it. The gap closes, or the project accepts it and records why. An entry that reaches both exits is
deleted.

Nothing here is subordinate to the enduring principles in [vision.md](vision.md). An entry may
conclude that a principle is wrong.

## Response content types depend on the platform

**Intent:** every file the site publishes is served with a content type that identifies it
correctly, on every platform the site is deployed to.

**Reality:** the built artifact carries no content-type configuration, by design — see the
**Portable artifact** principle. Each platform decides for itself, and the platforms disagree. The
container image maps no extension to Markdown, so it would serve a `.md` file as
`application/octet-stream`. What Cloudflare Pages serves for `.md` is not verified. `astro dev` and
`astro preview` both answer `text/markdown`, for two reasons that apply to neither deployment
target. The Markdown twins are the first files this affects.

**Resolves by:** undecided. Each target may need its own mapping, and something must verify the
served type per target rather than against a local server.

## The end-to-end suite runs against a server the site never deploys to

**Intent:** what the tests exercise before a release behaves like production.

**Reality:** Playwright runs against `astro preview`. Its DOM and visual assertions hold, because
the HTML is the same file production serves. Its response-level behaviour does not: headers,
content types, redirects, and error pages all come from a server that exists only on a developer
machine and in CI.

**Resolves by:** undecided. This needs discovery — whether a platform emulator, or the project's own
container image, can serve the suite instead.

## The e2e suite can start against a server that is not yet serving the site

**Intent:** when the suite starts, the server under test serves the build the suite is meant to
check. A test never fails because the server was not ready.

**Reality:** observed once, and it did not reproduce on the next run. A test asserting the home
page's title received `"Error"` — Astro's generic error page — with
`ENOENT: no such file or directory, open '/workspaces/website/dist/index.html'` behind it. So
`astro preview` answered Playwright's `webServer` readiness probe during a window in which
`dist/index.html` was absent. Which window is not established. Two candidates: `webServer` treats
any response as ready, including an error page, so a server that binds before its files are in
place passes the probe; and `reuseExistingServer` is on outside CI, so a preview server left over
from an earlier run can be serving `dist/` while `npm run build` rewrites it underneath. The two
are not exclusive, and a single non-reproducing observation cannot separate them.

**Resolves by:** undecided. It needs the mechanism established before a fix, because the two
candidates take opposite fixes — a stricter readiness condition against the first, and not reusing
a server across a rebuild against the second. Its rarity is not evidence that it is harmless: it
fails an arbitrary test with an unrelated-looking message, which costs more to diagnose than to
prevent.

## Nothing proves the absence of a flash of the wrong theme

**Intent:** a visitor never sees a frame of the wrong theme.
`openspec/specs/theming/spec.md` requires it, and it is the whole reason the theme is resolved by a
blocking inline script in `<head>` rather than by the bundled toggle module.

**Reality:** every theme assertion in `tests/` reads `html[data-theme]` after the page has settled.
Nothing inspects the first painted frame. A dark baseline fails if the pre-paint init breaks
altogether, because the whole page would then capture light — but that is protection by accident,
and it says nothing about a flash that resolves within a frame or two.

**Resolves by:** undecided. Asserting on first paint needs a capture the current setup does not take,
and it is not yet established which of a trace, a video, or a paint-timing probe can carry that
assertion without becoming flaky.

## The main session does the work it is meant to coordinate

**Intent:** every phase of a change — Explore, Propose, an adversarial review of the proposal by a
subagent and then by the human, Apply, Verify by a subagent, a review of the implementation by a
subagent and then by the human, Archive — runs in a context that holds only its own input: the
delegation message and the artifacts on disk from the phase before. Nothing else from the session
reaches it. The point is that stale reasoning, rejected directions, and earlier tangents cannot
steer the next phase; a small context is a side effect, not the goal. Three rules follow. Every
phase ends with a file, and the next phase starts from files, so each hand-off is traceable and is
a checkpoint the human can correct before the next phase reads it. The main thread is a router: it
holds the human's gate decisions and one short report per phase, and it does not read files itself
during a phase, because whatever it reads leaks into the next delegation message. A subagent that
would need to ask the human stops and returns the question instead of guessing. Forked agents and
forked skills are acceptable isolation; a fresh session per phase boundary is how the isolation is
achieved by hand today.

**Reality:** the isolation exists at one boundary only, and by hand: Explore and Propose run in one
session, and the human opens a new session for Apply onward, because the change folder is the only
thing that crosses. Inside each session the phases share one context. Explore ends with nothing on
disk, so Propose reads the whole Explore conversation, rejected directions included. Propose reads
the specs, the docs, and the codebase, and writes four artifacts, all in the main thread; it sits
there so it can ask questions. No subagent reviews the proposal before the human does. Three phases
are delegated and return short reports — Apply (`frontend-engineer`), Verify
(`frontend-qa-engineer`), and the implementation review (`frontend-code-reviewer`). The
`running-preflight-checks`, `testing-visual-regression`, and `scaffolding-components` skills carry a
`model:` pin and nothing else, which switches the model for one turn and isolates nothing, so their
output lands in the main thread whenever it calls them directly. The committing skill replays the
full diff into the main thread on every commit. Nothing loaded in a fresh session names the
sequence, the owner of each phase, or the two points where the main thread must stop for the
human, so a session can drift into doing the work itself.

**Resolves by:** change the tooling, through the OpenSpec flow, even though tooling under
`.claude/` otherwise commits directly. It lands on a new branch: the commit that restored the
engineer is already on `main`. The vendored `openspec-*` skills stay untouched, because
`openspec update` regenerates them. The process this resolves to, agreed 2026-09-11 — one owner
per step, skills as the owner's capabilities, every output a file:

| Step                  | Input                                        | Output on disk                     | Owner                       | Skills                       |
| --------------------- | -------------------------------------------- | ---------------------------------- | --------------------------- | ---------------------------- |
| Explore               | the idea, the codebase                       | `brief.md`                         | main thread, with the human | vendored explore             |
| Propose               | the brief                                    | proposal, specs, design, tasks     | planner agent               | vendored propose, update     |
| Proposal review       | the four artifacts, the living specs         | `review.md`                        | proposal reviewer agent     | none                         |
| _Gate_                | the change folder                            | the human's approval               | the human                   |                              |
| Apply                 | tasks, the rest of the folder                | code, ticked tasks                 | `frontend-engineer`         | vendored apply, scaffolding  |
| Verify                | the code, the tasks Verify group             | ticked Verify items, a report file | `frontend-qa-engineer`      | visual regression, preflight |
| Implementation review | the diff, the change folder, the conventions | a findings file                    | `frontend-code-reviewer`    | none                         |
| _Gate_                | the findings, the pull request               | the human's approval               | the human                   |                              |
| Commit the code       | the approved diff, the touched-files list    | a commit                           | a general-purpose subagent  | committing-conventionally    |
| Archive               | the change folder                            | merged specs, the archived folder  | main thread                 | vendored archive             |
| _Look_                | the merged specs                             | the human's go                     | the human                   |                              |
| Commit the specs      | the archive diff                             | a commit                           | a general-purpose subagent  | committing-conventionally    |

The review artifact gates Apply by existing; its accepted findings reach the engineer through the
artifacts an Update round rewrote, not through the file. Both review reports and the Verify
report are files so the folder is an audit log and a debugging record; where the two later files
live is settled at implementation. Both review loops keep the human in them: findings come to the
human, the human decides which go back, the coordinator re-delegates, and the reviewer runs again.
An automatic loop on Blocking findings waits until both reviewers have a track record. The pieces
one at a time:

- **Explore** stays in the main thread and ends with a written brief that the human can read and
  correct. The brief is Propose's only input besides the disk. _Decided 2026-09-11, in detail:_
  the brief is a declared artifact in the `frontend-change` schema, first in the graph, and
  `proposal` requires it, so every change has one — for a one-line idea with no Explore, the main
  thread writes the few lines itself before delegating. It carries the problem and goal, the
  decisions taken with their reasons, the rejected directions, the open questions and scope limits,
  and an answers section. Its template is settled at implementation; the starting point is five
  headings — Problem and goal, Decisions, Rejected directions, Open questions and scope, Answers —
  with an instruction that caps it at about one screen and sends anything longer to the proposal.
  The vendored explore skill writes it: since OpenSpec 1.8 that skill may
  create change artifacts within a scope the human confirms with an explicit yes, after scaffolding
  the change with `openspec new change`, so the change folder now exists at the end of Explore. No
  vendored skill changes: the propose skill reads every completed dependency before drafting, so a
  `proposal` that requires `brief` starts from it unmodified. Archive moves the whole change folder,
  so the brief survives as the record. Cost: the schema fork no longer matches upstream's artifact
  list, so the reconcile recipe in the tooling doc gains a step. OpenSpec has no subagent concept
  and its maintainers closed the requests as platform-specific; community schemas use the same
  file-only hand-off.
- **Propose and Update** run in a planner subagent that wraps the vanilla propose and update
  skills and returns questions instead of guessing, as the engineer does. _Decided._ When the
  planner returns a question, the human answers in chat, the coordinator appends the answer to
  the brief's answers section, and resumes the same planner rather than starting a new one — the
  Claude Code docs confirm a finished subagent resumes with its full history. The workflow doc's
  line that planning has no agent by design is rewritten when this lands.
- **The proposal review** is a separate read-only subagent, not a third placement on
  `frontend-code-reviewer`, because judging prose against specs shares almost nothing with judging
  a diff. It attacks the change folder — untestable scenarios, requirements that contradict the
  living specs, tasks that use a primitive nobody establishes, a missing tier decision, unnamed
  scope, a `skip_specs` claim that hides a behaviour change — and writes its report as a file, so
  an Update round picks it up from disk. Blocking findings go straight to the human; an automatic
  planner fix round waits until the reviewer has earned trust. _Decided._ The report survives
  archive with the rest of the folder. Checked on 1.12.0: `openspec validate --all --strict`
  ignores files the schema does not declare, and `openspec status` tracks only declared ones, so
  the report is a declared `review` artifact — the documented shape, and the one a community
  schema already uses for a fresh-context reviewer — and `apply` requires it, so OpenSpec itself
  refuses to apply a change nobody reviewed. _Decided 2026-09-11._ The gate proves a review ran,
  not that it passed and not that the human approved: existence is all OpenSpec checks, and the
  file goes stale after an Update round. So the coordinator reviews again after every Update, and
  the human reads the report before opening the apply session. If that hole needs closing
  mechanically, the reviewer writes its verdict on the report's first line and the coordinator
  refuses to proceed on anything but a clean one.
- **The three inline skills** stay inline. They are procedures, not phases: invoked from inside a
  phase's subagent their output lands where it belongs, and the leak exists only when the main
  thread invokes one directly. Scaffolding is invoked by the engineer and visual regression by the
  QA agent, so those two already sit inside a phase. Preflight had no owner, so the main thread
  ran the gate itself; now the QA agent owns all of Verify, runs the gate as well as the snapshot
  suite, and the apply guidance's hand-off line changes to match. The coordinator carries the
  rule that during a change the main thread never invokes these three. _Decided 2026-09-11._ The
  fork shape — `context: fork` with an `agent:`, which the Claude Code docs confirm keeps a skill's
  tool output in the subagent, and which `checking-dev-env` already uses — is not applied, because
  the dev-environment check and the QA agent would then invoke a forked skill from inside a
  subagent, and what happens then is the one case the docs do not cover. A fork for running the
  gate by hand outside a change is a follow-up once a probe at implementation shows nested forks
  work.
- **The committing skill** stays as it is in the marketplace plugin, and during a change it runs
  inside a general-purpose subagent that invokes it, so the diff replay lands there. The
  delegation answers up front the three questions the skill would ask — the branch is the
  change's branch, the scope is the engineer's touched-files list, staging is explicit paths —
  and a question the skill still hits comes back in the subagent's report. Commits happen only
  after a human approval: the code commit after the implementation gate, then Archive, then the
  human looks at the merged specs, then the second commit. Docs-only commits outside a change stay
  inline, because the human is present and no phase follows. _Decided 2026-09-11._ Forking the
  skill in the plugin was rejected because every consumer would lose its questions; it can become
  a plugin feature if a second project wants it.
- **The coordinator** is one project-owned skill, with one pointer line in `CLAUDE.md`, that names
  the sequence, the owner of each step, the files each step reads and writes, and the stops for
  the human. It is a runbook that points at the process table above, not a second copy of it. It
  has two entry points as two sections of the one skill, because the human starts a change in one
  session and applies it in another: start a change, and apply a named change. It carries the
  rules that belong to no single agent: the main thread never invokes the three procedure skills
  during a change; an answer to a planner question is appended to the brief and the same planner
  resumed; the proposal is reviewed again after every Update; commits are delegated and happen
  only after an approval. The pointer line is the backstop for a missed trigger, and the skill can
  be invoked by name. _Decided 2026-09-11._ Writing the sequence into `CLAUDE.md` itself was
  rejected because every session would pay for it; two separate entry-point skills were rejected
  because they would share most of their content.
- **Archive** stays in the main thread until it proves noisy.
