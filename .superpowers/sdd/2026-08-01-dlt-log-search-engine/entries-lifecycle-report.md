# Base Entries Lifecycle Refresh Report

## Scope

Implemented lifecycle reconciliation for replacement `LogViewerPage.entries`
lists without changing search semantics, structured-filter behavior, date-input
baselines, dependencies, text scaling, variable-height seeking, horizontal
scroll position, or generation cancellation guarantees.

## RED evidence

- Command: `rtk flutter test test/log_viewer_entries_lifecycle_test.dart`
- Outcome: all four new parent-driven widget tests failed against base
  `7730bdde6e0f1f99951f80b11457ce1f384a7c64` for the intended reasons:
  - shorter replacement retained stale ranges and threw
    `RangeError (end): Invalid value ... 0..6: 20`;
  - longer replacement retained the old result count, so expected `1/2` was
    absent;
  - the identical selected entry moved source index but the active-row key was
    absent;
  - empty replacement in `Matches only` threw
    `RangeError (length): Valid value range is empty: 0`.
- Production mutations caught: removing entry-list identity detection, match
  recomputation, row-key rebuilding, active-result clamping, identity-based
  selection reconciliation, or empty-list handling.

## GREEN evidence

- Command: `rtk flutter test test/log_viewer_entries_lifecycle_test.dart`
- Outcome: passed 4/4 after implementation, including a fresh pre-commit run.

## Implementation and files

- `lib/features/log_viewer/log_viewer_page.dart`
  - Detects replacement list identity in `didUpdateWidget`.
  - Invalidates the current scroll generation before reconciliation.
  - Rebuilds a `GlobalKey` for every new source index.
  - Recomputes search matches and highlight ranges from the replacement list
    with the unchanged keyword models and search engine.
  - Retains a valid active result ordinal, clamps it when needed, or resets to
    the empty `0/0` state.
  - Preserves manual selection by `LogEntry` identity, otherwise clamps the
    previous source position, with no selection for an empty list.
  - Defers the post-update active-result scroll behind a generation guard so an
    intervening update or navigation wins.
- `lib/features/log_viewer/widgets/log_table.dart`
  - Accepts a nullable active source index to represent no selection safely.
- `test/log_viewer_entries_lifecycle_test.dart`
  - Adds a stateful parent harness that updates the same `LogViewerPage` state.
  - Covers shorter recomputation/ranges, longer navigation and visibility,
    identity preservation plus fallback clamping, and empty `Matches only`.

## Commits

- Base: `7730bdde6e0f1f99951f80b11457ce1f384a7c64`
- Implementation and regression tests: `ff05c9c879a1c620f0105dbad80e62f71255dce2`
  (`fix: reconcile refreshed log entries`)
- This report: committed separately as
  `docs: report base entries lifecycle refresh`.

## Verification

- `rtk dart format lib/features/log_viewer/log_viewer_page.dart lib/features/log_viewer/widgets/log_table.dart test/log_viewer_entries_lifecycle_test.dart`
  - Passed; three files formatted with no final changes.
- `rtk flutter test test/log_viewer_entries_lifecycle_test.dart`
  - Passed: 4/4 lifecycle tests.
- `rtk flutter test test/log_search_engine_test.dart test/log_row_search_highlight_test.dart test/widget_test.dart --name 'merges overlapping|text scaler|horizontal scroll offset|variable-height search navigation|overlapping search navigation'`
  - Passed: 6/6 overlap, accessibility scaling, horizontal-offset,
    variable-height visibility, and latest-generation navigation regressions.
- `rtk flutter test test/log_search_engine_test.dart test/log_row_search_highlight_test.dart test/search_panel_test.dart test/log_viewer_entries_lifecycle_test.dart`
  - Passed: 20/20 focused search unit/component/lifecycle tests.
- `rtk flutter test test/widget_test.dart --name 'search|keyword|Matches only|match case|OR becomes|navigation buttons'`
  - Passed: 21/21 focused search widget integration tests.
- `rtk flutter analyze`
  - Passed: no issues found.
- `rtk flutter test`
  - 70 tests passed. The only failures were the two explicitly permitted
    baselines:
    - `a valid typed start date applies only after blur`
    - `an invalid typed date does not update the filter`
- `rtk git diff --check`
  - Passed with no whitespace errors before the implementation commit.

## Self-review

- Confirmed list identity, rather than content equality, gates lifecycle work,
  matching the caller contract that replacement uses a new `List` object.
- Confirmed every old asynchronous scroll is invalidated before keys and
  matches change, and the deferred replacement scroll runs only if still the
  latest generation.
- Confirmed replacement scrolling continues to use only the vertical
  controller; the horizontal-offset regression remains green.
- Confirmed active-match clamping cannot index an empty or shorter match list.
- Confirmed selection uses explicit object identity before source-position
  fallback and safely supports an empty input.
- Confirmed `Matches only` is retained on replacement and existing keyword
  removal remains the only path that restores `All logs` for empty keywords.
- Confirmed no structured-filter, date-input, search-engine, text-scaling, or
  dependency files changed.
- Independent code review reported no Critical, Important, or Minor findings
  and assessed the implementation ready after report/commit bookkeeping.

## Concerns

- The full suite retains the two authorized typed-date baseline failures listed
  above; they were not modified by this follow-up.
- Flutter reports newer package versions incompatible with current constraints
  during dependency resolution; this follow-up adds or updates no packages.

## Final Review v2 Fix Wave

### Scope and implementation

