# Browser loading measurements: www.brokenrobot.xyz

Measured 2026-09-29, about 08:58 to 09:06 GMT, in headless Chrome 154 driven by the Chrome DevTools MCP tools.

## Summary

- **Confirmed, stale-on-arrival caching.** A response stored with an `age` header above 14400 was revalidated (status 304) on the next normal reload; a response stored with a small `age` was served from cache with no request. On the phone-profile blog post, the hero image and the four preloaded Space Grotesk fonts were all revalidated. Which case occurs depends on which Cloudflare edge cache answers, so it varies from load to load.
- **Confirmed, blog index thumbnails are oversized.** Every thumbnail loaded was the 1280w AVIF (the largest candidate) for a slot 395 CSS px wide on desktop and 358 CSS px wide on the phone profile.
- **Confirmed, hero image is heavy and has no AVIF.** Chrome chose the 1668w WebP (304 kB) at 1440 px and device pixel ratio 1, the 2560w WebP (728 kB) at 1440 px and device pixel ratio 2, and the 1280w WebP (173 kB) on the phone profile.
- **Confirmed under throttling, fonts arrive after first paint.** On the phone profile every font, including the four preloaded ones, finished 0.8 to 1.7 s after first paint. Newsreader is not preloaded and is the font of the Largest Contentful Paint text element on all three pages.
- **Not observed:** no unused-preload console warning on any page; Cumulative Layout Shift was 0.00 (rounded) everywhere. Firefox and Safari were not measured.

## Method and limits

| Item                         | Value                                                                                                                            |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Tool family used             | Chrome DevTools MCP (`mcp__plugin_frontend-toolkit_chrome-devtools__*`). It started a browser on the first call; nothing failed. |
| Playwright MCP               | Not used. The fallback was not needed.                                                                                           |
| Browser                      | `HeadlessChrome/154.0.0.0` on macOS (from `navigator.userAgent`, `evaluate_script`)                                              |
| Firefox, Safari, real phones | **Not measured.** I did not check whether either tool family can drive them.                                                     |
| Desktop profile              | `emulate` viewport `1440x900x1`, no throttling                                                                                   |
| Phone profile                | `emulate` viewport `390x844x3,mobile,touch`, network `Slow 4G`, CPU throttling 4x                                                |
| Extra profile                | `emulate` viewport `1440x900x2` (blog post only, image selection only)                                                           |
| Cold load                    | Each page and profile used its own new `isolatedContext` (empty cache), opened on `about:blank`                                  |
| Trace                        | `performance_start_trace` (`reload=false`, `autoStop=false`), then `navigate_page`, then `performance_stop_trace`                |
| Lighthouse                   | **Not run.** The `lighthouse_audit` tool description states it excludes the performance category.                                |

Limits that affect how to read the numbers:

- **One run per page and profile.** No repeat runs, so no variance is known.
- **Desktop traces were stopped early.** I stopped each desktop trace immediately after `navigate_page` returned (about 0.3 to 0.45 s after navigation start). Phone traces ran 4 to 6 s longer. For the desktop blog post this made the trace miss a later Largest Contentful Paint candidate; see section A.
- **Sizes come from the Resource Timing API** (`evaluate_script` reading `performance.getEntriesByType`), because `list_network_requests` shows only method, URL, and status. "Transferred" is `transferSize`.
- **The cross-origin script `static.cloudflareinsights.com/beacon.min.js` has an unknown transferred size.** Resource Timing reports 0 for it, and its response carried no `content-length`. All byte totals below exclude it.
- **Priority is only known for requests I inspected individually** with `get_network_request` (the `priority` request header) or that a trace insight printed. Others are marked "not recorded".
- **No screenshots or filmstrip were taken.** Statements that text painted in a fallback font are inferences from timings, not direct observations.

Font file names map to faces as follows (observed, `evaluate_script` reading the `@font-face` rules on the home page). All faces declare `font-display: swap`.

