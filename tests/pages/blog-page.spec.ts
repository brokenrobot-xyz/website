import AxeBuilder from '@axe-core/playwright';
import { test, expect } from '@playwright/test';

import { settleImages } from '../settleImages';

test.describe('Blog page', () => {
    test.beforeEach(async ({ page }) => {
        await page.goto('./blog');
    });

    test('should have a title', async ({ page }) => {
        await expect(page).toHaveTitle(/Blog/);
    });

    test('should not have any automatically detectable accessibility issues', async ({ page }) => {
        const accessibilityScanResults = await new AxeBuilder({ page }).analyze();

        expect(accessibilityScanResults.violations).toEqual([]);
    });

    test('should match the screenshot', async ({ page }) => {
        await settleImages(page);

        await expect(page).toHaveScreenshot({ fullPage: true });
    });
});
