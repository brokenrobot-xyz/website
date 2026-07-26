import AxeBuilder from '@axe-core/playwright';
import { test, expect } from '@playwright/test';

import { settleImages } from '../../settleImages';

test.describe('Post: The power of coding conventions in large, distributed teams', () => {
    test.beforeEach(async ({ page }) => {
        await page.goto('./blog/the-power-of-coding-conventions-in-large-distributed-teams');
    });

    test('should have a title', async ({ page }) => {
        await expect(page).toHaveTitle(/The power of coding conventions in large, distributed teams/);
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