| File                     | Face                  | Preloaded            |
| ------------------------ | --------------------- | -------------------- |
| `cc4c675f99c90782.woff2` | Space Grotesk 400     | yes                  |
| `03f899704c451ad3.woff2` | Space Grotesk 500     | yes                  |
| `6439e8ce00ef6cfe.woff2` | Space Grotesk 600     | yes                  |
| `1d949940601ea42e.woff2` | Space Grotesk 700     | yes                  |
| `46215b0ff773c88a.woff2` | Newsreader 400        | no                   |
| `a5f58e052df44da3.woff2` | Newsreader 500        | no                   |
| `c327c542de4c40bd.woff2` | Newsreader 600        | no                   |
| `51945f4a6a9c8333.woff2` | Newsreader 400 italic | no                   |
| `c9b55e4bc3bfbc9c.woff2` | Space Mono 400        | no                   |
| `c4b0cdf760be8458.woff2` | Space Mono 700        | no                   |
| `262c4a0c9150b94b.woff2` | Space Mono 400 italic | no (never requested) |

## A. Cold-load metrics

Sources: Largest Contentful Paint, its breakdown, and Cumulative Layout Shift from the `performance_stop_trace` summary. First Contentful Paint from `evaluate_script` (`performance.getEntriesByType('paint')`). Largest Contentful Paint element from `performance_analyze_insight` (`LCPBreakdown`) and from `evaluate_script` (a buffered `PerformanceObserver`). Request count from `list_network_requests`. Bytes are my sum of `transferSize` values returned by `evaluate_script`, excluding the beacon script.

| Page       | Profile | Largest Contentful Paint            | Element                               | First Contentful Paint | Cumulative Layout Shift | Transferred bytes | Requests |
| ---------- | ------- | ----------------------------------- | ------------------------------------- | ---------------------- | ----------------------- | ----------------- | -------- |
| Home       | Desktop | 275 ms                              | `DIV`, text, Newsreader               | 276 ms                 | 0.00                    | 151,086           | 12       |
| Blog index | Desktop | 266 ms                              | `DIV.basis-2/3`, text, Newsreader     | 268 ms                 | 0.00                    | 535,947           | 16       |
| Blog post  | Desktop | 280 ms in trace; 484 ms in observer | `H1` in trace; hero `IMG` in observer | 280 ms                 | 0.00                    | 516,718           | 15       |
| Home       | Phone   | 836 ms                              | `DIV`, text, Newsreader               | 836 ms                 | 0.00                    | 151,086           | 12       |
| Blog index | Phone   | 3254 ms                             | first thumbnail `IMG`                 | 856 ms                 | 0.00                    | 409,843           | 14       |
| Blog post  | Phone   | 844 ms                              | `P`, text, Newsreader                 | 844 ms                 | 0.00                    | 384,930           | 15       |

Observed details:

- **Desktop blog post has two Largest Contentful Paint values.** The trace reported the `H1` at 280 ms. The `PerformanceObserver` run afterwards reported a later candidate: the hero `IMG` at 484 ms (size 721,088). The trace had already been stopped, so it missed it. The image download itself finished at 216 ms.
- **Phone blog index Largest Contentful Paint is a lazy-loaded thumbnail.** `performance_analyze_insight` (`LCPDiscovery`) reported: queued at 844 ms, download complete at 3,224 ms, initial priority Low, final priority High, and two failed checks: "fetchpriority=high should be applied" and "LCP resources should not use loading=lazy".
- **Phone breakdown for the blog index** (trace summary): time to first byte 95 ms, load delay 749 ms, load duration 2,380 ms, render delay 30 ms.
- **Time to first byte stayed at 69 to 95 ms under the Slow 4G throttle.** I did not investigate why the throttle did not raise it.

Layout shift entries (`evaluate_script`, `PerformanceObserver` for `layout-shift`; root causes from `performance_analyze_insight`, `CLSCulprits`):

| Page       | Profile | Shift values       | Root cause named by the trace                                            |
| ---------- | ------- | ------------------ | ------------------------------------------------------------------------ |
| Home       | Phone   | 0.000083           | Newsreader 400 and Newsreader 500 font files                             |
| Blog post  | Phone   | 0.000182, 0.003726 | Newsreader 400, Newsreader 400 italic, and "an unsized image" (the hero) |
| Blog post  | Desktop | 0.0000 (one shift) | "an unsized image" (the hero)                                            |
| Blog index | Phone   | none               | none                                                                     |

Desktop home and desktop blog index layout shift entries were not collected with the observer; the trace reported 0.00 for both.

## B. Image and font requests

Every row below is a cold load. No request came from the browser cache on any cold load (`deliveryType` was empty and `transferSize` was above zero for all same-origin requests). Status from `list_network_requests`; size and timing from `evaluate_script`.

### Image variant chosen versus rendered size

Descriptor mapping from `evaluate_script` reading each `srcset`. Rendered size from `getBoundingClientRect`. "Needed" is rendered CSS width times device pixel ratio, which is my arithmetic.

