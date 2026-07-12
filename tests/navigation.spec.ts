import { test, expect } from '@playwright/test';

test.describe('Home page', () => {
    test('should be accessible via the header navigation', async ({ page }, testInfo) => {
        // The "Home" nav link is hidden on mobile; the logo links home there instead.
        test.skip(testInfo.project.name === 'Pixel 7', 'The "Home" nav link is hidden on mobile.');

        await page.goto('./about');
        await expect(page).toHaveTitle(/About/);

        await page.getByRole('navigation').getByRole('link', { name: 'Home' }).click();
        await expect(page).toHaveTitle(/Broken Robot/);
    });

    test('should be accessible via the logo', async ({ page }) => {
        await page.goto('./about');
        await expect(page).toHaveTitle(/About/);

        await page.getByRole('banner').getByRole('link', { name: 'BrokenRobot' }).click();
        await expect(page).toHaveTitle(/Broken Robot/);
    });
});

test.describe('About page', () => {
    test('should be accessible from the home page via the header navigation', async ({ page }) => {
        await page.goto('./');
        await expect(page).toHaveTitle(/Broken Robot/);

        await page.getByRole('navigation').getByRole('link', { name: 'About' }).click();
        await expect(page).toHaveTitle(/About/);
    });

    test('should be accessible from the home page via the intro paragraph', async ({ page }) => {
        await page.goto('./');
        await expect(page).toHaveTitle(/Broken Robot/);

        await page.getByRole('main').getByRole('link', { name: 'About' }).click();
        await expect(page).toHaveTitle(/About/);
    });
});

test.describe('Blog page', () => {
    test('should be accessible from the home page via the header navigation', async ({ page }) => {
        await page.goto('./');
        await expect(page).toHaveTitle(/Broken Robot/);

        await page.getByRole('navigation').getByRole('link', { name: 'Blog' }).click();
        await expect(page).toHaveTitle(/Blog/);
    });

    test('should be accessible from the about page via the intro paragraph', async ({ page }) => {
        await page.goto('./about');
        await expect(page).toHaveTitle(/About/);

        await page.getByRole('link', { name: 'blog posts' }).click();
        await expect(page).toHaveTitle(/Blog/);
    });
});

test.describe('Post: Hello, World!', () => {
    test('should be accessible from the blog page', async ({ page }) => {
        await page.goto('./blog');
        await expect(page).toHaveTitle(/Blog/);

        await page.getByRole('heading').getByRole('link', { name: 'Hello, World!' }).click();
        await expect(page).toHaveTitle(/Hello, World!/);
    });
});

test.describe('Post: Hosting a static website on Amazon S3', () => {
    test('should be accessible from the blog page', async ({ page }) => {
        await page.goto('./blog');
        await expect(page).toHaveTitle(/Blog/);

        await page.getByRole('heading').getByRole('link', { name: 'Hosting a static website on Amazon S3' }).click();
        await expect(page).toHaveTitle(/Hosting a static website on Amazon S3/);
    });

    test('should be accessible from the about page', async ({ page }) => {
        await page.goto('./about');
        await expect(page).toHaveTitle(/About/);

        await page.getByRole('link', { name: 'Hosting a static website on Amazon S3' }).click();
        await expect(page).toHaveTitle(/Hosting a static website on Amazon S3/);
    });
});

test.describe('Post: Advanced static website hosting with Amazon S3 and CloudFront', () => {
    test('should be accessible from the blog page', async ({ page }) => {
        await page.goto('./blog');
        await expect(page).toHaveTitle(/Blog/);

        await page
            .getByRole('heading')
            .getByRole('link', { name: 'Advanced static website hosting with Amazon S3 and CloudFront' })
            .click();
        await expect(page).toHaveTitle(/Advanced static website hosting with Amazon S3 and CloudFront/);
    });

    test('should be accessible from the about page', async ({ page }) => {
        await page.goto('./about');
        await expect(page).toHaveTitle(/About/);

        await page.getByRole('link', { name: 'Advanced static website hosting with Amazon S3 and CloudFront' }).click();
        await expect(page).toHaveTitle(/Advanced static website hosting with Amazon S3 and CloudFront/);
    });
});

test.describe('Post: URL redirect with Amazon CloudFront and Amazon Route 53', () => {
    test('should be accessible from the blog page', async ({ page }) => {
        await page.goto('./blog');
        await expect(page).toHaveTitle(/Blog/);

        await page
            .getByRole('heading')
            .getByRole('link', { name: 'URL redirect with Amazon CloudFront and Amazon Route 53' })
            .click();
        await expect(page).toHaveTitle(/URL redirect with Amazon CloudFront and Amazon Route 53/);
    });

    test('should be accessible from the about page', async ({ page }) => {
        await page.goto('./about');
        await expect(page).toHaveTitle(/About/);

        await page.getByRole('link', { name: 'URL redirect with Amazon CloudFront and Amazon Route 53' }).click();
        await expect(page).toHaveTitle(/URL redirect with Amazon CloudFront and Amazon Route 53/);
    });
});

