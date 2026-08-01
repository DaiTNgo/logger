# Task 1 Report

## Changes

- Added widget coverage for clearing Start while retaining End.
- Added widget coverage for clearing End while retaining Start.
- Added widget coverage for clearing both boundaries back to `Select...`.
- Added widget coverage that an outside tap on a child calendar dismisses only that calendar and keeps the time-range panel open.

## RED verification

Ran:

```text
flutter test test/widget_test.dart --plain-name 'clearing Start retains End time range'
```

Result: failed as expected because no widget currently has the key
`time_range_clear_start`.

## Scope

Only `test/widget_test.dart` and this report were changed. No production code was modified.
