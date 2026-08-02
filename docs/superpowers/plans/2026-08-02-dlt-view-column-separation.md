# DLT View Column Separation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an independent View selector for DLT table columns so filter changes affect only filtering and View changes affect only presentation.

**Architecture:** `LogViewerPage` will own a `Set<String>` of visible DLT column IDs beside its existing filter state. `FilterStrip` will expose a dedicated multi-select View dropdown, and `LogTable` will render columns from the visible ID set in definition order instead of deriving them from active filters.

**Tech Stack:** Flutter, Dart, Material widgets, `flutter_test`

## Global Constraints

- Create an isolated worktree with `superpowers:using-git-worktrees` before implementation.
- Execute the plan with `superpowers:subagent-driven-development`, using a fresh implementation subagent and review gates per task.
- `Time` and `Payload` are always visible and never appear in the View dropdown.
- Default visible DLT columns are `ecu_id`, `apid`, `ctid`, `log_level`, and `message_type`.
- View state is in-memory only; do not add persistence.
- Preserve stable DLT definition order regardless of toggle order.
- Do not change the structured filter or keyword-search algorithms in this feature.
- Preserve the zero-keyword search startup state.
- Use `rtk` as the prefix for shell commands.

---

## File Structure

- Modify `lib/features/log_viewer/widgets/filter_strip.dart`: add the View button, dropdown, selected-state rendering, and visibility callback API.
- Modify `lib/features/log_viewer/widgets/log_table.dart`: accept visible column IDs and build metadata columns independently of filters.
- Modify `lib/features/log_viewer/log_viewer_page.dart`: own the default View state and wire it to the strip and table.
- Modify `test/widget_test.dart`: replace filter/column coupling assertions and add View interaction, independence, missing-value, and search-regression coverage.

### Task 1: Add the View multi-select control

**Files:**
- Modify: `lib/features/log_viewer/widgets/filter_strip.dart`
- Modify: `lib/features/log_viewer/log_viewer_page.dart`
- Test: `test/widget_test.dart`

**Interfaces:**
- Consumes: `dltFilterDefinitions` and `DltFilterDefinition` from `dlt_filter.dart`.
- Produces: `FilterStrip.visibleColumnIds` as `Set<String>` and `FilterStrip.onToggleVisibleColumn` as `ValueChanged<String>`.

- [ ] **Step 1: Add a focused widget-test helper and failing View selector test**

Add this helper near `openFilterMenu` in `test/widget_test.dart`:

```dart
Future<void> openViewMenu(WidgetTester tester) async {
  final button = find.byKey(const Key('view_columns_button'));
  final filterScroll = find
      .descendant(
        of: find.byKey(const Key('filter_strip')),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.dragUntilVisible(button, filterScroll, const Offset(-200, 0));
  await tester.tap(button);
  await tester.pumpAndSettle();
}
```

Add an isolated widget test that owns a mutable set and rebuilds `FilterStrip`:

```dart
testWidgets('View dropdown toggles DLT column selections', (tester) async {
  final visibleColumnIds = <String>{'ecu_id'};

  await tester.pumpWidget(
    MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          body: FilterStrip(
            filters: const [],
            visibleColumnIds: visibleColumnIds,
            onToggleVisibleColumn: (fieldId) => setState(() {
              if (!visibleColumnIds.add(fieldId)) {
                visibleColumnIds.remove(fieldId);
              }
            }),
            onSelectField: (_) {},
            onUpdateFilter: (_) {},
            onRemoveFilter: (_) {},
            onClearFilters: () {},
          ),
        ),
      ),
    ),
  );

  await openViewMenu(tester);
  expect(find.byKey(const Key('view_columns_dropdown')), findsOneWidget);
  expect(find.byKey(const Key('view_column_selected_ecu_id')), findsOneWidget);
  expect(find.text('Time'), findsNothing);
  expect(find.text('Payload'), findsNothing);

  await tester.tap(find.byKey(const Key('view_column_option_trace_type')));
  await tester.pumpAndSettle();
  expect(visibleColumnIds, contains('trace_type'));
  expect(
    find.byKey(const Key('view_column_selected_trace_type')),
    findsOneWidget,
  );
});
```