| Image             | Profile          | File chosen                       | Descriptor | Format | Transferred | Rendered CSS px | Needed device px | Chosen / needed |
| ----------------- | ---------------- | --------------------------------- | ---------- | ------ | ----------- | --------------- | ---------------- | --------------- |
| Blog post hero    | Desktop, ratio 1 | `heroImage.BEBVVSZf_Z1ytpv7.webp` | 1668w      | WebP   | 304,374     | 1216 x 684      | 1216             | 1.37            |
| Blog post hero    | Desktop, ratio 2 | `heroImage.BEBVVSZf_Z2kGSPj.webp` | 2560w      | WebP   | 727,832     | 1216 x 684      | 2432             | 1.05            |
| Blog post hero    | Phone, ratio 3   | `heroImage.BEBVVSZf_1HTQby.webp`  | 1280w      | WebP   | 172,586     | 358 x 201       | 1074             | 1.19            |
| Index thumbnail 1 | Desktop, ratio 1 | `heroImage.BEBVVSZf_18tpBQ.avif`  | 1280w      | AVIF   | 76,572      | 395 x 222       | 395              | 3.24            |
| Index thumbnail 2 | Desktop, ratio 1 | `heroImage.C2xv7UYp_Z1LYTxR.avif` | 1280w      | AVIF   | 122,352     | 395 x 222       | 395              | 3.24            |
| Index thumbnail 3 | Desktop, ratio 1 | `heroImage.89fU4HMA_1RSHMx.avif`  | 1280w      | AVIF   | 80,455      | 395 x 222       | 395              | 3.24            |
| Index thumbnail 1 | Phone, ratio 3   | `heroImage.BEBVVSZf_18tpBQ.avif`  | 1280w      | AVIF   | 76,572      | 358 x 201       | 1074             | 1.19            |
| Index thumbnail 2 | Phone, ratio 3   | `heroImage.C2xv7UYp_Z1LYTxR.avif` | 1280w      | AVIF   | 122,352     | 358 x 201       | 1074             | 1.19            |
| Index thumbnail 3 | Phone, ratio 3   | `heroImage.89fU4HMA_1RSHMx.avif`  | 1280w      | AVIF   | 80,455      | 358 x 201       | 1074             | 1.19            |

Observed details:

- **The blog index thumbnails do have AVIF sources.** Each `<picture>` has an AVIF `<source>` and a WebP `<source>`, with widths 384w, 640w, 768w, 1024w, 1280w, and no `sizes`.
- **The hero `<picture>` has one WebP `<source>` and a JPEG `<img>`.** Widths are 640w, 750w, 828w, 1080w, 1280w, 1668w, 2048w, 2560w. The `sizes="100vw"` attribute is on the `<img>`; the `<source>` has no `sizes` attribute.
- **Desktop blog index loaded five thumbnails, phone loaded three.** The other lazy images had an empty `currentSrc`.
- **`performance_analyze_insight` (`ImageDelivery`) estimates:** desktop blog index 365.6 kB wasted; phone blog index 256.7 kB; desktop blog post 165.5 kB; phone blog post 160.3 kB. This insight compares the file to the CSS pixel size (for example "1280x720 for its displayed dimensions 358x201"), not to device pixels, so on the phone profile it overstates the waste.

Inference: the oversizing is large on a device-pixel-ratio-1 desktop (3.24 times) and small on a ratio-3 phone (1.19 times). For the hero, the chosen width is close to what the screen needs at ratio 2; the cost there is the byte size of WebP at 2560w, not excess pixels.

### Desktop, home

| URL                                    | Status | Transferred | From cache | Priority     | Finished |
| -------------------------------------- | ------ | ----------- | ---------- | ------------ | -------- |
| `/_astro/fonts/cc4c675f99c90782.woff2` | 200    | 13,688      | no         | not recorded | 104 ms   |
| `/_astro/fonts/03f899704c451ad3.woff2` | 200    | 13,612      | no         | not recorded | 104 ms   |
| `/_astro/fonts/6439e8ce00ef6cfe.woff2` | 200    | 13,584      | no         | not recorded | 104 ms   |
| `/_astro/fonts/1d949940601ea42e.woff2` | 200    | 13,140      | no         | not recorded | 110 ms   |
| `/_astro/fonts/c9b55e4bc3bfbc9c.woff2` | 200    | 16,820      | no         | `u=0`        | 143 ms   |
| `/_astro/fonts/c4b0cdf760be8458.woff2` | 200    | 17,024      | no         | not recorded | 140 ms   |
| `/_astro/fonts/a5f58e052df44da3.woff2` | 200    | 23,924      | no         | not recorded | 141 ms   |
| `/_astro/fonts/46215b0ff773c88a.woff2` | 200    | 22,780      | no         | not recorded | 152 ms   |

