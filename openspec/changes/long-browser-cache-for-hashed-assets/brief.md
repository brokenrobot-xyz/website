# Brief

## Problem and goal

**Problem.** From 4 hours after each deploy until the next deploy, a browser re-checks every font and
every image with the server before the browser shows the file. The site owner sees the hero image of
a blog post reload on each page refresh in desktop Firefox, in desktop Safari, and on a phone.

**Mechanism.** The cache rule `cache_everything` in `infra/cloudflare/modules/domain/main.tf` sets an
edge cache lifetime of one year and a browser cache lifetime of 4 hours. Cloudflare therefore sends
`cache-control: public, max-age=14400` together with an `age` header that counts from the deploy
purge. A browser deducts the `age` value from the `max-age` value. When the `age` value is above
14400, the file is expired on arrival.

**Evidence.** `browser-measurements.md` in this folder holds the measurements, taken on 2026-09-29 in
headless Chrome 154 against production.

- Production sent `age` values from 56974 to 67190 with `max-age=14400`.
- On reload, Chrome re-checked each file stored with an `age` value of 57645 or 66569. The server
  answered 304. Each re-check took about 600 ms on the Slow 4G profile.
- On reload, Chrome served each file stored with an `age` value from 44 to 600 from the browser
  cache, with no request.
- The stored `age` value predicted the result for 8 of 8 files.
- Nobody measured Firefox or Safari.

**Goal.** A browser keeps each file under `/_astro/` for one year and does not re-check the file on
reload. The change is done when both of these results hold:

- The site owner sees no reload of the hero image on page refresh in Firefox, in Safari, and on a
  phone.
- A reload measurement on production shows no request for a file under `/_astro/`, where the same
  measurement before the change shows a 304.

## Decisions

- **Give the files under `/_astro/` a browser cache lifetime of one year, plus `immutable`.** The name
  of each file under `/_astro/` contains a hash of the file content, so a changed file has a new name
  and a browser cannot show an old copy.
- **Add a production header check that runs after each deploy.** The check confirms that a file under
  `/_astro/` carries the one-year browser cache lifetime. The end-to-end suite cannot do this check,
  because the suite runs against `astro preview`, which does not apply the Cloudflare rules.
  `docs/known-gaps.md` records that gap.
- **Correct `infra/cloudflare/README.md`.** The section "Edge caching hides deployments" says that a
  visitor keeps the site in the browser cache for up to 4 hours, and it records the per-file-type
  split as rejected. The measurements contradict the first statement. The reason for the rejection
  names `public/`, which has no hashed file names, and that reason does not apply to `/_astro/`.
- **Deliver this change before the site change.** A second change covers images, fonts, and a page
  weight budget. Two changes keep the effect of each change measurable.

## Rejected directions

- **Shorten the edge cache lifetime to 4 hours.** The browser cache lifetime would then vary from
  4 hours to zero, so the re-check would stay for part of the visitors.
- **Give every response one long browser cache lifetime.** A page keeps its address across deploys, so
  a browser would show an old page for up to one year.
- **Leave the cache rule unchanged.** The reload that the site owner sees would stay.
- **Check paint time in the pipeline.** Pipeline machines vary in speed, so the check would fail
  without a change to the site.

## Open questions and scope

**The proposal must verify each of these points and must not assume the answer:**

- Can a rule on the Cloudflare Free plan add `immutable`? The browser cache lifetime setting writes
  `max-age` only, so the change possibly needs a response header rule.
- How does the new rule interact with the rule `cache_everything`, which matches every request?
- Which browsers honor `immutable`? MDN states that `immutable` prevents the conditional request. The
  browser support table was not read.
- How does a Terraform change reach production? `.github/workflows/pipeline.yml` validates Terraform
  and contains no apply step.

**In scope:** the cache rules under `infra/cloudflare/`, `infra/cloudflare/README.md`, the production
header check, and the entry for that check in `docs/development/checks.md`. `docs/development/checks.md`
is the only document that lists automated checks.

**Not in scope, and the change must leave each item as it is:**

- The edge cache lifetime of one year and the deploy purge in `.github/workflows/deploy.yml`.
- The browser cache lifetime of 4 hours for pages and for files from `public/`.
- Images, fonts, and the page weight budget, which belong to the second change.
- The `Permissions-Policy` header, which names four features that Chrome does not recognize.
- The Chrome report that images have no explicit dimensions.

## Answers
