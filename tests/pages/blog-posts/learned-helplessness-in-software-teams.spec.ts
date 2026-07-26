import AxeBuilder from '@axe-core/playwright';
import { test, expect } from '@playwright/test';

import { settleImages } from '../../settleImages';

test.describe('Post: Learned helplessness in software teams: Symptoms, causes, and the path to empowerment', () => {
    test.beforeEach(async ({ page }) => {
        await page.goto('./blog/learned-helplessness-in-software-teams');
    });

    test('should have a title', async ({ page }) => {
        await expect(page).toHaveTitle(
            /Learned helplessness in software teams: Symptoms, causes, and the path to empowerment/
        );
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
