# Time Range Clear and Nested Popovers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add independent Start/End clear actions and keep the parent time-range dropdown open when child popovers close.

**Architecture:** `_TimeRangePanel` clears boundary state through its existing update path. Nested popup dismissal consumes the outside tap at the child layer, without calling the parent overlay dismiss callback.

**Tech Stack:** Flutter, Dart, flutter_test.

## Global Constraints

- Start and End have independent `Clear` actions.
- A remaining valid boundary still produces an open-ended filter.
- Child calendar/hour/minute popovers close independently from the parent.

### Task 1: Test the clear and child-dismiss behavior

**Files:** Modify `test/widget_test.dart`.

- [ ] Write failing tests that clear Start while retaining End, clear End while retaining Start, clear both to `Select...`, and tap outside a child calendar while asserting `filter_dropdown_time_range` remains visible.
- [ ] Run `flutter test test/widget_test.dart --plain-name 'clearing Start retains End time range'` and confirm RED.

### Task 2: Implement and verify

**Files:** Modify `lib/features/log_viewer/widgets/filter_strip.dart`, `test/widget_test.dart`.

- [ ] Add keyed `Clear` actions for both `_DateTimeSection` instances; clear its controller, dirty flag, and boundary while preserving the opposite boundary.
- [ ] Change nested dropdown outside-tap handling so it dismisses only its own overlay and consumes the event before it can dismiss the parent.
- [ ] Run `dart format lib test && flutter analyze && flutter test` and commit with `feat: clear individual DLT time boundaries`.

## Self-Review

- Clear behavior preserves open-ended filtering.
- Parent dropdown remains visible after child popup dismissal.
