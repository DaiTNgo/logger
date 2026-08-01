# DLT Custom Dropdown Selector Design

## Goal

Replace every default Material filter-value popup with a compact custom
dropdown that is visually consistent with the Add filter menu.

## Interaction

- Single-value filters open an anchored dropdown below `Select...`; tapping a
  value applies it and closes the dropdown.
- Multi-value filters open an anchored dropdown below `Select...`; each option
  has a checkbox and updates the selected filter immediately. Clicking outside
  closes the dropdown and preserves the current selection; there is no Apply
  button.
- Time range opens an anchored dropdown panel below `Select...` with Start and
  End date-and-time inputs. Each input captures year, month, day, hour, and
  minute in `YYYY-MM-DD HH:mm`; entering both values and clicking outside
  applies the range.
- The field picker remains an anchored dropdown and keeps its existing visual
  language.

## Visual Style

Each dropdown uses a white surface, 1 px `AppColors.border` outline, 16 px
outer corners, and a soft shadow. Options are 64 px high with 16 px text and
wide horizontal padding. Hovered or selected options use a light-gray rounded
12 px inner surface. It aligns its left edge to the control that opened it and
does not use `AlertDialog` or the default Material popup menu styling.

Multi-select options reserve a leading status column and render a checkmark
only when selected. Single-select options reserve the same column and render
a bullet only for the active value.

Time range provides Today, Last 7 days, Last 30 days, Last 90 days, and
Custom presets plus separate date and time controls for both Start and End.
The picker uses `AppColors.surface`, `AppColors.surfaceContainer`,
`AppColors.border`, `AppColors.text`, and `AppColors.secondaryText`.
The Time range dropdown closes before opening a date or time modal, then
reopens with the selected value so modal layers never overlap.
Time uses a 24-hour clock with separate `00–23` hour and `00–59` minute
controls; AM/PM is not shown.

## Testing

Widget tests will verify that a single-value selector appears as an anchored
custom dropdown and that dismissing a multi-value selector preserves the
checked values without requiring an Apply button.
