import AxeBuilder from '@axe-core/playwright';
import { test, expect } from '@playwright/test';

test.describe('Post: Your AI Platform Will Inherit Your Engineering Culture', () => {
    test.beforeEach(async ({ page }) => {
        await page.goto('./blog/your-ai-platform-will-inherit-your-engineering-culture');
    });

    test('should have a title', async ({ page }) => {
        await expect(page).toHaveTitle(/Your AI Platform Will Inherit Your Engineering Culture/);
    });

    test('should not have any automatically detectable accessibility issues', async ({ page }) => {
        const accessibilityScanResults = await new AxeBuilder({ page }).exclude('.astro-code').analyze();

        expect(accessibilityScanResults.violations).toEqual([]);
    });

    test('should match the screenshot', async ({ page }) => {
        await expect(page).toHaveScreenshot({ fullPage: true });
    });
});
