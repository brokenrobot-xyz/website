import { satteri } from '@astrojs/markdown-satteri';
import mdx from '@astrojs/mdx';
import preact from '@astrojs/preact';
import sitemap from '@astrojs/sitemap';
import tailwindcss from '@tailwindcss/vite';
import { defineConfig, fontProviders } from 'astro/config';
import { config } from 'dotenv';

import { codeBlockFocusPlugin } from './src/utils/codeBlockFocusPlugin';
import { readingTimePlugin } from './src/utils/readingTimePlugin';

config();

export default defineConfig({
    site: 'https://www.brokenrobot.xyz',
    integrations: [preact(), mdx(), sitemap()],
    vite: {
        plugins: [tailwindcss()]
    },
    security: {
        // Astro emits script-src/style-src (with per-page content hashes) and font-src itself. The rest are
        // listed here so the policy in the built HTML is complete on its own, and travels with the
        // artifact to any host. `frame-ancestors` is deliberately absent: it is ignored in a <meta>
        // element, so it lives only in the edge header (see nginx.conf).
        csp: {
            directives: [
                "default-src 'none'",
                "img-src 'self'",
                "connect-src 'self'",
                "base-uri 'none'",
                "form-action 'none'",
                "object-src 'none'",
                "media-src 'none'",
                "worker-src 'none'",
                "manifest-src 'none'",
                "frame-src 'none'",
                "child-src 'none'"
            ]
        }
    },
    compressHTML: true,
    build: {
        inlineStylesheets: 'always'
    },
    image: {
        responsiveStyles: true
    },
    fonts: [
        {
            provider: fontProviders.local(),
            name: 'Space Grotesk',
            cssVariable: '--font-space-grotesk',
            fallbacks: ['system-ui', 'sans-serif'],
            options: {
                variants: [
                    {
                        weight: 400,
                        style: 'normal',
                        src: [
                            '@fontsource/space-grotesk/files/space-grotesk-latin-400-normal.woff2',
                            '@fontsource/space-grotesk/files/space-grotesk-latin-400-normal.woff'
                        ]
                    },
                    {
                        weight: 500,
                        style: 'normal',
                        src: [
                            '@fontsource/space-grotesk/files/space-grotesk-latin-500-normal.woff2',
                            '@fontsource/space-grotesk/files/space-grotesk-latin-500-normal.woff'
                        ]
                    },
                    {
                        weight: 600,
                        style: 'normal',
                        src: [
                            '@fontsource/space-grotesk/files/space-grotesk-latin-600-normal.woff2',
                            '@fontsource/space-grotesk/files/space-grotesk-latin-600-normal.woff'
                        ]
                    },
                    {
                        weight: 700,
                        style: 'normal',
                        src: [
                            '@fontsource/space-grotesk/files/space-grotesk-latin-700-normal.woff2',
                            '@fontsource/space-grotesk/files/space-grotesk-latin-700-normal.woff'
                        ]
                    }
                ]
            }
        },
        {
            provider: fontProviders.local(),
            name: 'Newsreader',
            cssVariable: '--font-newsreader',
            fallbacks: ['Georgia', 'serif'],
            options: {
                variants: [
                    {
                        weight: 400,
                        style: 'normal',
                        src: [
                            '@fontsource/newsreader/files/newsreader-latin-400-normal.woff2',
                            '@fontsource/newsreader/files/newsreader-latin-400-normal.woff'
                        ]
                    },
                    {
                        weight: 500,
                        style: 'normal',
                        src: [
                            '@fontsource/newsreader/files/newsreader-latin-500-normal.woff2',
                            '@fontsource/newsreader/files/newsreader-latin-500-normal.woff'
                        ]
                    },
                    {
                        weight: 600,
                        style: 'normal',
                        src: [
                            '@fontsource/newsreader/files/newsreader-latin-600-normal.woff2',
                            '@fontsource/newsreader/files/newsreader-latin-600-normal.woff'
                        ]
                    },
                    {
                        weight: 400,
                        style: 'italic',
                        src: [
                            '@fontsource/newsreader/files/newsreader-latin-400-italic.woff2',
                            '@fontsource/newsreader/files/newsreader-latin-400-italic.woff'
                        ]
                    }
                ]
            }
        },
        {
            provider: fontProviders.local(),
            name: 'Space Mono',
            cssVariable: '--font-space-mono',
            fallbacks: ['ui-monospace', 'monospace'],
            options: {
                variants: [
                    {
                        weight: 400,
                        style: 'normal',
                        src: [
                            '@fontsource/space-mono/files/space-mono-latin-400-normal.woff2',
                            '@fontsource/space-mono/files/space-mono-latin-400-normal.woff'
                        ]
                    },
                    {
                        weight: 700,
                        style: 'normal',
                        src: [
                            '@fontsource/space-mono/files/space-mono-latin-700-normal.woff2',
                            '@fontsource/space-mono/files/space-mono-latin-700-normal.woff'
                        ]
                    },
                    {
                        weight: 400,
                        style: 'italic',
                        src: [
                            '@fontsource/space-mono/files/space-mono-latin-400-italic.woff2',
                            '@fontsource/space-mono/files/space-mono-latin-400-italic.woff'
                        ]
                    }
                ]
            }
        }
    ],
    markdown: {
        syntaxHighlight: 'prism',
        processor: satteri({ mdastPlugins: [readingTimePlugin], hastPlugins: [codeBlockFocusPlugin] })
    },
    server: {
        port: process.env.BROKENROBOT_PORT === undefined ? 4321 : parseInt(process.env.BROKENROBOT_PORT, 10),
        headers: {
            'Cache-Control': `public, max-age=0, must-revalidate`,
            // Mirrors the edge header in nginx.conf so `astro preview` (and the Playwright suite,
            // which runs against it) exercises the same two-layer policy as production. Keep the
            // two in sync; the strict, hash-based half is the <meta> policy from `security.csp`.
            'Content-Security-Policy': `default-src 'none'; child-src 'none'; connect-src 'self'; font-src 'self'; frame-src 'none'; img-src 'self'; manifest-src 'none'; media-src 'none'; object-src 'none'; script-src 'self' 'unsafe-inline'; script-src-attr 'none'; style-src 'self' 'unsafe-inline'; style-src-attr 'none'; worker-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none';`,
            'Permissions-Policy': `accelerometer=(), ambient-light-sensor=(), autoplay=(), battery=(), camera=(), display-capture=(), document-domain=(), encrypted-media=(), gamepad=(), geolocation=(), gyroscope=(), fullscreen=(self), magnetometer=(), microphone=(), midi=(), payment=(), publickey-credentials-get=(), screen-wake-lock=(), serial=(), speaker-selection=(), usb=(), web-share=(), xr-spatial-tracking=()`,
            'Referrer-Policy': `same-origin`,
            'Strict-Transport-Security': `max-age=63072000; includeSubDomains; preload`,
            'X-Content-Type-Options': `nosniff`,
            'X-Frame-Options': `DENY`
        }
    }
});
