# Review

<!-- Reviewed <date>, against the living specs and the change's planning artifacts. -->

## Findings

<!--
  Attack the change folder on this list. Under each item, give the findings as
  `artifact:line` + what is wrong + the concrete fix, or state that the item turned up nothing.
-->

### Untestable scenarios

<!-- A scenario whose WHEN/THEN cannot be exercised or observed. -->

### Requirements that contradict the living specs

<!-- A delta that conflicts with a requirement under openspec/specs/ without a MODIFIED or REMOVED entry for it. -->

### Tasks that use a primitive nobody establishes

<!-- A task that uses a .btn/.tag/.card/... class or a token that no earlier task creates and the codebase does not define. -->

### A missing tier decision

<!-- Interactive UI with no recorded interactivity-tier decision, or two tasks naming different tiers for one component. -->

### Unnamed scope

<!-- Work the tasks imply that the proposal never names, or a Non-Goals section that leaves the boundary open. -->

### A `skip_specs` claim that hides a behaviour change

<!-- The change sets skip_specs while a visitor, feed, crawler, or check would observe a difference. -->

## Verdict

<!-- One line: ready for the human's proposal gate, or what must change first. -->
