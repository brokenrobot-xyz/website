import AxeBuilder from '@axe-core/playwright';
import { test, expect } from '@playwright/test';

test.describe('Post: Navigating cultural clashes in global software teams', () => {
    test.beforeEach(async ({ page }) => {
        await page.goto('./blog/navigating-cultural-clashes-in-global-software-teams');
    });

    test('should have a title', async ({ page }) => {
        await expect(page).toHaveTitle(/Navigating cultural clashes in global software teams/);
    });

    test('should not have any automatically detectable accessibility issues', async ({ page }) => {
        const accessibilityScanResults = await new AxeBuilder({ page }).exclude('.astro-code').analyze();

        expect(accessibilityScanResults.violations).toEqual([]);
    });

    test('should match the screenshot', async ({ page }) => {
        await expect(page).toHaveScreenshot({ fullPage: true });
    });
});
