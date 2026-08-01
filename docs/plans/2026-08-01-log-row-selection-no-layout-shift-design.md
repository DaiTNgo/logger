# Log Row Selection Without Layout Shift

## Goal

Keep the selected log row's left blue rail while ensuring a row's content
does not move when selection changes.

## Design

Every `LogRow` reserves a 4 px left border. In its inactive state, that border
is transparent; in its active state, the same border changes to
`AppColors.primary`. The existing active background and active bottom-border
color are retained.

Because the border width is identical before and after a tap, the available
content width and the row's outer geometry remain constant. Only paint colors
change, so selecting a row cannot cause layout shift.

## Verification

Add a widget test that records the tapped row's timestamp position before and
after it becomes active, then asserts it is unchanged. This detects the
user-visible shift inside a row even when the row itself is constrained to the
same outer width. Keep the existing test that verifies the active rail is blue
and 4 px wide.
