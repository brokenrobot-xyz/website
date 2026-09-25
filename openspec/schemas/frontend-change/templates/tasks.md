# Tasks

## 1. <!-- Task Group Name -->

- [ ] 1.1 <!-- Task description -->
- [ ] 1.2 <!-- Task description -->

## 2. <!-- Task Group Name -->

- [ ] 2.1 <!-- Task description -->
- [ ] 2.2 <!-- Task description -->

<!--
  Keep the Verify group LAST and renumber it to follow your work groups (e.g. ## 5. Verify).
  Do not drop or water down its items — mark view-dependent items N/A (with a short note) when the
  change touches no views. Every UI change carries both-theme visual + a11y coverage.
  This group is the change-wide gate over the finished change. A work group's own tests and docs
  belong in that group, not here.
-->

## N. Verify

- [ ] Visual + a11y snapshots pass in **both themes** for every touched view (testing-visual-regression skill)
- [ ] All preflight gate checks pass — the set in `docs/development/checks.md` (running-preflight-checks skill)
- [ ] Manual preview: no theme flash, interactions work, console clean, responsive at 375px