No image requests except `/favicon.svg` (200, 1,597 bytes).

### Desktop, blog index

| URL                                       | Status | Transferred | From cache | Priority     | Finished |
| ----------------------------------------- | ------ | ----------- | ---------- | ------------ | -------- |
| `/_astro/fonts/cc4c675f99c90782.woff2`    | 200    | 13,688      | no         | not recorded | 230 ms   |
| `/_astro/fonts/03f899704c451ad3.woff2`    | 200    | 13,612      | no         | not recorded | 210 ms   |
| `/_astro/fonts/6439e8ce00ef6cfe.woff2`    | 200    | 13,584      | no         | not recorded | 232 ms   |
| `/_astro/fonts/1d949940601ea42e.woff2`    | 200    | 13,140      | no         | not recorded | 237 ms   |
| `/_astro/fonts/c9b55e4bc3bfbc9c.woff2`    | 200    | 16,820      | no         | not recorded | 315 ms   |
| `/_astro/fonts/46215b0ff773c88a.woff2`    | 200    | 22,780      | no         | not recorded | 327 ms   |
| `/_astro/fonts/c4b0cdf760be8458.woff2`    | 200    | 17,024      | no         | not recorded | 317 ms   |
| `/_astro/heroImage.BEBVVSZf_18tpBQ.avif`  | 200    | 76,572      | no         | not recorded | 315 ms   |
| `/_astro/heroImage.C2xv7UYp_Z1LYTxR.avif` | 200    | 122,352     | no         | not recorded | 325 ms   |
| `/_astro/heroImage.89fU4HMA_1RSHMx.avif`  | 200    | 80,455      | no         | not recorded | 309 ms   |
| `/_astro/heroImage.hDXWa_85_1Xc7JG.avif`  | 200    | 62,934      | no         | not recorded | 309 ms   |
| `/_astro/heroImage.CBXebSuU_ZDhvqs.avif`  | 200    | 63,170      | no         | not recorded | 317 ms   |
| `/favicon.svg`                            | 200    | 1,597       | no         | not recorded | 414 ms   |

### Desktop, blog post

| URL                                       | Status | Transferred | From cache | Priority     | Finished |
| ----------------------------------------- | ------ | ----------- | ---------- | ------------ | -------- |
| `/_astro/fonts/cc4c675f99c90782.woff2`    | 200    | 13,688      | no         | not recorded | 110 ms   |
| `/_astro/fonts/6439e8ce00ef6cfe.woff2`    | 200    | 13,584      | no         | not recorded | 112 ms   |
| `/_astro/fonts/03f899704c451ad3.woff2`    | 200    | 13,612      | no         | not recorded | 113 ms   |
| `/_astro/fonts/1d949940601ea42e.woff2`    | 200    | 13,140      | no         | not recorded | 114 ms   |
| `/_astro/heroImage.BEBVVSZf_Z1ytpv7.webp` | 200    | 304,374     | no         | `u=1, i`     | 216 ms   |
| `/_astro/fonts/c9b55e4bc3bfbc9c.woff2`    | 200    | 16,820      | no         | not recorded | 148 ms   |
| `/_astro/fonts/46215b0ff773c88a.woff2`    | 200    | 22,780      | no         | `u=0`        | 149 ms   |
| `/_astro/fonts/c327c542de4c40bd.woff2`    | 200    | 24,176      | no         | not recorded | 206 ms   |
| `/_astro/fonts/51945f4a6a9c8333.woff2`    | 200    | 24,640      | no         | not recorded | 213 ms   |
| `/_astro/fonts/c4b0cdf760be8458.woff2`    | 200    | 17,024      | no         | not recorded | 146 ms   |
| `/_astro/fonts/a5f58e052df44da3.woff2`    | 200    | 23,924      | no         | not recorded | 207 ms   |
| `/favicon.svg`                            | 200    | 1,597       | no         | not recorded | 232 ms   |

### Phone, home

