import AxeBuilder from '@axe-core/playwright';
import { test, expect } from '@playwright/test';

import { settleImages } from '../../settleImages';

test.describe('Post: URL redirect with Amazon CloudFront and Amazon Route 53', () => {
    test.beforeEach(async ({ page }) => {
        await page.goto('./blog/url-redirect-with-amazon-cloudfront-and-amazon-route-53');
    });

    test('should have a title', async ({ page }) => {
        await expect(page).toHaveTitle(/URL redirect with Amazon CloudFront and Amazon Route 53/);
    });

    test('should not have any automatically detectable accessibility issues', async ({ page }) => {
        const accessibilityScanResults = await new AxeBuilder({ page }).exclude('.astro-code').analyze();

        expect(accessibilityScanResults.violations).toEqual([]);
    });

    test('should match the screenshot', async ({ page }) => {
        await settleImages(page);

        await expect(page).toHaveScreenshot({ fullPage: true });
    });
});
