import type { APIRoute } from 'astro';
import { getCollection } from 'astro:content';

import { SITE_METADATA } from '../consts';

// A Markdown map of the site for language models, following the llms.txt convention
// (https://llmstxt.org): an H1 name, a blockquote summary, free prose, then sections of links.
const SUMMARY =
    'Personal website and blog of Tamas Mezei, a software engineer and architect in Zurich, Switzerland. Writing on software, engineering culture, coding conventions, and cloud infrastructure. No ads, no trackers.';

export const GET: APIRoute = async ({ site }) => {
    const toUrl = (path: string): string => new URL(path, site).href;

    const posts = (await getCollection('blog')).sort(
        (a, b) => b.data.publishDate.valueOf() - a.data.publishDate.valueOf()
    );

    const body = [
        `# ${SITE_METADATA.TITLE}`,
        '',
        `> ${SUMMARY}`,
        '',
        `Content is © ${SITE_METADATA.AUTHOR.NAME}, all rights reserved. Quote briefly with attribution and a link to the canonical URL.`,
        '',
        '## Pages',
        '',
        `- [Home](${toUrl('/')}): Latest posts and a short introduction.`,
        `- [About](${toUrl('/about')}): Who Tamas is and what he works on.`,
        `- [Blog](${toUrl('/blog')}): Every post, newest first.`,
        '',
        '## Blog posts',
        '',
        ...posts.map((post) => `- [${post.data.title}](${toUrl(`/blog/${post.id}`)}): ${post.data.excerpt}`),
        '',
        '## Optional',
        '',
        `- [RSS feed](${toUrl('/rss.xml')}): The same posts as a feed.`,
        `- [Sitemap](${toUrl('/sitemap-index.xml')}): Every indexable URL on the site.`,
        ''
    ].join('\n');

    return new Response(body, {
        headers: { 'Content-Type': 'text/plain; charset=utf-8' }
    });
};
