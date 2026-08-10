import rss from '@astrojs/rss';
import type { APIRoute } from 'astro';
import { getCollection } from 'astro:content';

import { SITE_METADATA } from '@consts';

export const GET: APIRoute = async ({ site }) => {
    const posts = await getCollection('blog');

    return rss({
        title: SITE_METADATA.TITLE,
        description: SITE_METADATA.DESCRIPTION,
        site: site !== undefined ? site : '',
        items: posts.map((post) => ({
            title: post.data.title,
            pubDate: post.data.publishDate,
            description: post.data.excerpt,
            link: `/blog/${post.id}`
        })),
        trailingSlash: false
    });
};
