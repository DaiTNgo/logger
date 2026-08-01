# Time Range Nested Popovers Design

## Interaction

The Time range filter opens one primary panel. It contains Start and End date,
hour, and minute controls. Clicking a calendar icon opens a calendar popover
above the primary panel; clicking an hour or minute control opens a compact
option popover beside that control. No action opens a modal or dialog.

## State

Start and End are draft timestamps while the primary panel is open. A date,
hour, or minute selection immediately updates its control. When both timestamps
are valid and Start is not after End, the filter is updated automatically. A
click outside closes all popovers while retaining the latest valid range.

## Positioning

Every popover uses viewport-aware placement: it anchors to its invoking
control, shifts horizontally within a 16 px safe margin, opens above when
below lacks room, and constrains its height with internal scrolling.

## Styling

Use `AppColors.surface`, `surfaceContainer`, `border`, `text`, and
`secondaryText`; retain the current rounded dropdown shape and compact option
rows.