| URL                                    | Status | Transferred | From cache | Priority     | Finished |
| -------------------------------------- | ------ | ----------- | ---------- | ------------ | -------- |
| `/_astro/fonts/cc4c675f99c90782.woff2` | 200    | 13,688      | no         | not recorded | 1715 ms  |
| `/_astro/fonts/03f899704c451ad3.woff2` | 200    | 13,612      | no         | not recorded | 1722 ms  |
| `/_astro/fonts/1d949940601ea42e.woff2` | 200    | 13,140      | no         | not recorded | 1663 ms  |
| `/_astro/fonts/6439e8ce00ef6cfe.woff2` | 200    | 13,584      | no         | not recorded | 1731 ms  |
| `/_astro/fonts/46215b0ff773c88a.woff2` | 200    | 22,780      | no         | not recorded | 2072 ms  |
| `/_astro/fonts/a5f58e052df44da3.woff2` | 200    | 23,924      | no         | not recorded | 2080 ms  |
| `/_astro/fonts/c4b0cdf760be8458.woff2` | 200    | 17,024      | no         | not recorded | 1998 ms  |
| `/_astro/fonts/c9b55e4bc3bfbc9c.woff2` | 200    | 16,820      | no         | not recorded | 2006 ms  |
| `/favicon.svg`                         | 200    | 1,597       | no         | not recorded | 2680 ms  |

### Phone, blog index

| URL                                       | Status | Transferred | From cache | Priority                | Finished |
| ----------------------------------------- | ------ | ----------- | ---------- | ----------------------- | -------- |
| `/_astro/fonts/cc4c675f99c90782.woff2`    | 200    | 13,688      | no         | not recorded            | 1716 ms  |
| `/_astro/fonts/6439e8ce00ef6cfe.woff2`    | 200    | 13,584      | no         | not recorded            | 1724 ms  |
| `/_astro/fonts/03f899704c451ad3.woff2`    | 200    | 13,612      | no         | not recorded            | 1798 ms  |
| `/_astro/fonts/1d949940601ea42e.woff2`    | 200    | 13,140      | no         | not recorded            | 1782 ms  |
| `/_astro/fonts/46215b0ff773c88a.woff2`    | 200    | 22,780      | no         | not recorded            | 2341 ms  |
| `/_astro/fonts/c4b0cdf760be8458.woff2`    | 200    | 17,024      | no         | not recorded            | 2199 ms  |
| `/_astro/fonts/c9b55e4bc3bfbc9c.woff2`    | 200    | 16,820      | no         | not recorded            | 2208 ms  |
| `/_astro/heroImage.BEBVVSZf_18tpBQ.avif`  | 200    | 76,572      | no         | initial Low, final High | 3224 ms  |
| `/_astro/heroImage.89fU4HMA_1RSHMx.avif`  | 200    | 80,455      | no         | not recorded            | 3290 ms  |
| `/_astro/heroImage.C2xv7UYp_Z1LYTxR.avif` | 200    | 122,352     | no         | not recorded            | 3524 ms  |
| `/favicon.svg`                            | 200    | 1,597       | no         | not recorded            | 4124 ms  |

### Phone, blog post

| URL                                      | Status | Transferred | From cache | Priority     | Finished |
| ---------------------------------------- | ------ | ----------- | ---------- | ------------ | -------- |
| `/_astro/fonts/cc4c675f99c90782.woff2`   | 200    | 13,688      | no         | `u=1`        | 1802 ms  |
| `/_astro/fonts/03f899704c451ad3.woff2`   | 200    | 13,612      | no         | not recorded | 1820 ms  |
| `/_astro/fonts/6439e8ce00ef6cfe.woff2`   | 200    | 13,584      | no         | not recorded | 1835 ms  |
| `/_astro/fonts/1d949940601ea42e.woff2`   | 200    | 13,140      | no         | not recorded | 1745 ms  |
| `/_astro/heroImage.BEBVVSZf_1HTQby.webp` | 200    | 172,586     | no         | `u=1, i`     | 3319 ms  |
| `/_astro/fonts/46215b0ff773c88a.woff2`   | 200    | 22,780      | no         | not recorded | 2470 ms  |
| `/_astro/fonts/c327c542de4c40bd.woff2`   | 200    | 24,176      | no         | not recorded | 2504 ms  |
| `/_astro/fonts/51945f4a6a9c8333.woff2`   | 200    | 24,640      | no         | not recorded | 2527 ms  |
| `/_astro/fonts/c9b55e4bc3bfbc9c.woff2`   | 200    | 16,820      | no         | not recorded | 2295 ms  |
| `/_astro/fonts/c4b0cdf760be8458.woff2`   | 200    | 17,024      | no         | not recorded | 2312 ms  |
| `/_astro/fonts/a5f58e052df44da3.woff2`   | 200    | 23,924      | no         | not recorded | 2511 ms  |
| `/favicon.svg`                           | 200    | 1,597       | no         | not recorded | 3911 ms  |

