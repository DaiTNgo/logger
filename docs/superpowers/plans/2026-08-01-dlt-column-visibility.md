# DLT Column Visibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an aligned DLT table header and show metadata columns only while their filter chip is active.

**Architecture:** `LogEntry` owns DLT metadata by filter field id. A new `LogTable` widget derives its columns from the active filter list, renders the header and rows inside one horizontal scroll view, and delegates row selection to `LogViewerPage`.

**Tech Stack:** Flutter, Dart, Material 3, google_fonts, flutter_test.

## Global Constraints

- `Time` and `Payload` always remain visible.
- A DLT filter chip makes its matching metadata column visible; removing it hides that column.
- Support every existing non-payload filter id in `dltFilterDefinitions`.
- Preserve row selection and payload highlighting.
- Keep the header and all rows horizontally aligned on narrow screens.

---

## File Structure

- Modify: `lib/models/log_entry.dart` — add `dltValues` metadata keyed by DLT filter id.
- Modify: `lib/data/sample_logs.dart` — supply representative DLT values for each row and each supported field.
- Create: `lib/features/log_viewer/widgets/log_table.dart` — derive visible columns and render a shared-scrolling header and rows.
- Modify: `lib/features/log_viewer/log_viewer_page.dart` — replace the standalone list with `LogTable` and pass active filters.
- Modify: `test/widget_test.dart` — verify visible column transitions and fixed columns.

### Task 1: Extend log data with DLT metadata

**Files:** Modify `lib/models/log_entry.dart`, `lib/data/sample_logs.dart`, `test/widget_test.dart`.

**Consumes:** Existing DLT ids from `dlt_filter.dart`.

**Produces:** `LogEntry.dltValues` as `Map<String, String>` and sample rows that can populate every metadata column.

- [ ] **Step 1: Write the failing data test**

```dart
test('sample logs provide every supported DLT field', () {
  const fieldIds = [
    'ecu_id', 'apid', 'ctid', 'message_type', 'log_level', 'trace_type',
    'network_type', 'header_type', 'verbose_mode', 'message_counter',
    'length', 'number_of_arguments', 'session_id', 'time_range',
  ];
  for (final fieldId in fieldIds) {
    expect(sampleLogs.first.dltValues[fieldId], isNotEmpty);
  }
});
```

- [ ] **Step 2: Verify RED**

Run: `flutter test test/widget_test.dart --plain-name 'sample logs provide every supported DLT field'`

Expected: FAIL because `LogEntry` does not expose `dltValues`.

- [ ] **Step 3: Add the model property and representative values**

```dart
class LogEntry {
  const LogEntry({
    required this.time,
    required this.level,
    required this.message,
    this.dltValues = const {},
    this.highlightedWord,
  });

  final Map<String, String> dltValues;
}
```

Add all fourteen field ids to each `LogEntry` in `sample_logs.dart`, using values compatible with the existing filter definitions. Use the row's existing `LogLevel` to set `log_level` values such as `Info`, `Warning`, and `Error`.

- [ ] **Step 4: Verify GREEN**

Run: `flutter test test/widget_test.dart --plain-name 'sample logs provide every supported DLT field'`

Expected: PASS.

### Task 2: Render the dynamically visible DLT table

**Files:** Create `lib/features/log_viewer/widgets/log_table.dart`; modify `lib/features/log_viewer/log_viewer_page.dart` and `test/widget_test.dart`.

**Consumes:** `List<LogEntry> entries`, `List<DltFilter> filters`, and existing `LogRow` selection/highlight behavior.

**Produces:** `LogTable({required entries, required filters, required activeIndex, required onRowTap})`.

- [ ] **Step 1: Write the failing initial-column widget test**

```dart
testWidgets('shows headers for active DLT filters plus fixed columns', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1600, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const MyApp());

  for (final label in const [
    'Time', 'ECU ID', 'APID', 'CTID', 'Message Type', 'Log Level', 'Payload',
  ]) {
    expect(find.byKey(Key('dlt_column_header_$label')), findsOneWidget);
  }
  expect(find.byKey(const Key('dlt_column_header_Trace Type')), findsNothing);
});
```

- [ ] **Step 2: Verify RED**

Run: `flutter test test/widget_test.dart --plain-name 'shows headers for active DLT filters plus fixed columns'`

Expected: FAIL because no table header exists.

- [ ] **Step 3: Implement `LogTable`**

Define column descriptors with stable widths: 72 for `Time`, 96 for normal metadata, 128 for `CTID`, and an expanded 480 minimum-width `Payload`. Build the column list as `Time`, the active filters in filter-strip order using `definitionFor`, then `Payload`. Wrap the header and rows in a single horizontal `SingleChildScrollView` containing a minimum-width table. Give every header `Key('dlt_column_header_<label>')`.

Render row metadata from `entry.dltValues[fieldId] ?? '—'`. Extract the existing row visual implementation into a payload-cell widget or extend `LogRow` so its selection color, semantics label, and timeout highlight remain unchanged.

Replace the `ListView` in `LogViewerPage` with `LogTable`, passing `_filters`, `sampleLogs`, `_activeLogIndex`, and the existing selection callback.

- [ ] **Step 4: Verify GREEN**

Run: `flutter test test/widget_test.dart --plain-name 'shows headers for active DLT filters plus fixed columns'`

Expected: PASS.

### Task 3: Verify filter-controlled column changes

**Files:** Modify `test/widget_test.dart`.

**Consumes:** The existing filter-strip add/remove callbacks and `LogTable` derived-column behavior.

- [ ] **Step 1: Write the failing visibility-transition tests**

```dart
testWidgets('adding and removing a filter shows and hides its column', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1600, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const MyApp());

  await openFilterMenu(tester);
  await tester.tap(find.byKey(const Key('add_filter_trace_type')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('dlt_column_header_Trace Type')), findsOneWidget);

  await tester.tap(find.byKey(const Key('remove_filter_trace_type')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('dlt_column_header_Trace Type')), findsNothing);
});

testWidgets('clearing filters retains Time and Payload columns', (tester) async {
  await tester.pumpWidget(const MyApp());
  await tester.tap(find.text('Clear all'));
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('dlt_column_header_Time')), findsOneWidget);
  expect(find.byKey(const Key('dlt_column_header_Payload')), findsOneWidget);
  expect(find.byKey(const Key('dlt_column_header_ECU ID')), findsNothing);
});
```

- [ ] **Step 2: Verify RED**

Run: `flutter test test/widget_test.dart --plain-name 'adding and removing a filter shows and hides its column' && flutter test test/widget_test.dart --plain-name 'clearing filters retains Time and Payload columns'`

Expected: FAIL until Task 2's column derivation reacts to widget rebuilds.

- [ ] **Step 3: Make column derivation rebuild-safe**

Do not cache the active column list in state. Build it from the `filters` constructor argument each time `LogTable.build` runs so callbacks from `FilterStrip` immediately add or remove the matching column. Keep `Time` and `Payload` outside that derived list.

- [ ] **Step 4: Verify GREEN and run the full suite**

Run: `dart format lib test && flutter analyze && flutter test`

Expected: formatter completes without output changes, analyzer reports no diagnostics, and all tests pass.

## Self-Review

- The plan covers dynamic visibility for all fourteen existing DLT fields and keeps the two agreed fixed columns.
- Tests cover initial state, adding, removing, clearing, model data, selection preservation, and narrow-screen horizontal alignment through the shared scroller.
- Names and constructor fields are consistent between tasks; no new dependency is needed.
