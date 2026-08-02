# DLT Log Search Engine Design

**Date:** 2026-08-01

## Goal

Implement a testable DLT log search engine that evaluates keyword rules against
the log payload/message, highlights every matched keyword, navigates between
matching rows, and optionally hides non-matching rows.

## Scope

- Search only the DLT log `payload/message`.
- Treat keywords as literal substrings, not regular expressions.
- Configure AND/OR and case sensitivity independently for each keyword.
- Count and navigate matching log rows, not individual keyword occurrences.
- Support two display modes: `All logs` and `Matches only`.
- Keep `All logs` as the default display mode.

Search does not evaluate time, level, ECU, APID, CTID, or other structured DLT
fields. It consumes an already-filtered base log input. The future pipeline is
DLT source → structured filters → base log input → keyword search → `All logs` /
`Matches only`. Until a structured-filter engine exists, this branch uses
`sampleLogs` as its temporary base input.

## Keyword Semantics

AND and OR are keyword modes rather than binary expression operators. They have
no precedence and do not form an expression tree.

- When at least one AND keyword exists, a log row matches only when its payload
  contains every AND keyword. OR keywords are optional and are highlighted when
  present, but they do not decide whether the row matches.
- When no AND keyword exists, a log row matches when its payload contains at
  least one OR keyword.
- When there are no keywords, search is inactive, all logs remain visible, and
  the match counter displays `0/0`.
- Case sensitivity is evaluated independently for every keyword.

For example, with `timeout` as AND and `database` as OR, a payload containing
`timeout` matches whether or not it contains `database`. If both keywords are
OR, a payload must contain at least one of them.

## Architecture

### SearchKeyword

Replace the parallel keyword collections in `LogViewerPage` with one model per
keyword. Each `SearchKeyword` contains:

- `text`
- `mode` (`and` or `or`)
- `caseSensitive`

This keeps the text and options synchronized when a keyword is added, changed,
or removed.

### LogSearchEngine

Create a pure Dart search engine with no Flutter dependency. It accepts logs and
keywords and returns ordered row-level matches. Each match identifies its source
log and contains normalized character ranges for highlighting.

The engine:

1. Evaluates each keyword against the payload using that keyword's case mode.
2. Applies the AND/OR row-matching rules.
3. Finds every occurrence of every matching keyword in an accepted row.
4. Merges overlapping or adjacent ranges so text is never rendered twice.
5. Preserves source-log order in its result list.

### LogViewerPage

`LogViewerPage` owns UI state:

- Keywords and their options.
- Ordered search results.
- The active result index.
- The display mode (`All logs` or `Matches only`).

Adding or removing a keyword, toggling AND/OR, or toggling match-case recomputes
the results and selects the first match. Search evaluates the base log list
supplied by the upstream structured-filter stage; it does not implement that
stage. In `All logs`, the full base list is rendered. In `Matches only`, only
matched rows are rendered.

## UI and Navigation

Remove the static `highlightedWord` field from sample log data. `LogRow` instead
receives dynamic match ranges and renders the payload as styled text spans.

- Every occurrence of every matching keyword uses a light-blue highlight.
- The active matching row uses a stronger blue row treatment and scrolls into
  view when previous/next navigation changes the active result.
- Multiple occurrences in one payload are all highlighted but count as one
  result row.
- The counter displays the active row position, for example `2/7`.
- With no matches, the counter displays `0/0` and both navigation controls are
  disabled.
- Previous is disabled on the first result and next is disabled on the last;
  navigation does not wrap.
- A compact `All logs / Matches only` control sits beside the counter.
- `Matches only` shows an empty state when no row matches.

Row selection and the active search result remain distinct concepts so search
navigation does not silently overwrite a user's manually selected row.

## Input and State Handling

- Trim leading and trailing whitespace before adding a keyword.
- Ignore empty keywords and exact duplicates.
- Treat differently cased strings as distinct keyword text.
- Treat all keyword text literally; regex metacharacters have no special meaning.
- Reset the active result to the first row whenever the query changes.
- If the active row disappears after the supplied base list changes or a data
  refresh, select the nearest valid result, or no result when the result set is
  empty.
- Clearing all keywords removes dynamic highlights, restores `All logs`, and
  displays the full base log list.

## Testing

Pure Dart unit tests cover:

- No keywords.
- AND-only queries.
- OR-only queries.
- Mixed AND/OR queries.
- Per-keyword case sensitivity.
- Repeated occurrences within one payload.
- Overlapping match ranges.
- Literal handling of regex-like characters.
- Stable source-log ordering.

Flutter widget tests cover:

- Dynamic highlights and removal of static highlights.
- Row-based match counter values.
- Previous/next enabled states and active-row movement.
- Scrolling the active result into view.
- Switching between `All logs` and `Matches only`.
- `0/0` and the no-results empty state.
- Recalculation after adding, removing, or changing a keyword.
- Keeping manual row selection separate from search navigation.

## Out of Scope

- Boolean expression parsing, parentheses, precedence, and NOT.
- Regex, fuzzy matching, stemming, or tokenization.
- Searching structured DLT columns.
- Structured DLT filter evaluation. A future engine owns that stage and supplies
  the base log input consumed by keyword search.
- Background isolates or indexing for very large data sets.
