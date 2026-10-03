---
name: red-green-tdd
description: Use red/green TDD with lamdera/program-test for new features and bug fixes - write a failing E2E test first, then implement until it passes.
---

# Red/Green TDD with lamdera/program-test

Every new feature or bug fix starts with a failing `tests/E2ETests.elm`
test. No exceptions for "small" changes. Lamdera E2E tests are fast and
deterministic, so there's no cost excuse for skipping the red step.

## The loop

1. **Red.** Add a test that exercises the desired behavior from the
   user's point of view (a keypress, a button click, a view assertion).
   Wire it into the `tests` list in `tests/E2ETests.elm`. Run
   `npm test` and **confirm it fails for the right reason** — usually
   "element not found" or a value mismatch. If it fails because the
   test file doesn't compile, fix the compile error first; that's not
   a real red.
2. **Green.** Make the minimum change in `src/` to pass. Run
   `npm test`. Stop when the whole suite passes.
3. **Report both phases** in the final message: which test failed at
   red, which assertion drove each implementation choice.

## What "for the right reason" means

Before writing code, the failure should point at the missing
behavior:

- New element → a `findById "new-element-id"` selector returns 0 matches.
- New computation/state → an assertion on the rendered value (e.g.
  `Query.has [ Selector.text "1/5" ]`) fails against the current output.
- Bug fix → the test reproduces the bug; the failing assertion shows
  the wrong observed state.

A test that fails because of a typo, missing import, or unrelated
compile error is not red — fix it and re-run until the failure is
the *behavioral* one.

## Why not skip the test for "obvious" changes

The point isn't proof-of-correctness, it's:

- Forces a concrete spec before code (what should the view show in
  this state, exactly?).
- Catches accidental regressions in unrelated tests (a drop in the
  passing count is a louder signal than "looks fine").
- Leaves a permanent guard against future refactors that break the
  behavior.

## Conventions worth keeping

- **Factor out DSL helpers in `tests/E2ETests.elm`.** As soon as an
  interaction (a login flow, a multi-key sequence, a "click this button
  by id" action) recurs, wrap it in a small helper and reuse it rather
  than hand-rolling `client.click` / `client.input` in every test — the
  tests stay readable and a UI change updates in one place.
- **Selectors — `data-testid` first, `id` where required:** `data-testid`
  is the preferred hook for `checkView` assertions because it's a
  test-only attribute that won't be repurposed for styling/behavior.
  Plain `id` is *required* for the interaction actions —
  `client.click` / `client.input` (and `Dom.id`) key off `id`, not
  `data-testid` — so buttons and inputs must carry an `id`. It's fine to
  reuse that same `id` in a `findById` assertion. When you add an element
  purely to assert against, prefer a `data-testid`.
- **Keys from a document subscription can't be simulated directly.** If
  input arrives via a document-level `onKeyDown` subscription (not a
  focused `<input>`), `program-test` can't dispatch it — add a helper
  that injects the resulting msg instead.
- **Deterministic clock:** fix "now" at the top of the test file and
  advance it with `Effect.Test.fastForward` / per-action ms offsets when
  testing time-dependent behavior.
- **Backend assertions:** use `Effect.Test.checkBackend` to assert on the
  `BackendModel` directly (e.g. that a `ToBackend` msg persisted state)
  rather than only checking the rendered view.

## See also

- `/testing-quick-ref` — basic test structure
- `/testing-user-interaction` — click/input patterns
- `/testing-view-assertions` — selector patterns
- `/testing-pitfalls` — common mistakes
