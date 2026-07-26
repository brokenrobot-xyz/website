// The `SatteriAstroData` import also loads the `DataMap` augmentation that types `context.data.astro`.
import type { SatteriAstroData } from '@astrojs/markdown-satteri';
import getReadingTime from 'reading-time';
import { defineMdastPlugin } from 'satteri';
import type { MdastVisitorContext } from 'satteri';

declare module 'satteri' {
    interface DataMap {
        readingTime: { text: string };
    }
}

// Sätteri visits nodes by type and has no document-level hook, so the text is
// accumulated in the per-document data bag and the frontmatter is rewritten on
// each visit. The last write wins, and it is read only after the whole document
// has been compiled.
const appendText = (context: MdastVisitorContext, value: string): void => {
    const state = (context.data.readingTime ??= { text: '' });

    state.text += `${value}\n`;

    const astro: SatteriAstroData | undefined = context.data.astro;

    if (astro !== undefined) {
        astro.frontmatter.minutesRead = getReadingTime(state.text).text;
    }
};

const readingTimePlugin = defineMdastPlugin({
    name: 'reading-time',
    text: (node, context) => appendText(context, node.value),
    inlineCode: (node, context) => appendText(context, node.value),
    code: (node, context) => appendText(context, node.value),
    html: (node, context) => appendText(context, node.value)
});

export { readingTimePlugin };
