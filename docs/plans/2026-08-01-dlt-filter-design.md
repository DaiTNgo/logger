# DLT Filter Picker Design

## Goal

Replace the free-form Add filter dialog with a DLT field picker and
field-specific value selection that matches the supplied chip patterns.

## Interaction

1. Selecting **Add filter** opens a popover-style list of DLT fields.
2. Selecting a field adds its chip immediately and opens that field's value
   selector.
3. Multi-value fields render as `Field | is | Select... | x`. Their selector
   allows several values to be active at once.
4. Single-value and range fields render as `Field | Select... | x`.
5. A selected field cannot produce duplicate chips. Selecting it again edits
   the existing filter.
6. The `Time range` selector collects an inclusive start and end timestamp.
7. Payload is intentionally excluded because message-text filtering already
   belongs to search.

## Filter Catalog

| Category | Fields | Selection mode |
| --- | --- | --- |
| Identity | ECU ID, APID, CTID | Multiple values |
| Classification | Message Type, Log Level, Trace Type, Network Type | Multiple values |
| Header attributes | Header Type, Verbose Mode | One value |
| Numeric header values | Message Counter, Length, Number of Arguments | One value/condition |
| Session | Session ID | One value |
| Time | Time range | Start/end range |

The catalog covers the standard and extended DLT header data used for
filtering: ECU ID, Session ID, Timestamp, Message Counter, Length, APID,
CTID, Message Info, and Number of Arguments. Payload is not exposed.

## Presentation

The field menu opens below the Add filter button. Chips keep the existing
horizontal scroll strip. Value selectors open from the chip's `Select...`
area and close once their choice is confirmed. The time range selector shows
separate start and end inputs, then displays a compact summary in the chip.

## Testing

Widget tests will cover field-menu visibility, multi-value chip structure,
single-value chip structure, choosing a value, setting a time range, and
deduplicating a repeated field selection.
