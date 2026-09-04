## 1. <!-- Task Group Name -->

- [ ] 1.1 <!-- Task description -->
- [ ] 1.2 <!-- Task description -->

## 2. <!-- Task Group Name -->

- [ ] 2.1 <!-- Task description -->
- [ ] 2.2 <!-- Task description -->

<!--
  Keep the Verify group LAST and renumber it to follow your work groups (e.g. ## 5. Verify).
  Do not drop or water down its items — every UI change carries both-theme visual + a11y coverage.
-->

## N. Verify

- [ ] Visual + a11y snapshots pass in **both themes** for every touched view (testing-visual-regression skill)
- [ ] All nine gate steps pass — `type:check`, `lint:check`, `format:check`, `specs:check`, `designmd:check`, `tokens:check`, `build`, `thirdparty:check`, `terraform:check` (running-preflight-checks skill)
- [ ] Manual preview: no theme flash, interactions work, console clean, responsive at 375px
