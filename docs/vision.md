# Vision

This document explains _why_ brokenrobot.xyz exists and the kind of site it strives to be
over the long run. It is the north star the other documents serve.

## Mission

Broken Robot is Tamas Mezei's little corner of the web — a personal site and blog where he
shares professional experiences, thoughts, adventures, and projects with the world. It is a
place to think out loud about software, document a journey, and give something back to the
wider development community.

It is deliberately **pure content**: no ads, no affiliate links, no tracking or spyware.
Making the internet a slightly better place, one byte at a time.

## Audience

The site is written for three overlapping readers. The design should serve all three without
diluting the personal, human voice.

- **Fellow developers** — peers who come for the writing on software, engineering culture,
  and tooling. They should find articles readable, well-structured, and easy to navigate.
- **Employers & clients** — people evaluating Tamas professionally. The site doubles as a
  credibility signal: it should feel polished, trustworthy, and competent.
- **Tech-curious readers** — a broader audience interested in software without being expert
  practitioners. Content and presentation should remain approachable, never gatekept.

## Where it's heading

Broken Robot is always growing toward a few lasting ambitions. They aren't a one-time
checklist — they're the directions the site keeps moving in.

1. **A look that feels current.** A polished, contemporary aesthetic that ages well.
2. **A distinctive identity.** A memorable visual personality rooted in the "Broken Robot"
   name (see [brand](brand.md)) — recognizable as nobody else's.
3. **A great reading experience.** Typography, layout, and long-form article ergonomics tuned
   for comfortable, distraction-free reading.
4. **Capabilities that serve the reader.** Notably a **light/dark theme** the reader controls
   and a **robot mascot** woven through the experience — and room to grow further over time.

## What good looks like

The site is living up to its vision when:

- It has a recognizable, ownable identity — someone could spot it without the logo.
- Light and dark themes are both first-class, with the reader's preference respected.
- The mascot is present and reinforces the brand (e.g. hero, 404, empty states).
- Reading a long article simply feels good — on a phone as much as on a wide monitor.
- Performance, accessibility, SEO, and security are always upheld, never traded away for
  looks.

## Enduring principles

These are commitments the site always upholds. They also appear in the relevant technical
docs.

- **Ad-free and tracking-free.** No ads, affiliate links, analytics spyware, or third-party
  trackers. This is core to the brand promise.
- **Static by design.** A static-site model with dual-cloud delivery (AWS S3/CloudFront +
  Cloudflare Pages). See [tech-stack](tech-stack.md).
- **Strict security.** A strict CSP and hardened security headers. See
  [architecture](architecture.md) for what this means for theming.
- **Stable URLs.** `/blog/<slug>/` permalinks and the RSS feed keep working — readers and
  search engines depend on them.
- **Simplicity.** A clean, focused experience. Features earn their place; nothing is added
  just because it can be.
