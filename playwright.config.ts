import { defineConfig, devices } from '@playwright/test';
import { config } from 'dotenv';

config();

export default defineConfig({
    testDir: './tests',
    snapshotPathTemplate: '{testDir}/__screenshots__/{testFilePath}/{arg}{-projectName}{ext}',
    expect: {
        timeout: 10_000,
        toPass: {
            timeout: 15_000
        },
        toHaveScreenshot: {
            maxDiffPixelRatio: 0.01
        }
    },
    fullyParallel: true,
    forbidOnly: process.env.CI !== undefined,
    retries: 0,
    workers: 1,
    outputDir: 'reports/tests/e2e/test-results',
    reporter: [
        ['list'],
        ['html', { outputFolder: 'reports/tests/e2e/html', open: 'never' }],
        ['json', { outputFile: 'reports/tests/e2e/json/test-results.json' }],
        ['junit', { outputFile: 'reports/tests/e2e/junit/test-results.xml' }],
        ['github']
    ],
    use: {
        baseURL: `http://localhost:${process.env.BROKENROBOT_PORT}`,
        trace: 'on-first-retry'
    },
    projects: [
        // Desktop browsers
        {
            name: 'Desktop Chrome',
            use: { ...devices['Desktop Chrome'] }
        },

        // Mobile browsers
        {
            name: 'Pixel 7',
            use: { ...devices['Pixel 7'] }
        }
    ],
    webServer: {
        command: 'npm run serve',
        timeout: 60_000,
        url: `http://localhost:${process.env.BROKENROBOT_PORT}`,
        reuseExistingServer: process.env.CI === undefined
    }
});
