# DLT View Column Separation Design

## Goal

Separate log presentation from log filtering. The new `View` control selects
which DLT metadata columns appear in the log table, while every other option in
the filter strip remains a real data filter.

## User Experience

- Add a dedicated `View` button beside `Add filter` in the filter strip.
- Opening `View` shows a multi-select dropdown containing the available DLT
  metadata columns.
- A check mark indicates every currently visible column.
- `Time` and `Payload` are always visible and are not listed in the dropdown.
- The default DLT columns remain `ECU ID`, `APID`, `CTID`, `Log Level`, and
  `Message Type`.
- Adding, editing, removing, or clearing filters does not change the selected
  View columns.
- Changing View columns does not add filters or change the displayed log set.
- View selections remain in memory while the screen is open. Persisting them
  across application launches is outside this change.

## State and Components

`LogViewerPage` owns two independent pieces of state:

- `filters` contains only structured conditions used to reduce the log input.
- `visibleColumnIds` contains the DLT metadata fields rendered by `LogTable`.

`FilterStrip` receives the visible column selection and a callback for updating
it. Its existing filter callbacks continue to operate only on filters.

`LogTable` receives `visibleColumnIds` instead of deriving columns from active
filters. It builds its columns in the stable order defined by the shared DLT
field definitions, regardless of the order in which fields were selected.

## Data Flow

The log-processing pipeline remains:

`All logs -> structured filters -> keyword search -> All/Matched mode -> table`

View selection is deliberately outside this pipeline. It changes only table
rendering. Hiding or showing a column preserves the filtered entries, keyword
matches, current match, and row selection.

If an entry does not contain a value for a visible metadata column, the table
continues to render `—` for that cell. Duplicate visible columns are not
allowed.

## Testing

Widget coverage will verify that:

- The fixed and default DLT columns appear initially.
- Toggling a View option updates both the column header and row cells.
- `Time` and `Payload` cannot be hidden.
- Filter add, edit, remove, and clear actions do not affect column visibility.
- View changes do not affect filter/search results or keyword navigation state.
- Missing metadata values render as `—`.
- Closing and reopening the View dropdown reflects the current selection.

Existing tests that encode the old coupling between filters and columns will be
updated to assert the new independent behavior. Unrelated pre-existing test
failures will be reported separately and will not expand the scope of this
feature.
