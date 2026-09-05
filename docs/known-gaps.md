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

## The container and production disagree on HSTS

**Intent:** unrecorded. No document states the intended `Strict-Transport-Security` max-age.

**Reality:** `nginx.conf` declares `max-age=63072000`. Production returns `max-age=31536000`. The
two have drifted apart, and nothing records which one is correct.

**Resolves by:** undecided. Write the intended value first; only then is it possible to say which
side is wrong.

## The end-to-end suite runs against a server the site never deploys to

**Intent:** what the tests exercise before a release behaves like production.

**Reality:** Playwright runs against `astro preview`. Its DOM and visual assertions hold, because
the HTML is the same file production serves. Its response-level behaviour does not: headers,
content types, redirects, and error pages all come from a server that exists only on a developer
machine and in CI.

**Resolves by:** undecided. This needs discovery — whether a platform emulator, or the project's own
container image, can serve the suite instead.