Other requests on every page: the document, `static.cloudflareinsights.com/beacon.min.js` (200, size unknown, request priority `u=1`), and `POST /cdn-cgi/rum?` (204, 300 bytes).

## C. Fonts

### When each font finished, relative to first paint

All values from `evaluate_script` (Resource Timing `responseEnd` and the `first-paint` entry). The difference is my arithmetic. A positive number means the font finished after first paint.

| Page       | Profile | First paint | Preloaded Space Grotesk files finished | Newsreader files finished               | Space Mono files finished               |
| ---------- | ------- | ----------- | -------------------------------------- | --------------------------------------- | --------------------------------------- |
| Home       | Desktop | 276 ms      | 104 to 110 ms (before)                 | 141 to 152 ms (before)                  | 140 to 143 ms (before)                  |
| Blog index | Desktop | 268 ms      | 210 to 237 ms (before)                 | 327 ms (59 ms after)                    | 315 to 317 ms (47 to 49 ms after)       |
| Blog post  | Desktop | 280 ms      | 110 to 114 ms (before)                 | 149 to 213 ms (before)                  | 146 to 148 ms (before)                  |
| Home       | Phone   | 836 ms      | 1663 to 1731 ms (827 to 895 ms after)  | 2072 to 2080 ms (1236 to 1244 ms after) | 1998 to 2006 ms (1162 to 1170 ms after) |
| Blog index | Phone   | 856 ms      | 1716 to 1798 ms (860 to 942 ms after)  | 2341 ms (1485 ms after)                 | 2199 to 2208 ms (1343 to 1352 ms after) |
| Blog post  | Phone   | 844 ms      | 1745 to 1835 ms (901 to 991 ms after)  | 2470 to 2527 ms (1626 to 1683 ms after) | 2295 to 2312 ms (1451 to 1468 ms after) |

### Fonts used above the fold but not preloaded

- **Observed:** the Largest Contentful Paint element had a computed `font-family` starting with Newsreader on the home page (both profiles), the blog index (desktop, and the first candidate on phone), and the blog post (phone). Newsreader is not preloaded. Source: `evaluate_script`, `getComputedStyle` on the Largest Contentful Paint element.
- **Observed:** on the desktop blog post the first Largest Contentful Paint candidate was the `H1`, in Space Grotesk, which is preloaded.
- **Observed:** Space Mono 400 and 700 reached status `loaded` on every page (`evaluate_script`, `document.fonts`). Space Mono is not preloaded. I did not measure whether the Space Mono text is above the fold.
- **Observed:** on the phone profile the non-preloaded fonts started about 150 ms later than the preloaded ones (start at 789 to 802 ms versus 633 to 653 ms) and finished about 270 to 780 ms later, depending on the page and the file.

Inference: with `font-display: swap` and these timings, text on the phone profile first painted in the fallback font and swapped later, for the preloaded Space Grotesk as well as for Newsreader and Space Mono. The trace supports this by naming Newsreader font files as the root cause of layout shifts on the phone home page and phone blog post. I did not capture screenshots, so the swap itself was not seen.

Inference: the layout shift from the swap is near zero because the fallback faces carry metric overrides. Observed in the document source returned by `get_network_request`: the fallback `@font-face` rules set `size-adjust`, `ascent-override`, and `descent-override`. The glyph shapes still change, which matches what the site owner describes.

### Preloaded fonts that were not used

| Page                     | Face status in `document.fonts` after load (`evaluate_script`) | Unused-preload console warning |
| ------------------------ | -------------------------------------------------------------- | ------------------------------ |
| Home, both profiles      | Space Grotesk 400, 500, 600, 700 all `loaded`                  | none                           |
| Blog index, desktop      | Space Grotesk 400, 500, 700 `loaded`; 600 not `loaded`         | none                           |
| Blog index, phone        | Space Grotesk 400, 500, 700 `loaded`; 600 `unloaded`           | none                           |
| Blog post, both profiles | Space Grotesk 400, 500, 600, 700 all `loaded`                  | none                           |

