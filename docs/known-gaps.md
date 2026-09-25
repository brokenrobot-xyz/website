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
