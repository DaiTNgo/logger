# Large Log Performance and Import Design

## Goal

Support progressively opening and exploring text and DLT log files up to at
least 100 MB on Windows without loading the full payload into Dart objects or
blocking the UI. The architecture must allow a future SSH `cat` byte stream to
use the same pipeline, but live transport is outside this implementation.

## Scope

This design includes:

- Fixed-height virtualized log rows without per-record `GlobalKey` objects.
- Local import for `.log`, `.txt`, and `.dlt` files.
- A required preview and schema-mapping step before import.
- Delimiter, regular-expression, and DLT parsing.
- Progressive indexing, filtering, and payload search.
- Session-only source indexes and caches.
- Parser presets that persist independently from log contents.
- Performance instrumentation and a 100 MB Windows benchmark fixture.

This design does not include SSH connectivity, credentials, reconnect logic,
or persisted log history.

## Architecture

The processing pipeline is:

`LogSource -> schema preview/mapping -> background parser -> offset index -> filter -> keyword search -> virtualized table`

### Log Sources

`LogSource` exposes a chunked byte stream and supports cancellation and
disposal. The initial implementations are `LocalTextFileSource` and
`LocalDltFileSource`.

The interface must not assume that the source size is known or that the stream
ends. A future `SshCatSource` can therefore provide SSH stdout bytes without
changing parsers, indexing, filtering, search, or the viewer. Live transport
itself is not implemented now.

### Schema

`LogSchema` describes:

- Parser type: delimited text, regular-expression text, or DLT.
- Delimiter or regular expression when applicable.
- Mapping from token positions or named groups to normalized log fields.
- The set of fields available to View and Filter.

The payload/message field is required. Time, ECU ID, APID, CTID, log level,
message type, and other DLT metadata are optional.

Parser presets persist only schema configuration. They never retain the file,
parsed records, search data, or prior sessions.

### Source-Backed Record Index

The original file remains the payload store. Import does not copy the complete
payload into SQLite or an in-memory list.

`LogRecordIndex` stores compact record locators and filter metadata:

- Monotonic sequence number.
- Byte offset and byte length.
- Compact normalized metadata needed by configured filters.
- Schema-mismatch flags.

Offsets and compact values use typed buffers split into bounded chunks. The
application must not create a `LogEntry`, `GlobalKey`, or ordinary Dart map for
every record in the file. Payload bytes are read and decoded only for visible
rows, preview, or background search.

### Session Lifecycle

`LogSession` owns the source, schema, parser worker, index, filter/search state,
and temporary resources. Closing a file, opening another file, or exiting the
application disposes the session and deletes its index/cache. Every file open
starts a new session.

Changing the schema cancels active parser and search work, clears the session
index, and rebuilds it from the start of the source.

## File Open and Schema Mapping

Opening a file first reads a small sample. The application detects text versus
DLT and proposes a parser or saved preset, but it always opens the preview and
mapping screen before full import.

For text files, users can configure:

- Tab, space, pipe, semicolon, comma, or a custom delimiter.
- A regular expression using named capture groups.
- Mapping from tokens/groups to normalized fields.

The preview renders representative parsed rows and mapping errors. Import only
begins after confirmation.

For DLT files, the DLT parser reads record headers and reports optional fields
that are present. View and Filter list only fields declared by the confirmed
schema. A field is never automatically enabled as a visible column.

## Schema Mismatch Behaviour

If a record contains more columns than the confirmed schema:

- Parsing continues.
- The record is marked as a schema mismatch.
- Extra values remain available as raw/unmapped data.
- Existing mappings are not shifted and new filter fields are not created.
- A debounced summary toast reports the mismatch and offers `Review mapping`.

If a record contains fewer columns than the schema:

- The record remains in the session.
- Missing fields render as `—`.
- The mismatch contributes to the same aggregated warning rather than emitting
  a toast for every record.

Reviewing and confirming a changed mapping rebuilds the index for the session.

## Progressive Processing

The parser runs outside the UI isolate. It preserves partial text lines and DLT
records across byte-chunk boundaries and emits bounded record batches.

Each completed batch updates import progress and becomes available to the
viewer immediately. A bounded queue applies backpressure so parsing cannot
outpace indexing and state updates indefinitely.

Filter evaluates indexed metadata and always precedes payload search. Search
retains the existing semantics:

- Search only the payload/message.
- Every AND keyword must match.
- OR keywords are optional when an AND keyword exists; otherwise any OR match
  accepts the record.
- Case sensitivity is configured independently per keyword.

Filter and search evaluate existing indexed batches in a background worker and
then incrementally evaluate new batches. Generation tokens cancel stale import,
filter, search, and schema-rebuild results.

Visible and matched indexes use chunked typed buffers. Rendering must not
recreate a full `List<int>` on every widget build. While work is incomplete,
the UI reports both current results and scanning progress.

## Virtualized Table

Every log row has a fixed height. Payload is restricted to one line with an
ellipsis and does not open a detail panel.

The table virtualizes by visible index and scrolls directly to an item index.
It removes the per-record `Map<int, GlobalKey>` and the context-seeking/binary
jump algorithm. At most viewport and cache-extent widgets are built.

`Time` and `Payload` remain fixed columns. Optional columns follow the current
View selection, and unavailable schema fields do not appear in View or Filter.

## Error Handling

- Text defaults to UTF-8. Invalid byte sequences use a replacement character
  and increment an aggregated warning count.
- DLT parsing attempts to resynchronize at the next valid record header after
  corrupt input and aggregates skipped-record warnings.
- Lines and records spanning chunks are supported without allocating a buffer
  the size of the full file.
- Cancellation closes file handles, stops workers, and releases temporary
  resources.
- Unrecoverable errors such as an unreadable file or unrecognizable DLT stream
  show an error state with a path back to schema mapping.
- Repeated schema problems are debounced into summary notifications.

## Future Live Source Boundary

Future SSH live logging is expected to run `cat` on a device and consume its
stdout as a byte stream. At that time, `SshCatSource` will spool bytes into a
temporary session file so the same appendable offset index can address older
records. Closing the live session removes that spool and its index.

This design only preserves the interface and append semantics required by that
future source. It adds no SSH package or live-log UI now.

## Testing

Correctness tests cover:

- Delimiter and regex mapping.
- Text lines and DLT records split across chunks.
- DLT corruption and resynchronization.
- Missing and extra fields, raw preservation, mismatch aggregation, and mapping
  review.
- Schema-driven View and Filter availability.
- Filter-before-search ordering and existing keyword semantics.
- Cancellation and generation isolation across import, search, filter, schema
  rebuild, and session replacement.
- File handle and temporary-resource disposal.
- Search navigation in All logs and Matches only without per-row GlobalKeys.

Performance verification uses a generated 100 MB fixture in a Windows release
build and records:

- Time to first visible batch, targeting approximately one second on the
  reference development machine.
- Full indexing throughput in MB/s.
- Filter and search throughput and cancellation latency.
- Peak process working set.
- Number of built row widgets relative to viewport size.

Performance tests record measurements rather than enforce hardware-dependent CI
timings. The feature is not complete if it processes the whole file on the UI
isolate, retains all payloads as `LogEntry` objects, creates a GlobalKey per
record, or makes the UI unresponsive during import/filter/search.
