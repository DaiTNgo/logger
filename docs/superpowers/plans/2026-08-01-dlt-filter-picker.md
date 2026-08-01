# DLT Filter Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a DLT-specific filter picker with multi-value, single-value, and time-range chips.

**Architecture:** Put DLT field definitions and selected-filter state in a focused model. `LogViewerPage` owns active filters; `FilterStrip` owns the anchored field menu, chip presentation, and value popovers.

**Tech Stack:** Flutter, Dart, Material 3, flutter_test.

## Global Constraints

- Exclude Payload; keyword search is responsible for payload text.
- Menu fields: ECU ID, APID, CTID, Message Type, Log Level, Trace Type, Network Type, Header Type, Verbose Mode, Message Counter, Length, Number of Arguments, Session ID, Time range.
- ECU ID, APID, CTID, Message Type, Log Level, Trace Type, and Network Type use `Field | is | Select... | ×` and accept several values.
- Header Type, Verbose Mode, Message Counter, Length, Number of Arguments, Session ID, and Time range use `Field | Select... | ×`.
- Time range stores inclusive start/end timestamps.
- Re-selecting an active field edits it instead of creating a duplicate.
- Preserve horizontal scrolling and narrow-screen behavior.

---

## File Structure

- Create: `lib/features/log_viewer/models/dlt_filter.dart` — catalog, filter type, and selected values/range.
- Modify: `lib/features/log_viewer/log_viewer_page.dart` — DLT filter state and mutations.
- Modify: `lib/features/log_viewer/widgets/filter_strip.dart` — picker, chip variants, and selectors.
- Modify: `test/widget_test.dart` — end-to-end widget coverage.

### Task 1: Model the catalog

**Files:** Create `lib/features/log_viewer/models/dlt_filter.dart`; modify `test/widget_test.dart`.

**Produces:** `DltFilterMode { multiValue, singleValue, timeRange }`, `DltFilterDefinition`, `DltFilter`, and a constant catalog of all fourteen non-payload fields.

- [ ] **Step 1: Write the failing field-menu test**

```dart
testWidgets('Add filter lists all non-payload DLT fields', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1600, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const MyApp());
  await tester.tap(find.byKey(const Key('add_filter_button')));
  await tester.pumpAndSettle();
  for (final label in const [
    'ECU ID', 'APID', 'CTID', 'Message Type', 'Log Level', 'Trace Type',
    'Network Type', 'Header Type', 'Verbose Mode', 'Message Counter',
    'Length', 'Number of Arguments', 'Session ID', 'Time range',
  ]) {
    expect(find.text(label), findsOneWidget);
  }
  expect(find.text('Payload'), findsNothing);
});
```

- [ ] **Step 2: Verify RED**

Run: `flutter test test/widget_test.dart --plain-name 'Add filter lists all non-payload DLT fields'`

Expected: FAIL because the existing dialog has a small dropdown.

- [ ] **Step 3: Add the model**

```dart
enum DltFilterMode { multiValue, singleValue, timeRange }

class DltFilterDefinition {
  const DltFilterDefinition({required this.id, required this.label, required this.mode, this.options = const []});
  final String id;
  final String label;
  final DltFilterMode mode;
  final List<String> options;
}

class DltFilter {
  const DltFilter({required this.fieldId, this.values = const [], this.rangeStart, this.rangeEnd});
  final String fieldId;
  final List<String> values;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
}
```

Add all fourteen definitions, assigning modes from Global Constraints.

- [ ] **Step 4: Verify GREEN after Task 2 connects the catalog**

Run: `flutter test test/widget_test.dart --plain-name 'Add filter lists all non-payload DLT fields'`

Expected: PASS.

### Task 2: Add the field picker and empty chips

**Files:** Modify `lib/features/log_viewer/log_viewer_page.dart`, `lib/features/log_viewer/widgets/filter_strip.dart`, and `test/widget_test.dart`.

**Consumes:** `dltFilterDefinitions` and `DltFilter` from Task 1.

**Produces:** `onSelectField(String fieldId)` and `_addOrFocusFilter(String fieldId)`.

- [ ] **Step 1: Write the failing selection test**

```dart
testWidgets('selecting a DLT field adds one empty filter chip', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1600, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const MyApp());
  await tester.tap(find.byKey(const Key('add_filter_button')));
  await tester.tap(find.byKey(const Key('add_filter_ecu_id')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('dlt_filter_ecu_id')), findsOneWidget);
  expect(find.text('Select...'), findsOneWidget);
});
```

- [ ] **Step 2: Verify RED**

Run: `flutter test test/widget_test.dart --plain-name 'selecting a DLT field adds one empty filter chip'`

Expected: FAIL because menu items do not exist.

- [ ] **Step 3: Implement minimal picker**