- [ ] **Step 2: Run the focused test and confirm the missing API failure**

Run:

```bash
rtk flutter test test/widget_test.dart --plain-name "View dropdown toggles DLT column selections"
```

Expected: FAIL because `FilterStrip` does not yet accept `visibleColumnIds` or `onToggleVisibleColumn` and the View control keys do not exist.

- [ ] **Step 3: Add the View API and dropdown to `FilterStrip`**

Extend the constructor and fields:

```dart
const FilterStrip({
  super.key,
  required this.filters,
  required this.visibleColumnIds,
  required this.onToggleVisibleColumn,
  required this.onSelectField,
  required this.onUpdateFilter,
  required this.onRemoveFilter,
  required this.onClearFilters,
});

final List<DltFilter> filters;
final Set<String> visibleColumnIds;
final ValueChanged<String> onToggleVisibleColumn;
```

Place a compact outlined `View` button immediately after `Add filter`. Anchor a dropdown with `_showDropdown`, give it `Key('view_columns_dropdown')`, and wrap its option list in `StatefulBuilder` so check marks refresh without closing the overlay. Render one option per `dltFilterDefinitions` item:

```dart
InkWell(
  key: Key('view_column_option_${definition.id}'),
  onTap: () => setDropdownState(
    () => onToggleVisibleColumn(definition.id),
  ),
  child: SizedBox(
    height: 40,
    child: Row(
      children: [
        SizedBox(
          width: 32,
          child: visibleColumnIds.contains(definition.id)
              ? Icon(
                  Icons.check,
                  key: Key('view_column_selected_${definition.id}'),
                )
              : null,
        ),
        Text(definition.label),
      ],
    ),
  ),
)
```

Here `setDropdownState` comes from the dropdown's `StatefulBuilder`. Keep the overlay open after each toggle so multiple columns can be changed in one interaction. Do not add `Time` or `Payload`, because neither is part of `dltFilterDefinitions` as a fixed table column.

- [ ] **Step 4: Wire temporary View state into every `FilterStrip` call site**

In `_LogViewerPageState`, add the default state:

```dart
final _visibleColumnIds = <String>{
  'ecu_id',
  'apid',
  'ctid',
  'log_level',
  'message_type',
};

void _toggleVisibleColumn(String fieldId) => setState(() {
  if (!_visibleColumnIds.add(fieldId)) {
    _visibleColumnIds.remove(fieldId);
  }
});
```

Pass both new arguments to the production `FilterStrip`. Update the existing direct `FilterStrip` construction in `test/widget_test.dart` with `visibleColumnIds: const {}` and `onToggleVisibleColumn: (_) {}` so the suite compiles.

- [ ] **Step 5: Run FilterStrip coverage and static analysis**

Run:

```bash
rtk flutter test test/widget_test.dart --plain-name "View dropdown toggles DLT column selections"
rtk flutter test test/widget_test.dart --plain-name "an upward short dropdown remains adjacent to its anchor"
rtk flutter analyze
```

Expected: both focused tests PASS and analysis reports no new issues.

- [ ] **Step 6: Commit the View control**

```bash
rtk git add lib/features/log_viewer/widgets/filter_strip.dart lib/features/log_viewer/log_viewer_page.dart test/widget_test.dart
rtk git commit -m "feat: add DLT column View selector"
```

### Task 2: Decouple table columns from filters

