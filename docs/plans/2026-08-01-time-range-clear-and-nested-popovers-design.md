# Time Range Clear and Nested Popovers Design

## Behaviour

- Start and End each expose a `Clear` action.
- Clearing one boundary preserves the other boundary and its open-ended filter.
- Clearing both returns the chip to `Select...`.
- Calendar, hour, and minute popovers are child overlays: an outside click
  closes only that child and leaves the time-range dropdown open.

## Testing

Widget tests cover clearing either boundary, clearing both, and dismissing a
child date/time popup without dismissing its parent range dropdown.