Replace the dialog with an anchored Material menu below `add_filter_button`. Give each item `Key('add_filter_<id>')`. In `_addOrFocusFilter`, use `indexWhere((filter) => filter.fieldId == fieldId)`; append one empty filter only when the result is `-1`.

- [ ] **Step 4: Verify GREEN**

Run: `flutter test test/widget_test.dart --plain-name 'selecting a DLT field adds one empty filter chip'`

Expected: PASS.

### Task 3: Multi-value chip and selector

**Files:** Modify `lib/features/log_viewer/log_viewer_page.dart`, `lib/features/log_viewer/widgets/filter_strip.dart`, and `test/widget_test.dart`.

**Produces:** `onUpdateFilter(DltFilter filter)` and a checkbox value selector for `multiValue` definitions.

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('ECU ID uses is and stores multiple selected values', (tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.tap(find.byKey(const Key('add_filter_button')));
  await tester.tap(find.byKey(const Key('add_filter_ecu_id')));
  await tester.tap(find.byKey(const Key('filter_value_ecu_id')));
  await tester.tap(find.text('ECU_MAIN'));
  await tester.tap(find.text('ECU_BACKUP'));
  await tester.tap(find.byKey(const Key('confirm_filter_values')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('filter_operator_ecu_id')), findsOneWidget);
  expect(find.text('is'), findsOneWidget);
  expect(find.text('ECU_MAIN, ECU_BACKUP'), findsOneWidget);
});
```

- [ ] **Step 2: Verify RED**

Run: `flutter test test/widget_test.dart --plain-name 'ECU ID uses is and stores multiple selected values'`

Expected: FAIL because multi-value state and its selector do not exist.

- [ ] **Step 3: Implement multi-value behavior**

Render label, keyed `is` segment, tappable keyed value segment, and ×. The selector prechecks existing values and confirms a `List<String>` back to `onUpdateFilter`.

- [ ] **Step 4: Verify GREEN**

Run: `flutter test test/widget_test.dart --plain-name 'ECU ID uses is and stores multiple selected values'`

Expected: PASS.

### Task 4: Single-value and time-range selectors

**Files:** Modify `lib/features/log_viewer/log_viewer_page.dart`, `lib/features/log_viewer/widgets/filter_strip.dart`, and `test/widget_test.dart`.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('Verbose Mode has no is segment and accepts one value', (tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.tap(find.byKey(const Key('add_filter_button')));
  await tester.tap(find.byKey(const Key('add_filter_verbose_mode')));
  await tester.tap(find.byKey(const Key('filter_value_verbose_mode')));
  await tester.tap(find.text('Verbose'));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('filter_operator_verbose_mode')), findsNothing);
  expect(find.text('Verbose'), findsOneWidget);
});

testWidgets('Time range stores an inclusive start and end time', (tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.tap(find.byKey(const Key('add_filter_button')));
  await tester.tap(find.byKey(const Key('add_filter_time_range')));
  await tester.enterText(find.byKey(const Key('time_range_start')), '2026-08-01 10:00');
  await tester.enterText(find.byKey(const Key('time_range_end')), '2026-08-01 11:00');
  await tester.tap(find.byKey(const Key('confirm_time_range')));
  await tester.pumpAndSettle();
  expect(find.text('2026-08-01 10:00 – 2026-08-01 11:00'), findsOneWidget);
});
```

- [ ] **Step 2: Verify RED**

Run: `flutter test test/widget_test.dart --plain-name 'Verbose Mode has no is segment and accepts one value' && flutter test test/widget_test.dart --plain-name 'Time range stores an inclusive start and end time'`

Expected: FAIL because these selectors do not exist.

- [ ] **Step 3: Implement scalar and range behavior**

For a single-value field, show a one-choice menu and replace `Select...`; never render `is`. For `Time range`, provide `time_range_start` and `time_range_end` inputs plus `confirm_time_range`; reject an incomplete range and render `start – end` once complete.

- [ ] **Step 4: Verify GREEN and no duplicates**

```dart
testWidgets('selecting an active field does not add a duplicate chip', (tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.tap(find.byKey(const Key('add_filter_button')));
  await tester.tap(find.byKey(const Key('add_filter_ecu_id')));
  await tester.tap(find.byKey(const Key('add_filter_button')));
  await tester.tap(find.byKey(const Key('add_filter_ecu_id')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('dlt_filter_ecu_id')), findsOneWidget);
});
```

Run: `dart format lib test && flutter analyze && flutter test`

Expected: formatter completes, analyzer reports no issues, and all widget tests pass.

## Self-Review

- Tasks 1-4 cover every agreed field, exclude Payload, distinguish chip structures, and include Time range.
- Tests exercise visible behavior rather than private state.
- The current workspace has no `.git` directory, so commit steps are intentionally omitted.
