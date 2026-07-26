import AxeBuilder from '@axe-core/playwright';
import { test, expect } from '@playwright/test';

import { settleImages } from '../../settleImages';

test.describe('Post: Hosting a static website on Amazon S3', () => {
    test.beforeEach(async ({ page }) => {
        await page.goto('./blog/hosting-a-static-website-on-amazon-s3');
    });

    test('should have a title', async ({ page }) => {
        await expect(page).toHaveTitle(/Hosting a static website on Amazon S3/);
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
