# Time Range Nested Popovers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep every Time range interaction inside viewport-aware popovers without modal dialogs.

**Architecture:** Extract the Time range panel into a stateful private widget. It owns draft timestamps and invokes a reusable nested overlay helper for calendar, hour, and minute choices. The parent filter is updated only on a complete valid range.

**Tech Stack:** Flutter, Dart, Material 3, flutter_test.

## Global Constraints

- No `showDialog`, `showDatePicker`, or `showTimePicker` for Time range.
- Calendar opens only from the Start/End calendar icon.
- Hour and minute open their own compact popovers.
- Use 24-hour `00–23` and minute `00–59` options.
- Automatically save only valid `Start <= End` ranges.
- All popovers remain inside viewport with a 16 px safe margin.

---

### Task 1: Build stateful Time range panel and calendar popovers

**Files:** Modify `lib/features/log_viewer/widgets/filter_strip.dart`; modify `test/widget_test.dart`.

- [ ] Write a failing test that tapping `time_range_start_calendar` renders `inline_start_calendar` and no `AlertDialog`.
- [ ] Run: `flutter test test/widget_test.dart --plain-name 'start calendar opens in a popover'`; expect FAIL.
- [ ] Implement `_TimeRangePanel` with draft `DateTime?` Start/End values and a nested overlay calendar anchored to each icon.
- [ ] Re-run focused test; expect PASS.

### Task 2: Add hour/minute option popovers and auto-save

**Files:** Modify `lib/features/log_viewer/widgets/filter_strip.dart`; modify `test/widget_test.dart`.

- [ ] Write failing tests that `time_range_start_hour` opens 24 options and `time_range_end_minute` opens 60 options.
- [ ] Run each focused test; expect FAIL.
- [ ] Implement anchored option popovers using the shared viewport-aware overlay helper. Compose each selected date/hour/minute into a timestamp; call `onUpdate` when both timestamps exist and `Start <= End`.
- [ ] Run: `dart format lib test && flutter analyze && flutter test`; expect all checks pass.

## Self-Review

- Calendar, hour, and minute each open only from their own control.
- No modal remains in the Time range path.
- Valid ranges auto-save; invalid ranges do not update the filter.