- **Observed:** on the blog index the Space Grotesk 600 file (`6439e8ce00ef6cfe.woff2`, 13,584 bytes) was downloaded through its preload, while the matching face stayed unused.
- **Observed:** Chrome did not print its unused-preload warning on any page. Console was read with `list_console_messages`, including with `includePreservedMessages=true`, several minutes after load on the desktop blog index.
- **Not resolved:** I do not know why the warning is absent when the face is unused. The face status and the console disagree; I report both.

## D. Reload behaviour

Method: load the page in a new isolated context, then `navigate_page` with `type=reload` and `ignoreCache=false`. Status from `list_network_requests`. Cache versus network from `evaluate_script` (Resource Timing `deliveryType` and `transferSize`). Stored `age` from `get_network_request` on the first-load request, or on the cached entry.

### Blog post, phone profile: first reload

| Resource                              | First-load `age` | Reload result     | Status | Transferred | Time on network |
| ------------------------------------- | ---------------- | ----------------- | ------ | ----------- | --------------- |
| Document                              | not read         | revalidated       | 304    | 300         | not recorded    |
| Hero `heroImage.BEBVVSZf_1HTQby.webp` | 57645            | **revalidated**   | 304    | 300         | 608 to 1208 ms  |
| Space Grotesk 400 (preloaded)         | 57645            | **revalidated**   | 304    | 300         | 602 to 1174 ms  |
| Space Grotesk 500 (preloaded)         | not read         | **revalidated**   | 304    | 300         | 603 to 1182 ms  |
| Space Grotesk 600 (preloaded)         | not read         | **revalidated**   | 304    | 300         | 603 to 1192 ms  |
| Space Grotesk 700 (preloaded)         | not read         | **revalidated**   | 304    | 300         | 603 to 1198 ms  |
| Newsreader 400                        | 600              | cache, no request | 200    | 0           | none            |
| Newsreader 500, 600, 400 italic       | not read         | cache, no request | 200    | 0           | none            |
| Space Mono 400, 700                   | not read         | cache, no request | 200    | 0           | none            |
| `/favicon.svg`                        | not read         | revalidated       | 304    | 300         | 1216 to 1790 ms |

Nothing was downloaded again in full. The revalidation request for the hero carried `if-none-match` with the stored `etag`, and the 304 response carried `age: 378`. The 304 for Space Grotesk 400 carried `age: 286`.

### Blog post, phone profile: second reload

| Resource       | Reload result     | Status | Transferred |
| -------------- | ----------------- | ------ | ----------- |
| Document       | revalidated       | 304    | 300         |
| Hero image     | cache, no request | 200    | 0           |
| All ten fonts  | cache, no request | 200    | 0           |
| `/favicon.svg` | cache, no request | 200    | 0           |

### Blog post, desktop profile: first reload

| Resource                               | First-load `age`                         | Reload result     | Status | Transferred |
| -------------------------------------- | ---------------------------------------- | ----------------- | ------ | ----------- |
| Document                               | not read                                 | revalidated       | 304    | 300         |
| Hero `heroImage.BEBVVSZf_Z1ytpv7.webp` | no `age` header; `cf-cache-status: MISS` | cache, no request | 200    | 0           |
| Newsreader 400                         | 44                                       | cache, no request | 200    | 0           |
| All other fonts                        | not read                                 | cache, no request | 200    | 0           |
| `/favicon.svg`                         | not read                                 | cache, no request | 200    | 0           |

### Blog index, phone profile: first reload (extra run)

| Resource                                    | First-load `age` | Reload result     | Status | Transferred | Time on network |
| ------------------------------------------- | ---------------- | ----------------- | ------ | ----------- | --------------- |
| Document                                    | not read         | revalidated       | 304    | 300         | not recorded    |
| Thumbnail `heroImage.BEBVVSZf_18tpBQ.avif`  | 66569            | **revalidated**   | 304    | 300         | 618 to 1190 ms  |
| Thumbnail `heroImage.89fU4HMA_1RSHMx.avif`  | not read         | **revalidated**   | 304    | 300         | 618 to 1198 ms  |
| Thumbnail `heroImage.C2xv7UYp_Z1LYTxR.avif` | not read         | **revalidated**   | 304    | 300         | 618 to 1207 ms  |
| Space Grotesk 400                           | 179              | cache, no request | 200    | 0           | none            |
| Newsreader 400                              | 180              | cache, no request | 200    | 0           | none            |
| Other fonts                                 | not read         | cache, no request | 200    | 0           | none            |

