# Final Review Fix Wave Report

## Scope

Resolved all four findings from `final-fix-brief.md` without adding packages,
changing structured-filter behavior, or modifying the two authorized typed-date
baseline tests.

## RED evidence

1. Overlapping literal occurrences
   - Command: `rtk flutter test test/log_search_engine_test.dart --plain-name 'merges overlapping occurrences of one keyword'`
   - RED outcome: failed because searching `aa` in `aaa` produced the
     non-overlapping range ending at index 2 instead of the required merged
     `SearchRange(0, 3)`.
   - Production mutation caught: replacing overlap-aware prefix enumeration
     with `RegExp.allMatches`.

2. Highlighted payload text scaling
   - Command: `rtk flutter test test/log_row_search_highlight_test.dart --plain-name 'highlighted payload inherits the plain payload text scaler'`
   - RED outcome: failed with expected `linear (1.75x)`, actual `no scaling`.
   - Production mutation caught: removing the inherited text scaler from the
     highlighted `RichText`.

3. Variable-height destination visibility
   - Command: `rtk flutter test test/widget_test.dart --plain-name 'variable-height search navigation reveals the distant active row'`
   - Initial test-enabling RED: compilation identified the missing injectable
     base-entry input needed to exercise deterministic uneven rows.
   - Behavioral RED after supplying that input: failed because the destination
     key had zero mounted widgets, so its bounds could not be compared with the
     vertical viewport. The one-shot entry-fraction estimate had left source
     index 20 unbuilt.
   - Production mutation caught: restoring the one-shot fractional estimate or
     exiting when the first estimated position does not build the target.

## Implementation

- `lib/features/log_viewer/services/log_search_engine.dart`
  - Enumerates a literal regular expression at every Dart string start index
    with `matchAsPrefix`, preserving per-keyword case sensitivity and allowing
    overlaps before normal range merging.
- `lib/features/log_viewer/widgets/log_row.dart`
  - Applies `MediaQuery.textScalerOf(context)` directly to highlighted
    `RichText` while retaining the inspectable `TextSpan` tree.
- `lib/features/log_viewer/log_viewer_page.dart`
  - Accepts a base entry list, creates corresponding row keys, and uses that
    list consistently for searching and rendering.
  - Replaces the unverified fraction estimate with a bounded 40-iteration seek.
    The seek uses mounted row indexes to bracket the target, jumps only the
    vertical controller, checks the search generation before every step, and
    performs a precise vertical reveal once the row is built.
- `test/log_search_engine_test.dart`
  - Covers overlapping `aa` occurrences in `aaa` merging to `[0, 3]`.
- `test/log_row_search_highlight_test.dart`
  - Compares plain and highlighted rendered text scalers under a non-default
    `MediaQuery` scaler.
- `test/widget_test.dart`
  - Uses a constrained viewport, deliberately uneven row heights, and distant
    matches; asserts both active-row bounds are inside vertical viewport bounds.

## Commits

- Base: `e027a0d81625feb6885308277b31843f77be8962`
- Implementation and regression tests: `06c3fdb` (`fix: harden DLT search matching and navigation`)
- This report: committed separately as `docs: report final DLT search fix wave`.

## Verification

- `rtk dart format lib/features/log_viewer/log_viewer_page.dart lib/features/log_viewer/services/log_search_engine.dart lib/features/log_viewer/widgets/log_row.dart test/log_search_engine_test.dart test/log_row_search_highlight_test.dart test/widget_test.dart`
  - Passed; six files checked and all are formatted.
- `rtk flutter test test/log_search_engine_test.dart --plain-name 'merges overlapping occurrences of one keyword'`
  - Passed: 1/1.
- `rtk flutter test test/log_row_search_highlight_test.dart --plain-name 'highlighted payload inherits the plain payload text scaler'`
  - Passed: 1/1.
- `rtk flutter test test/widget_test.dart --plain-name 'variable-height search navigation reveals the distant active row'`
  - Passed: 1/1.
- `rtk flutter test test/widget_test.dart --plain-name 'search navigation preserves the table horizontal scroll offset'`
  - Passed: 1/1.
- `rtk flutter test test/widget_test.dart --plain-name 'overlapping search navigation settles on the latest active match'`
  - Passed: 1/1.
- `rtk flutter test test/log_search_engine_test.dart test/log_row_search_highlight_test.dart test/search_panel_test.dart`
  - Passed: 16/16 search unit/component tests.
- `rtk flutter analyze`
  - Passed: no issues found.
- `rtk flutter test`
  - 66 tests passed. The only failures were the two explicitly authorized
    baselines:
    - `a valid typed start date applies only after blur`
    - `an invalid typed date does not update the filter`
- `rtk git diff --check`
  - Passed with no whitespace errors.

## Self-review

- Confirmed overlap ranges are merged by the existing stable range-merging
  path and existing case-sensitive/literal-text tests remain green.
- Confirmed the scaling test exercises actual rendered `RichText` widgets and
  retains the focused span-tree assertions.
- Confirmed the visibility regression checks geometry, not merely key
  existence.
- Confirmed seek operations use only the vertical scroll controller; the
  focused horizontal-offset test remains green.
- Confirmed every asynchronous seek step and the final reveal retain the Task 4
  generation guard; the rapid query-change regression remains green.
- Confirmed row selection state is untouched by search navigation.
- Reviewed the diff for unrelated structured-filter or date-input changes;
  none are present.

## Concerns

- The full suite still contains the two authorized typed-date baseline failures
  listed above; they were not changed by this wave.
- Flutter reports newer incompatible package versions during dependency
  resolution, but this wave adds or updates no dependencies.
