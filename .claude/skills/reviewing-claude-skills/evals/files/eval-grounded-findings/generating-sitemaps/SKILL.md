---
name: generating-sitemaps
description: Generates a sitemap.xml for a static site from its built HTML — collects page URLs, assigns priorities, and escapes entities per the bundled rules. Use after a build when the sitemap is missing or stale.
allowed-tools: Read Write Glob
---

# Generate a sitemap

Build `sitemap.xml` from the built site's HTML files, following the three rule files:
[`references/url-rules.md`](references/url-rules.md),
[`references/priorities.md`](references/priorities.md), and
[`references/escaping.md`](references/escaping.md).

## Steps

1. Collect every `.html` file under the build directory with `Glob`.
2. Map each file to its canonical URL per the URL rules.
3. Assign each URL a priority per the priority table.
4. Escape each URL per the escaping rules. Never emit an unescaped ampersand.
5. Write `sitemap.xml` at the build root and report the URL count.