**Files:**
- Modify: `lib/features/log_viewer/widgets/log_table.dart`
- Modify: `lib/features/log_viewer/log_viewer_page.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: `_LogViewerPageState._visibleColumnIds` and stable ordering from `dltFilterDefinitions`.
- Produces: `LogTable.visibleColumnIds` as `Set<String>`; removes the presentation dependency on `LogTable.filters`.

- [ ] **Step 1: Replace old coupling tests with failing View behavior tests**

Rename the initial header test to `shows fixed and default View columns` and keep its current expected header list.

Replace `adding and removing a filter shows and hides its column` with two tests:

```dart
testWidgets('View toggles a table column without adding a filter', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1600, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const MyApp());

  await openViewMenu(tester);
  await tester.tap(find.byKey(const Key('view_column_option_trace_type')));
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('dlt_column_header_Trace Type')), findsOneWidget);
  expect(find.byKey(const Key('dlt_filter_trace_type')), findsNothing);

  await tester.tap(find.byKey(const Key('view_column_option_trace_type')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('dlt_column_header_Trace Type')), findsNothing);
});

testWidgets('filter changes do not change View columns', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1600, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const MyApp());

  await openFilterMenu(tester);
  await tester.tap(find.byKey(const Key('add_filter_trace_type')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('dlt_filter_trace_type')), findsOneWidget);
  expect(find.byKey(const Key('dlt_column_header_Trace Type')), findsNothing);

  await tester.tap(find.text('Clear all'));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('dlt_column_header_ECU ID')), findsOneWidget);
  expect(find.byKey(const Key('dlt_column_header_Time')), findsOneWidget);
  expect(find.byKey(const Key('dlt_column_header_Payload')), findsOneWidget);
});
```

- [ ] **Step 2: Add failing stable-order, missing-value, and search-regression coverage**

Add these three tests:

```dart
testWidgets('View keeps DLT columns in definition order', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1800, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const MyApp());

  await openViewMenu(tester);
  await tester.tap(find.byKey(const Key('view_column_option_network_type')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('view_column_option_trace_type')));
  await tester.pumpAndSettle();

  final traceX = tester
      .getTopLeft(find.byKey(const Key('dlt_column_header_Trace Type')))
      .dx;
  final networkX = tester
      .getTopLeft(find.byKey(const Key('dlt_column_header_Network Type')))
      .dx;
  expect(traceX, lessThan(networkX));
});

testWidgets('visible column without metadata renders a dash', (tester) async {
  final controller = ScrollController();
  addTearDown(controller.dispose);
  final rowKey = GlobalKey();

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 240,
          child: LogTable(
            entries: const [
              LogEntry(
                time: '12:00:00',
                level: LogLevel.info,
                message: 'payload',
              ),
            ],
            visibleEntryIndexes: const [0],
            matchRangesByEntryIndex: const {},
            currentSearchEntryIndex: null,
            verticalController: controller,
            rowKeys: {0: rowKey},
            visibleColumnIds: const {'trace_type'},
            activeIndex: null,
            onRowTap: (_) {},
          ),
        ),
      ),
    ),
  );

  expect(find.text('—'), findsOneWidget);
});