The 304 for the first thumbnail carried `age: 66606`, which is still above 14400.

### The edge returns different ages for the same file

Observed with `evaluate_script` running `fetch(url, {method: 'HEAD', cache: 'no-store'})` from the desktop blog post page, shortly after its reload at 09:00:54 GMT:

| Resource                               | `age`          | `cf-cache-status` |
| -------------------------------------- | -------------- | ----------------- |
| Document                               | 67188          | HIT               |
| Four Space Grotesk files               | 844            | HIT               |
| Hero `heroImage.BEBVVSZf_Z1ytpv7.webp` | 62             | HIT               |
| Six Newsreader and Space Mono files    | 67188 to 67190 | HIT               |
| `/favicon.svg`                         | 107            | HIT               |

At 09:00:14 GMT, in the same browser context, Newsreader 400 had been delivered with `age: 44`. Response `cf-ray` values ended in `-ZRH` on some loads and `-MXP` on others.

### What this shows

Observed:

- **In every case where I read the stored `age`, the outcome matched it.** Stored `age` of 57645, 57645, and 66569 (all above 14400) led to a 304 revalidation. Stored `age` of 44, 179, 180, 600, and a response with no `age` header led to a cache hit with no request. That is eight resources.
- **No resource was downloaded again in full on any reload.**
- **Each revalidation cost about 570 to 600 ms on the Slow 4G profile.**
- **A 304 that carries a small `age` repairs the cache entry; a 304 that carries a large `age` does not.** After the phone blog post 304 responses with `age` 378 and 286, the second reload used the cache. The blog index thumbnail 304 carried `age: 66606`; I did not reload that page a second time.

Inference:

- The hypothesis is confirmed for Chrome: a response that arrives with `age` above `max-age` is stale on arrival and is revalidated on its next use.
- It is not "every asset on every use". It depends on which edge cache answered, which differs between files in the same page load and between loads.
- The revalidated image is not re-downloaded, but during the round trip the image slot has no picture. On a slow connection that is a visible delay of about half a second, which matches "a page refresh visibly reloads the hero image".

Not measured:

- **Firefox and Safari reload behaviour.** Their handling of subresources on reload may differ from Chrome's. I have no measurement of it.
- **Revisit by ordinary navigation** (link click or back button) rather than reload.
- **The stored `age` of the resources marked "not read".**

## E. Console messages

Source: `list_console_messages`, with `includePreservedMessages=true` for the warnings, and `get_console_message` for the detail of the issue.

| Page       | Profile | Messages                                                                                                               |
| ---------- | ------- | ---------------------------------------------------------------------------------------------------------------------- |
| Home       | Desktop | four Permissions-Policy warnings                                                                                       |
| Blog index | Desktop | four Permissions-Policy warnings; issue "Lazy-loaded images should have explicit dimensions" (count 11)                |
| Blog post  | Desktop | four Permissions-Policy warnings; issue "Lazy-loaded images should have explicit dimensions" (count 1)                 |
| Home       | Phone   | four Permissions-Policy warnings                                                                                       |
| Blog index | Phone   | issue "Lazy-loaded images should have explicit dimensions" (count 11). Preserved messages were not read for this page. |
| Blog post  | Phone   | four Permissions-Policy warnings; issue "Lazy-loaded images should have explicit dimensions" (count 1)                 |

The four warnings, identical on every page where they were read:

```
Error with Permissions-Policy header: Unrecognized feature: 'ambient-light-sensor'.
Error with Permissions-Policy header: Unrecognized feature: 'battery'.
Error with Permissions-Policy header: Unrecognized feature: 'document-domain'.
Error with Permissions-Policy header: Unrecognized feature: 'speaker-selection'.
```

Observed details:

- **The Permissions-Policy warnings only appear with `includePreservedMessages=true`.** A plain `list_console_messages` call returned no warnings.
- **No errors, no Content-Security-Policy violations, and no unused-preload warnings** on any page.
- **The lazy-image issue and the markup disagree.** Chrome says the images lack explicit dimensions. The first three blog index `<img>` elements do carry `width` and `height` attributes (3840 x 2160, 4032 x 2268, 3840 x 2160; `evaluate_script`). The trace also calls the blog post hero "an unsized image". I did not inspect the CSS to find out why Chrome treats them as unsized.
