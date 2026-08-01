# DLT Column Visibility Design

## Goal

Show DLT metadata as labeled columns above the log rows, with visibility
driven by the active DLT filter chips.

## Behaviour

- `Time` and `Payload` are always visible.
- Each active DLT filter chip makes its matching metadata column visible.
- Removing a filter chip hides only its matching column.
- All available DLT fields have a column definition and sample data so that
  adding any supported filter can reveal a populated column.
- The header and log rows share one horizontal scroll area, keeping values
  aligned with their labels on narrow screens.

## Presentation

The table header uses the existing dense Carbon styling: a neutral surface,
small IBM Plex Mono labels, and a bottom border. The payload column grows to
fill remaining width; metadata columns use stable compact widths. Row
selection and search highlighting keep their present appearance.

## Data and Testing

`LogEntry` will carry a map of DLT field values in addition to time, level,
and payload. Widget tests will verify the initial visible columns, the
always-visible columns, and the add/remove filter transitions.