testWidgets('View changes preserve keyword search state', (tester) async {
  await tester.binding.setSurfaceSize(const Size(1600, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const MyApp());
  await tester.enterText(find.byKey(const Key('keyword_input')), 'timeout');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();

  expect(find.text('1/2'), findsOneWidget);
  expect(
    find.byKey(const Key('payload_search_highlights_10_48_33')),
    findsOneWidget,
  );

  await openViewMenu(tester);
  await tester.tap(find.byKey(const Key('view_column_option_trace_type')));
  await tester.pumpAndSettle();

  expect(find.text('1/2'), findsOneWidget);
  expect(
    find.byKey(const Key('payload_search_highlights_10_48_33')),
    findsOneWidget,
  );
});
```

- [ ] **Step 3: Run the new tests and confirm old table coupling fails**

Run each new test by exact name:

```bash
rtk flutter test test/widget_test.dart --plain-name "View toggles a table column without adding a filter"
rtk flutter test test/widget_test.dart --plain-name "filter changes do not change View columns"
rtk flutter test test/widget_test.dart --plain-name "View keeps DLT columns in definition order"
rtk flutter test test/widget_test.dart --plain-name "visible column without metadata renders a dash"
rtk flutter test test/widget_test.dart --plain-name "View changes preserve keyword search state"
```

Expected: at least the View/table assertions FAIL because `LogTable` still derives metadata columns from `filters`.

- [ ] **Step 4: Replace `LogTable.filters` with `visibleColumnIds`**

Change the public API:

```dart
const LogTable({
  super.key,
  required this.entries,
  required this.visibleEntryIndexes,
  required this.matchRangesByEntryIndex,
  required this.currentSearchEntryIndex,
  required this.verticalController,
  required this.rowKeys,
  required this.visibleColumnIds,
  required this.activeIndex,
  required this.onRowTap,
});

final Set<String> visibleColumnIds;
```

Remove `final List<DltFilter> filters`. Build columns from definitions in their declared order:

```dart
final columns = [
  const _LogColumn(label: 'Time', width: 72),
  for (final definition in dltFilterDefinitions)
    if (visibleColumnIds.contains(definition.id))
      _LogColumn(
        label: definition.label,
        fieldId: definition.id,
        width: definition.id == 'ctid' ? 128 : 96,
      ),
  const _LogColumn(label: 'Payload', width: 480, isPayload: true),
];
```

The existing row expression `entry.dltValues[column.fieldId] ?? '—'` remains the missing-value behavior.

- [ ] **Step 5: Wire View state into `LogTable` and preserve filter behavior**

In `LogViewerPage`, replace:

```dart
filters: _filters,
```

on `LogTable` with:

```dart
visibleColumnIds: _visibleColumnIds,
```

Do not alter the `FilterStrip.filters` argument, filter callbacks, search engine calls, `visibleEntryIndexes`, `_matches`, `_activeMatchIndex`, or `_displayMode`.

- [ ] **Step 6: Run all feature tests and analysis**

Run:

```bash
rtk flutter test test/widget_test.dart
rtk flutter test test/log_viewer_entries_lifecycle_test.dart
rtk flutter analyze
```

Expected: feature and lifecycle tests PASS; analysis reports no new issues. If an unrelated pre-existing failure appears, record its exact test name and output, verify that the focused View tests pass, and do not modify unrelated behavior.

- [ ] **Step 7: Commit the decoupled table behavior**

```bash
rtk git add lib/features/log_viewer/widgets/log_table.dart lib/features/log_viewer/log_viewer_page.dart test/widget_test.dart
rtk git commit -m "feat: decouple DLT View columns from filters"
```

### Task 3: Final regression verification

**Files:**
- Verify: `lib/features/log_viewer/widgets/filter_strip.dart`
- Verify: `lib/features/log_viewer/widgets/log_table.dart`
- Verify: `lib/features/log_viewer/log_viewer_page.dart`
- Verify: `test/widget_test.dart`

**Interfaces:**
- Consumes: completed View selector, page-owned visibility state, and table visibility API.
- Produces: a reviewed feature branch ready to merge.

- [ ] **Step 1: Run formatting checks**

```bash
rtk dart format --output=none --set-exit-if-changed lib/features/log_viewer/widgets/filter_strip.dart lib/features/log_viewer/widgets/log_table.dart lib/features/log_viewer/log_viewer_page.dart test/widget_test.dart
```

Expected: exit code 0. If formatting changes are required, run `rtk dart format` on exactly these files and commit the mechanical update.

- [ ] **Step 2: Run the full repository verification**

```bash
rtk flutter analyze
rtk flutter test
```

Expected: analysis and tests PASS. Per the agreed exception, unrelated pre-existing failures may be documented, but every new or modified View test must pass.

- [ ] **Step 3: Inspect the final diff for scope and state separation**

```bash
rtk git diff main...HEAD --check
rtk git diff main...HEAD --stat
rtk git status --short
```

Expected: no whitespace errors, only the planned files plus the approved design/plan documents are changed, and the worktree is clean.

- [ ] **Step 4: Request two-stage review before merge**

Use the subagent-driven workflow to request specification-compliance review first and code-quality review second. Resolve only findings tied to this feature, rerun the focused tests after each correction, and then merge the worktree branch into `main` when both review gates approve.
