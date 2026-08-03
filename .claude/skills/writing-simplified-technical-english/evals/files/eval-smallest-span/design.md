# Theme tokens

The site resolves every color through a two-layer token system. The base layer defines raw
values, and the semantic layer maps each raw value to a named role. The build performs a
validation of the semantic layer before the build emits CSS, so a role that references a missing
raw value fails the build rather than shipping a broken color.

Both themes are first-class. The light theme and the dark theme each declare a complete set of
semantic tokens, and neither theme inherits from the other, because an inherited theme drifts
when a maintainer edits the parent theme and does not check the child theme.

Components never reference a raw value, because a raw value carries one color in both themes and
ignores the theme the reader chose. When a component needs a color the semantic layer does not
carry, the component's author adds the role to both themes first, because a component that
bypasses the semantic layer renders correctly in one theme and wrongly in the other.

A generator produces the token file from a single source, and the generator runs in CI. When the
generated file and the committed file differ, the drift check fails the build, because a
hand-edited token file loses its changes when the generator next runs.
