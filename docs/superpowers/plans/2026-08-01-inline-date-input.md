# Inline Date Input Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users edit DLT time-range dates as `YYYY-MM-DD` and apply valid values on focus loss.

**Architecture:** Keep `_TimeRangePanel` as the single owner of start/end boundary state. Replace each date `InputDecorator` with a controlled `TextField`; on blur, parse its date text, retain the boundary's existing time, and route the result through the panel's existing range-update logic.

**Tech Stack:** Flutter, Dart, Material 3, flutter_test.

## Global Constraints

- A date input displays and accepts only `YYYY-MM-DD`.
- Hour and minute remain independent controls.
- Valid date text applies only when its field loses focus.
- Invalid text stays visible and never changes filter state.
- Calendar choice updates the matching editable date input.
- A filter update requires both boundaries to form a chronological range.

---

## File Structure

- Modify: `lib/features/log_viewer/widgets/filter_strip.dart` — turn date display into focus-aware editable inputs and preserve current time values.
- Modify: `test/widget_test.dart` — cover valid blur, invalid blur, and independent time preservation.

### Task 1: Add date-input regression tests

**Files:** Modify `test/widget_test.dart`.

**Produces:** Widget tests that define date-only direct input semantics.

- [ ] **Step 1: Write failing blur tests**

```dart
testWidgets('a valid typed start date applies only after blur', (tester) async {
  await openTimeRangeFilter(tester);
  final input = find.byKey(const Key('time_range_start_input'));
  await tester.tap(input);
  await tester.enterText(input, '2026-08-02');
  expect(find.text('Select...'), findsOneWidget);
  await tester.tap(find.byKey(const Key('time_range_end_input')));
  await tester.pumpAndSettle();
  expect(find.text('2026-08-02 00:00 –'), findsOneWidget);
});

testWidgets('an invalid typed date does not update the filter', (tester) async {
  await openTimeRangeFilter(tester);
  final input = find.byKey(const Key('time_range_start_input'));
  await tester.enterText(input, '2026-02-30');
  await tester.tap(find.byKey(const Key('time_range_end_input')));
  await tester.pumpAndSettle();
  expect(find.text('Select...'), findsOneWidget);
  expect(find.text('2026-02-30'), findsOneWidget);
});
```

- [ ] **Step 2: Verify RED**

Run: `flutter test test/widget_test.dart --plain-name 'a valid typed start date applies only after blur'`

Expected: FAIL because no editable date input exists.

### Task 2: Implement focus-aware date input

**Files:** Modify `lib/features/log_viewer/widgets/filter_strip.dart` and `test/widget_test.dart`.

**Consumes:** `_TimeRangePanel._start`, `_TimeRangePanel._end`, `_updateBoundary`, and `_formatDateTime`.

**Produces:** `_DateTimeSection` date input callbacks and date-only formatter/parser.

- [ ] **Step 1: Implement the smallest input API**

```dart
class _DateTimeSection extends StatelessWidget {
  const _DateTimeSection({
    required this.dateInputKey,
    required this.dateText,
    required this.onDateSubmitted,
    // existing fields
  });
}
```

Give each section a `FocusNode` and `TextEditingController` owned and disposed by `_TimeRangePanel`. Build a `TextField(key: dateInputKey, controller: controller)` with hint `YYYY-MM-DD`. On `FocusNode` loss, call `onDateSubmitted(controller.text)`.

Parse only exact `YYYY-MM-DD` values by matching `RegExp(r'^\\d{4}-\\d{2}-\\d{2}$')`, then construct and verify the date components to reject overflow dates. For a valid date, call `_updateBoundary` with its existing hour/minute or zero values. For invalid text, retain both controller text and boundary state.

Update controllers when `_updateBoundary` receives a calendar date so direct text and calendar choice stay synchronized.

- [ ] **Step 2: Add a time-preservation test**

```dart
testWidgets('typing a date preserves the selected start time', (tester) async {
  await openTimeRangeFilter(tester);
  await selectTimeOption(tester, const Key('time_range_start_hour'),
      const Key('time_range_start_hour_options'),
      const Key('time_range_start_hour_option_10'));
  await selectTimeOption(tester, const Key('time_range_start_minute'),
      const Key('time_range_start_minute_options'),
      const Key('time_range_start_minute_option_30'));
  final input = find.byKey(const Key('time_range_start_input'));
  await tester.enterText(input, '2026-08-02');
  await tester.tap(find.byKey(const Key('time_range_end_input')));
  await tester.pumpAndSettle();
  expect(find.text('2026-08-02 10:30'), findsOneWidget);
});
```

- [ ] **Step 3: Verify GREEN**

Run: `flutter test test/widget_test.dart --plain-name 'a valid typed start date applies only after blur' && flutter test test/widget_test.dart --plain-name 'an invalid typed date does not update the filter' && flutter test test/widget_test.dart --plain-name 'typing a date preserves the selected start time'`

Expected: all three tests PASS.

- [ ] **Step 4: Run complete verification and commit**

Run: `dart format lib test && flutter analyze && flutter test`

Expected: formatter reports no pending changes, analyzer reports no issues, and the full suite passes.

Commit:

```bash
git add lib/features/log_viewer/widgets/filter_strip.dart test/widget_test.dart
git commit -m "feat: allow direct DLT date input"
```

## Self-Review

- Tests prove blur-only application, invalid-input preservation, and time preservation.
- The plan keeps calendar and hour/minute interactions while giving dates a direct-entry path.
- No new dependency or separate parser abstraction is required.
