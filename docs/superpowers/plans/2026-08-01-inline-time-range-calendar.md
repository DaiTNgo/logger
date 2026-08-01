# Inline Time Range Calendar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Time range date/time dialogs with inline calendars and 24-hour controls inside the filter dropdown.

**Architecture:** Create a private stateful time-range panel in `filter_strip.dart`. It owns draft Start/End values and which date field is expanded; it emits a completed `DltFilter` on outside dismissal. The existing overlay remains the only popup layer.

**Tech Stack:** Flutter, Dart, Material 3, flutter_test.

## Global Constraints

- Never open `showDatePicker`, `showTimePicker`, or `showDialog` from Time range.
- Clicking the Start or End date field expands its `CalendarDatePicker` inline in the same dropdown.
- Start/End controls use a 24-hour clock: hour `00–23`, minute `00–59`, no AM/PM.
- Use `AppColors.surface`, `surfaceContainer`, `border`, `text`, and `secondaryText`.
- Draft values apply only when both Start and End are complete.

---

### Task 1: Build inline date controls

**Files:** Modify `lib/features/log_viewer/widgets/filter_strip.dart`; modify `test/widget_test.dart`.

- [ ] **Step 1: Write the failing inline-calendar test**

```dart
testWidgets('time range expands an inline calendar without a dialog', (tester) async {
  await tester.pumpWidget(const MyApp());
  await openFilterMenu(tester);
  await tester.tap(find.byKey(const Key('add_filter_time_range')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('filter_value_time_range')));
  await tester.tap(find.byKey(const Key('time_range_start_date')));
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('inline_start_calendar')), findsOneWidget);
  expect(find.byType(AlertDialog), findsNothing);
});
```

- [ ] **Step 2: Verify RED**

Run: `flutter test test/widget_test.dart --plain-name 'time range expands an inline calendar without a dialog'`

Expected: FAIL because the current date control opens a dialog.

- [ ] **Step 3: Implement stateful inline panel**

Replace the Time range child with `_InlineTimeRangePanel`. Give it `DltFilter filter` and `ValueChanged<DltFilter> onComplete`. Its state owns `DateTime? startDate`, `DateTime? endDate`, `bool startCalendarVisible`, and `bool endCalendarVisible`. Date fields use keys `time_range_start_date` and `time_range_end_date`; render one keyed `CalendarDatePicker` below the active date field.

- [ ] **Step 4: Verify GREEN**

Run: `flutter test test/widget_test.dart --plain-name 'time range expands an inline calendar without a dialog'`

Expected: PASS.

### Task 2: Add 24-hour time controls and completion

**Files:** Modify `lib/features/log_viewer/widgets/filter_strip.dart`; modify `test/widget_test.dart`.

- [ ] **Step 1: Write the failing completion test**

```dart
testWidgets('inline Start and End values render a complete 24-hour range', (tester) async {
  // Select a Start date, Start hour/minute, End date, and End hour/minute.
  // Dismiss the dropdown.
  expect(find.text('2026-08-01 09:41 – 2026-08-01 11:59'), findsOneWidget);
});
```

- [ ] **Step 2: Verify RED**

Run: `flutter test test/widget_test.dart --plain-name 'inline Start and End values render a complete 24-hour range'`

Expected: FAIL because hour/minute controls do not compose draft timestamps.

- [ ] **Step 3: Implement time selection**

Use dropdown controls with keys `time_range_start_hour`, `time_range_start_minute`, `time_range_end_hour`, and `time_range_end_minute`. Generate literal options `00` through `23` and `00` through `59`. Compose `YYYY-MM-DD HH:mm`; call `onComplete` only when both composed timestamps exist during dropdown dismissal.

- [ ] **Step 4: Verify full regression**

Run: `dart format lib test && flutter analyze && flutter test`

Expected: formatter completes, analyzer reports no issues, and all widget tests pass.

## Self-Review

- The only overlay is the existing Time range dropdown.
- Inline calendars, 24-hour fields, and Start/End completion are all test-covered.
- The workspace has no Git repository, so no commit step is available.
