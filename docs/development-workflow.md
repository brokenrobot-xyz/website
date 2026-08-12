# Development workflow

How the site evolves. We work by two complementary practices:

- **Spec-driven development** — we agree on _what_ to build before any code. A change captures
  intent first, and once it's done the agreed behaviour is folded into a living record of how the
  site behaves, so the documentation never drifts behind the code.
- **Scaled [trunk-based development](https://trunkbaseddevelopment.com/)** — we _integrate_ in small
  batches. Each change is one short-lived branch off a single trunk (`main`), reviewed and merged
  quickly; the trunk stays releasable at all times and every merge deploys.

This page is the _what_ — the way we work, independent of any tool. The _how_ (the specific tooling,
commands, agents, and CI) is in [tooling/workflow.md](tooling/workflow.md).

## When to use it

For changes to the site itself:

- **Features** — new capabilities or behaviour (e.g. a theme toggle, a tags index, search).
- **Design** — visual and layout changes (typography, colour, spacing, components).
- **Infrastructure** — Terraform, deployment, CI/CD, and hosting changes under `infra/`.

The line is explicit: **any change to the site itself follows the flow, however small** — code
under `src/`, `public/`, or `tests/`, infrastructure and CI, and a dependency change that alters
site behaviour. The proposal is the agreement, even when no behaviour (and so no spec) changes —
see [What gets a spec](#what-gets-a-spec). Outside the flow: blog article prose (below),
repository documentation and agent tooling (`docs/`, `CLAUDE.md`, `.claude/`), which commit
directly, and routine dependency refreshes, which follow their own procedure (see
[tooling/workflow.md](tooling/workflow.md)).

### Out of scope: writing blog articles

Authoring or editing a **blog article** is _not_ planned as a change. Article content lives under
`src/content/blog/**` and is written directly, then committed with the custom `post` type (see
[commit-conventions](development/conventions/commit-conventions.md)). There is no spec for prose.

The blog _infrastructure_ — rendering components, the content schema, Markdown pipeline plugins, the
RSS feed — is ordinary feature work and **is** in scope.

## The workflow

A change moves through these phases. Three are explicitly **yours to decide** — you approve the
proposal, the implementation, and the production release; the rest is execution you accept or send
back.

1. **Explore** _(optional)_ — clarify the idea and investigate the codebase before committing to a
   proposal. No code is written.
2. **Propose** — capture the intent: the why and scope, how the site's behaviour changes, and the
   work broken into small steps. This is the agreement.
3. **Review the proposal** — **you** read, refine, and approve it **before any code is written**.
   The earliest and cheapest gate.
4. **Implement** — do the agreed work on a short-lived branch, surgically; nothing beyond the
   proposal.
5. **Verify** — the change is checked: visual + accessibility coverage in **both themes**, and the
   quality gate (types, lint, formatting, build).
6. **Archive** — fold the agreed behaviour into the living record **on the branch**, so the change
   carries its code and its spec together when it goes to review.
7. **Review the implementation** — **you** examine the change against the guardrails (below) and
   approve it before it merges.
8. **Integrate** — merge the short-lived branch into the trunk. Only complete, verified changes
   merge, so the trunk stays releasable.
9. **Deploy** — the merge releases the change to production; **you** approve the release.

The three **you** steps are the decision gates: accept the proposal, accept the implementation,
accept the release. Everything between is execution you oversee.

## Trunk-based integration

The integration half keeps a few invariants — the _why_ behind the branch rules in
[branching-conventions](development/conventions/branching-conventions.md):

- **Small batches.** One change is one short-lived branch — opened, reviewed, and merged quickly, so
  branches never drift far from the trunk.
- **The trunk is always releasable.** A change merges only when it is complete and its gates pass;
  partial work stays on the branch. We keep the units small rather than hide incomplete work behind
  flags.
- **Every merge deploys.** There are no release branches; merging to the trunk releases to
  production. The site's version (in `package.json`) is bumped deliberately for notable releases, not
  on every merge.

> The **release gate** (step 9) — a required approval before the production deploy — is the intended
> third gate, but it is not yet configured. Setting it up is a planned infrastructure change. See
> [tech-stack](tech-stack.md) for how deployment works today.

## The living record

We keep two things: a **living record of how the site behaves today**, and the **in-flight change**
modifying it. The record answers "how does it work now?"; a change answers "what are we changing, and
why?". When a change is done, its agreed behaviour merges into the record — which is what keeps the
record honest.

### What gets a spec

The record describes **externally observable behaviour** — what visitors and downstream consumers
(feeds, crawlers) rely on — and the external constraints we hold (accessibility, CSP, performance,
compatibility). A change updates the record exactly when it moves one of those. A change that
doesn't — a pure refactor, tooling, CI, a dependency bump — still gets a proposal and the gates,
and declares that it changes no behaviour; auditing that claim is part of the proposal review.
Never invent a requirement to satisfy a validator: a fabricated requirement is drift, not record.

Bug fixes sit on both sides of the line: a fix that **restores** behaviour the record already
describes changes no spec; a fix that **changes** the agreed behaviour modifies the record. The
mechanics — the `skip_specs` marker — are in [tooling/workflow.md](tooling/workflow.md).

## Guardrails

Every change must respect the site's enduring constraints — don't restate them in each proposal, but
honour them. The authoritative sources are:

- [architecture](architecture.md) — code structure, content model, and theming (CSS custom
  properties on `<html>`, both light and dark first-class).
- [coding-conventions](development/conventions/coding-conventions.md) — TypeScript, Astro patterns, and the testing rules.
- [tech-stack](tech-stack.md) and [vision](vision.md) — the static-only, ad-free, **CSP-strict**
  shape of the site (no third-party scripts, no inline `on*` handlers) and the principles behind it.

In short: output stays static, the CSP stays strict, both themes stay first-class, and UI changes
carry visual + accessibility coverage.
