# Inline Date Input Design

## Goal

Allow direct editing of the start and end dates in the DLT time-range
filter without replacing the existing calendar, hour, or minute controls.

## Interaction

- The date input displays and accepts only `YYYY-MM-DD`.
- Hour and minute remain separate controls.
- A date is parsed and applied only when its input loses focus.
- A valid date updates that boundary while retaining its current hour and
  minute (or `00:00` when none is set).
- An invalid date remains visible for correction and does not change filter
  state.
- Calendar selection continues to update the editable date input.
- The filter may use either boundary independently: a start-only value means
  "from this time onward" and an end-only value means "up to this time".
- When both boundaries exist, they must form a chronological range.

## Testing

Widget tests will cover valid start-date input on focus loss, invalid input
that leaves filter state unchanged, and preservation of independently chosen
hour/minute values.
