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
