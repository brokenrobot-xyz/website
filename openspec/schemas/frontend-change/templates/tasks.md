## 1. <!-- Task Group Name -->

- [ ] 1.1 <!-- Task description -->
- [ ] 1.2 <!-- Task description -->

## 2. <!-- Task Group Name -->

- [ ] 2.1 <!-- Task description -->
- [ ] 2.2 <!-- Task description -->

<!--
  Keep the Verify group LAST and renumber it to follow your work groups (e.g. ## 5. Verify).
  Do not drop or water down its items — mark view-dependent items N/A (with a short note) when the
  change touches no views. Every UI change carries visual + a11y coverage in both themes; dark rests
  on manual review until the dark Playwright projects are wired.
-->

## N. Verify

- [ ] Visual + a11y snapshots pass for every touched view — light via the Playwright projects, dark by manual review until the dark projects are wired (testing-visual-regression skill)
- [ ] All eight gate steps pass — `type:check`, `lint:check`, `format:check`, `specs:check`, `designmd:check`, `tokens:check`, `build`, `thirdparty:check` (running-preflight-checks skill)
- [ ] Manual preview: no theme flash, interactions work, console clean, responsive at 375px