- `lib/features/log_viewer/log_viewer_page.dart`
  - Initializes the default manual selection from the actual initial entry
    count: `null` for an empty input and the existing sample index clamped to a
    valid source index otherwise.
  - Keeps a `null` selection through an empty-to-nonempty replacement instead
    of inventing a selection that never existed.
- `test/log_viewer_entries_lifecycle_test.dart`
  - Covers short and empty initial inputs plus empty-to-nonempty replacement.
  - Starts a distant seek, proves vertical movement is already in flight, then
    proves replacement recomputation and scrolling win at the new generation.
  - Proves the current per-keyword OR mode and case-sensitive option survive a
    parent-driven replacement and determine the recomputed matches.
- `test/log_search_engine_test.dart`
  - Covers truly adjacent, non-overlapping `data` and `base` ranges in
    `database` and expects one merged range.
- Source and tests commit:
  `74f88ae2b33320bc749773575af4eb3d4dc1f574`
  (`fix: complete entries lifecycle review`).

### RED evidence

- Command:
  `rtk flutter test test/log_viewer_entries_lifecycle_test.dart --name 'short initial entries clamp|empty initial entries have no selection|empty to nonempty replacement preserves no selection'`
  - With only the initialization/reconciliation fix temporarily restored to
    the pre-fix behavior, failed 3/3 for the intended reasons: the short list
    had no active last row, the empty list exposed active index `5`, and the
    empty-to-nonempty replacement invented an active row.
- Command:
  `rtk flutter test test/log_viewer_entries_lifecycle_test.dart --name 'entry replacement supersedes an in-flight distant search seek'`
  - With only the post-replacement active-result scroll temporarily removed,
    failed because the replacement active row was not built/visible. The test
    first asserted a positive vertical offset after 20 ms, proving the distant
    scroll had started before replacement.
- Command:
  `rtk flutter test test/log_viewer_entries_lifecycle_test.dart --name 'entry replacement retains keyword logic and case options for recompute'`
  - With replacement recomputation temporarily reduced to default AND and
    case-insensitive keyword models, failed because the lowercase `error` row
    was incorrectly highlighted.
- Command:
  `rtk flutter test test/log_search_engine_test.dart --name 'merges truly adjacent keyword ranges'`
  - With the merge boundary temporarily changed from `<=` to `<`, failed
    because two ranges were returned instead of the expected single `[0, 8)`
    range.
- Every temporary mutation was restored before GREEN verification; no
  mutation remains in the committed diff.

### GREEN and regression evidence

- Command:
  `rtk dart format lib/features/log_viewer/log_viewer_page.dart test/log_search_engine_test.dart test/log_viewer_entries_lifecycle_test.dart`
  - Passed; three files formatted, zero changes required.
- Command:
  `rtk flutter test test/log_viewer_entries_lifecycle_test.dart test/log_search_engine_test.dart --name 'short initial entries clamp|empty initial entries have no selection|empty to nonempty replacement preserves no selection|entry replacement supersedes an in-flight distant search seek|entry replacement retains keyword logic and case options for recompute|merges truly adjacent keyword ranges'`
  - Passed 6/6 Final Review v2 focused tests.
- Command:
  `rtk flutter test test/log_viewer_entries_lifecycle_test.dart`
  - Passed 9/9 lifecycle tests.
- Command:
  `rtk flutter test test/log_search_engine_test.dart test/log_row_search_highlight_test.dart test/widget_test.dart --name 'merges overlapping|text scaler|horizontal scroll offset|variable-height search navigation|overlapping search navigation'`
  - Passed 6/6 overlap, text-scaling, horizontal-offset, variable-height, and
    latest-generation regressions.
- Command:
  `rtk flutter test test/log_search_engine_test.dart test/log_row_search_highlight_test.dart test/search_panel_test.dart test/log_viewer_entries_lifecycle_test.dart`
  - Passed 26/26 search unit, highlight, panel, and lifecycle tests.
- Command:
  `rtk flutter test test/widget_test.dart --name 'search|keyword|Matches only|match case|OR becomes|navigation buttons'`
  - Passed 21/21 search widget integration tests.
- Command: `rtk flutter analyze`
  - Passed with `No issues found!`.
- Command: `rtk flutter test`
  - 76 tests passed. The only failures were the same two authorized typed-date
    baselines:
    - `a valid typed start date applies only after blur`
    - `an invalid typed date does not update the filter`
- Command: `rtk git diff --check`
  - Passed with no whitespace errors before the source/test commit.

### Self-review

- Confirmed initialization reads `widget.entries` only after state setup and
  cannot expose an out-of-range manual selection for short or empty inputs.
- Confirmed `null` means no prior valid selection and remains `null` across
  replacement; identity preservation and source-position clamping continue to
  apply only when a valid prior selection exists.
- Confirmed the in-flight replacement test observes movement before updating
  the same stateful `LogViewerPage`, then verifies the new active row is fully
  visible at offset zero after settlement.
- Confirmed the option-retention test drives real chip controls: `timeout` is
  OR while `ERROR` remains AND and becomes case-sensitive, so only exact-case
  AND matches survive replacement.
- Confirmed the adjacent-range expectation is a hand-derived literal and fails
  if adjacency is treated as separation.
- Re-ran all prior overlap, text-scaling, variable-height, horizontal-offset,
  and rapid-navigation coverage; none regressed.
- Diff scope is limited to the page lifecycle source, the two search/lifecycle
  test files, and this report. No structured-filter or date-input code changed.

### Concerns

- The full suite still has the two explicitly authorized typed-date baseline
  failures above; this fix wave did not touch that area.
- Dependency resolution continues to report seven newer package versions that
  are incompatible with current constraints; no dependency changed here.
