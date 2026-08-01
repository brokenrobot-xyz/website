# Tasks: generate the theme tokens

## 1. Generator

- [ ] Write the generator so that the generator reads the design source and emits
      the generated token file.
- [ ] When the design source holds a value no theme uses, omit the value from
      the generated token file, because an unused value grows the stylesheet without
      changing what a reader sees.

## 2. CI

- [ ] Add a step that regenerates the generated token file and compares the result
      against the committed copy.
- [ ] When the two files differ, fail the run.