test.describe('Post: The human side of code reviews in large teams', () => {
    test('should be accessible from the blog page', async ({ page }) => {
        await page.goto('./blog');
        await expect(page).toHaveTitle(/Blog/);

        await page
            .getByRole('heading')
            .getByRole('link', { name: 'The human side of code reviews in large teams' })
            .click();
        await expect(page).toHaveTitle(/The human side of code reviews in large teams/);
    });
});

test.describe('Post: The power of coding conventions in large, distributed teams', () => {
    test('should be accessible from the blog page', async ({ page }) => {
        await page.goto('./blog');
        await expect(page).toHaveTitle(/Blog/);

        await page
            .getByRole('heading')
            .getByRole('link', { name: 'The power of coding conventions in large, distributed teams' })
            .click();
        await expect(page).toHaveTitle(/The power of coding conventions in large, distributed teams/);
    });
});

test.describe('Post: Beyond tabs and spaces: Finding a balance in coding conventions', () => {
    test('should be accessible from the blog page', async ({ page }) => {
        await page.goto('./blog');
        await expect(page).toHaveTitle(/Blog/);

        await page
            .getByRole('heading')
            .getByRole('link', { name: 'Beyond tabs and spaces: Finding a balance in coding conventions' })
            .click();
        await expect(page).toHaveTitle(/Beyond tabs and spaces: Finding a balance in coding conventions/);
    });
});

test.describe('Post: The renaissance of written coding conventions: Because AI reads manuals, too', () => {
    test('should be accessible from the home page', async ({ page }) => {
        await page.goto('./');
        await expect(page).toHaveTitle(/Broken Robot/);

        await page
            .getByRole('heading')
            .getByRole('link', { name: 'The renaissance of written coding conventions: Because AI reads manuals, too' })
            .click();
        await expect(page).toHaveTitle(/The renaissance of written coding conventions: Because AI reads manuals, too/);
    });

    test('should be accessible from the blog page', async ({ page }) => {
        await page.goto('./blog');
        await expect(page).toHaveTitle(/Blog/);

        await page
            .getByRole('heading')
            .getByRole('link', { name: 'The renaissance of written coding conventions: Because AI reads manuals, too' })
            .click();
        await expect(page).toHaveTitle(/The renaissance of written coding conventions: Because AI reads manuals, too/);
    });
});

test.describe('Post: Learned helplessness in software teams: Symptoms, causes, and the path to empowerment', () => {
    test('should be accessible from the home page', async ({ page }) => {
        await page.goto('./');
        await expect(page).toHaveTitle(/Broken Robot/);

        await page
            .getByRole('heading')
            .getByRole('link', {
                name: 'Learned helplessness in software teams: Symptoms, causes, and the path to empowerment'
            })
            .click();
        await expect(page).toHaveTitle(
            /Learned helplessness in software teams: Symptoms, causes, and the path to empowerment/
        );
    });

    test('should be accessible from the blog page', async ({ page }) => {
        await page.goto('./blog');
        await expect(page).toHaveTitle(/Blog/);

        await page
            .getByRole('heading')
            .getByRole('link', {
                name: 'Learned helplessness in software teams: Symptoms, causes, and the path to empowerment'
            })
            .click();
        await expect(page).toHaveTitle(
            /Learned helplessness in software teams: Symptoms, causes, and the path to empowerment/
        );
    });
});

test.describe('Post: Your AI Platform Will Inherit Your Engineering Culture', () => {
    test('should be accessible from the home page', async ({ page }) => {
        await page.goto('./');
        await expect(page).toHaveTitle(/Broken Robot/);

        await page
            .getByRole('heading')
            .getByRole('link', {
                name: 'Your AI Platform Will Inherit Your Engineering Culture'
            })
            .click();
        await expect(page).toHaveTitle(/Your AI Platform Will Inherit Your Engineering Culture/);
    });

    test('should be accessible from the blog page', async ({ page }) => {
        await page.goto('./blog');
        await expect(page).toHaveTitle(/Blog/);

        await page
            .getByRole('heading')
            .getByRole('link', {
                name: 'Your AI Platform Will Inherit Your Engineering Culture'
            })
            .click();
        await expect(page).toHaveTitle(/Your AI Platform Will Inherit Your Engineering Culture/);
    });
});
