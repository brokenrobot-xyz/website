# Tasks: refine the theme toggle

## 1. Tokens

- [ ] Add a `--focus-ring` role to both themes, because a component that reads a raw value
      ignores the theme the reader chose.
- [ ] Update the design tokens and the component styles, then verify that they render in both
      themes.

## 2. Component

- [ ] Restyle the theme toggle button focus ring so that the contrast ratio passes AA in both
      themes.
- [ ] When the theme toggle receives keyboard focus, render the focus ring at full opacity,
      because a focus ring that fades leaves a keyboard user unable to see the current control.

## 3. Verify

- [ ] Run the snapshot suite in both themes.

## 4. Review

- [ ] Attach the visual baseline run to the pull request, because a reviewer who cannot see the
      rendered change approves the pull request on trust alone.

## 5. Merge

- [ ] When the screenshot check reports no diff, squash-merge the branch.
