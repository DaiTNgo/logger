# Log Row Selection Without Layout Shift Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve the blue left selection rail in the log view without moving row content when a user selects a row.

**Architecture:** `LogRow` already owns both its selected-state decoration and its tap target. Reserve the 4 px left border in both states, using transparent paint while inactive and the primary blue while active. A widget test will compare the selected row's timestamp position before and after a tap.

**Tech Stack:** Flutter, Dart, flutter_test.

## Global Constraints

- Keep the selected log row's left rail 4 px wide and `AppColors.primary`.
- Do not change the row's content position or dimensions when its selected state changes.
- Preserve the existing active-row key and tap behavior.

---

### Task 1: Stabilize the log row selection rail

**Files:**
- Modify: `test/widget_test.dart:590-610`
- Modify: `lib/features/log_viewer/widgets/log_row.dart:42-57`

**Interfaces:**
- Consumes: `LogRow.isActive`, `LogRow.onTap`, and key `log_row_10_42_01`.
- Produces: A constant-width 4 px left border for both selected and unselected log rows.

- [ ] **Step 1: Write the failing widget test**

Add this test immediately before the existing `tapping a log row moves the active rail to that row` test:

```dart
  testWidgets('selecting a log row keeps its content position stable', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    final row = find.byKey(const Key('log_row_10_42_01'));
    final timestamp = find.descendant(of: row, matching: find.text('10:42:01'));
    final timestampBeforeTap = tester.getTopLeft(timestamp);

    await tester.tap(row);
    await tester.pump();

    expect(tester.getTopLeft(timestamp), timestampBeforeTap);
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/widget_test.dart --plain-name "selecting a log row keeps its content position stable"`

Expected: FAIL because the previously inactive row gains a 4 px left border after the tap and moves its timestamp right by 4 px.

- [ ] **Step 3: Reserve the left-rail space in both states**

In `LogRow.build`, replace the conditional `left` border with a constant 4 px border whose color changes with `isActive`:

```dart
              left: BorderSide(
                color: isActive ? AppColors.primary : Colors.transparent,
                width: 4,
              ),
```

Leave the existing `bottom` border and all padding unchanged.

- [ ] **Step 4: Run the focused test to verify it passes**

Run: `flutter test test/widget_test.dart --plain-name "selecting a log row keeps its content position stable"`

Expected: PASS.

- [ ] **Step 5: Run the existing rail regression test**

Run: `flutter test test/widget_test.dart --plain-name "tapping a log row moves the active rail to that row"`

Expected: PASS, confirming the selected rail remains blue and 4 px wide.

- [ ] **Step 6: Run the complete widget test suite**

Run: `flutter test`

Expected: PASS with no test failures.

- [ ] **Step 7: Commit the completed change**

Run:

```bash
git add lib/features/log_viewer/widgets/log_row.dart test/widget_test.dart \
  docs/plans/2026-08-01-log-row-selection-no-layout-shift-design.md \
  docs/superpowers/plans/2026-08-01-log-row-selection-no-layout-shift.md
git commit -m "fix: prevent log row selection layout shift"
```

Expected: A commit containing the stable selection rail, its regression test, and its documentation.

## Self-Review

- Spec coverage: Task 1 preserves the left rail and its blue active color, reserves equal border width in every state, and verifies the row bounds before and after selection.
- Placeholder scan: No placeholders or unspecified implementation steps remain.
- Type consistency: The plan uses existing `LogRow`, `isActive`, `onTap`, and Flutter test APIs without introducing new interfaces.
