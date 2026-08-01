# Proposal: generate the theme tokens

## Why

A maintainer edits the theme values by hand today, and a hand edit drifts from the design source
without failing anything. The token manifest removes the drift, because CI regenerates
the token manifest and compares the result against the committed copy.

## What changes

The build gains a generator that reads the design source and writes the token manifest. When the
generated token manifest and the committed token manifest differ, CI fails the run, because
a token manifest that drifted has lost the values the designer chose.

## What stays

Both themes keep their current values. The generator changes the source of the values, and the
generator does not change the values.
