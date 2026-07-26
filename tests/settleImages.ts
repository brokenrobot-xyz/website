import type { Page } from '@playwright/test';

/**
 * Make a page's images deterministic before a screenshot.
 *
 * Screenshots used to hide every `<picture>` via an injected stylesheet, because most images are
 * `loading="lazy"` and a full-page capture does not reliably scroll them into view — so they landed
 * half-loaded. That stylesheet is injected into the page at capture time, which a hash-based
 * `style-src` blocks, so the masking silently stopped working once CSP was enabled.
 *
 * Forcing eager loading and awaiting decode achieves the same stability through the DOM instead,
 * which CSP does not restrict, and lets the baselines show the images rather than hide them.
 */
const settleImages = async (page: Page): Promise<void> => {
    await page.evaluate(async () => {
        for (const image of document.querySelectorAll('img')) {
            image.loading = 'eager';
        }

        await Promise.all([...document.images].map((image) => image.decode().catch(() => undefined)));

        await document.fonts.ready;
    });
};

export { settleImages };
