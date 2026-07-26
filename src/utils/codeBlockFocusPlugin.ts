import { defineHastPlugin } from 'satteri';

// Code blocks scroll horizontally when they overflow, and a scrollable region has to be
// reachable by keyboard (axe: scrollable-region-focusable). Shiki used to emit `tabindex="0"`
// on the <pre> itself; Prism does not, so add it here.
const codeBlockFocusPlugin = defineHastPlugin({
    name: 'code-block-focus',
    element: {
        filter: ['pre'],
        visit: (node, context) => {
            // Lowercase on purpose: Sätteri serializes the key verbatim into the HTML
            // attribute, so the hast-conventional `tabIndex` would emit `tabIndex="0"`.
            context.setProperty(node, 'tabindex', 0);
        }
    }
});

export { codeBlockFocusPlugin };
