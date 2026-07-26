import { defineHastPlugin } from 'satteri';

// Code blocks scroll horizontally when they overflow, and a scrollable region has to be
// reachable by keyboard (axe: scrollable-region-focusable). Shiki used to emit `tabindex="0"`
// on the <pre> itself; Prism does not, so add it here.
const codeBlockFocusPlugin = defineHastPlugin({
    name: 'code-block-focus',
    element: {
        filter: ['pre'],
        visit: (node, context) => {
            context.setProperty(node, 'tabIndex', 0);
        }
    }
});

export { codeBlockFocusPlugin };
