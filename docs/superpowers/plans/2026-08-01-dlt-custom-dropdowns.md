# DLT Custom Dropdowns Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render every DLT filter selector as an anchored custom dropdown and auto-save multi-value choices on dismissal.

**Architecture:** `FilterStrip` replaces `showMenu` and `showDialog` value selectors with one reusable overlay dropdown wrapper. `_DltFilterChip` supplies custom option rows or a time-range panel and sends each value update to `LogViewerPage` immediately.

**Tech Stack:** Flutter, Dart, Material 3, flutter_test.

## Global Constraints

- Keep the existing Add filter field picker behavior.
- Use white background, 1 px `AppColors.border`, 16 px outer corners, 16 px option text, 64 px option rows, a light-gray 12 px selected/hovered inner surface, and a soft shadow.
- Anchor each dropdown below the calling Select control.
- A single-value click applies and closes.
- Multi-value checkbox changes apply immediately; outside dismissal keeps those changes and no Apply button is shown.
- Time range has Start/End date-and-time inputs (`YYYY-MM-DD HH:mm`) and applies when both are present on outside dismissal.
- Time range exposes preset ranges plus custom date and time controls, all styled with the existing `AppColors` tokens.

---

### Task 1: Add a reusable anchored dropdown overlay

**Files:** Modify `lib/features/log_viewer/widgets/filter_strip.dart`; modify `test/widget_test.dart`.

**Produces:** A private custom overlay widget/function that accepts an anchor `BuildContext`, a child panel, and an outside-dismiss callback.

- [ ] **Step 1: Write the failing custom-dropdown test**

```dart
testWidgets('single-value filters open a custom anchored dropdown', (tester) async {
  await tester.pumpWidget(const MyApp());
  await openFilterMenu(tester);
  await tester.tap(find.byKey(const Key('add_filter_verbose_mode')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('filter_value_verbose_mode')));
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('filter_dropdown_verbose_mode')), findsOneWidget);
  expect(find.byType(AlertDialog), findsNothing);
});
```

- [ ] **Step 2: Verify RED**

Run: `flutter test test/widget_test.dart --plain-name 'single-value filters open a custom anchored dropdown'`

Expected: FAIL because the current selector is a default menu.

- [ ] **Step 3: Implement the overlay**

Create an `OverlayEntry` positioned from the trigger render box. Wrap the panel in a full-screen transparent `GestureDetector` that removes the entry on outside tap. Give the panel a white `Material`, border, square shape, and `BoxShadow`.

- [ ] **Step 4: Verify GREEN**

Run: `flutter test test/widget_test.dart --plain-name 'single-value filters open a custom anchored dropdown'`

Expected: PASS.

### Task 2: Convert selector content and auto-save multi values

**Files:** Modify `lib/features/log_viewer/widgets/filter_strip.dart`; modify `test/widget_test.dart`.

**Consumes:** The anchored overlay from Task 1 and `onUpdate(DltFilter)`.

- [ ] **Step 1: Write the failing dismissal test**

```dart
testWidgets('multi-value choices persist when its dropdown is dismissed', (tester) async {
  await tester.pumpWidget(const MyApp());
  await openFilterMenu(tester);
  await tester.tap(find.byKey(const Key('add_filter_log_level')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('filter_value_log_level')));
  await tester.tap(find.text('Error'));
  await tester.tapAt(const Offset(10, 500));
  await tester.pumpAndSettle();

  expect(find.text('Error'), findsOneWidget);
  expect(find.byKey(const Key('confirm_filter_values')), findsNothing);
});
```

- [ ] **Step 2: Verify RED**

Run: `flutter test test/widget_test.dart --plain-name 'multi-value choices persist when its dropdown is dismissed'`

Expected: FAIL because the current dialog requires Apply.

- [ ] **Step 3: Implement selector panels**

Render single-value rows, checkbox rows, and time inputs inside the overlay. Call `onUpdate` immediately from each multi checkbox. For time inputs, cache values in the panel and call `onUpdate` only when both are nonempty during outside dismissal.

- [ ] **Step 4: Verify GREEN and full regression**

Run: `dart format lib test && flutter analyze && flutter test`

Expected: formatter completes, analyzer reports no issues, and all widget tests pass.

## Self-Review

- Task 1 replaces default selector presentation with the agreed dropdown styling.
- Task 2 covers the required no-Apply multi-value behavior and range handling.
- The workspace has no `.git` directory, so no commit step is possible.
