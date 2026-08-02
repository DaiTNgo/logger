# Large Log Performance and Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Progressively open, configure, filter, search, and render text or DLT log files of at least 100 MB on Windows without retaining every payload or row key in memory.

**Architecture:** A source-backed session streams bytes through a schema-driven parser isolate into a compact chunked offset index. The UI reads only visible records, filters indexed metadata before background payload search, and renders fixed-height rows by index; parser presets persist, while log contents and indexes are discarded with the session.

**Tech Stack:** Flutter/Dart 3.12, Windows desktop, `dart:io`, typed data, isolates, `file_selector` 1.1.0, `shared_preferences` 2.5.5, `flutter_test`, `integration_test`

## Global Constraints

- Target Windows desktop first.
- Support `.log`, `.txt`, and `.dlt` local files.
- Show parsed records progressively; never wait for the complete file before rendering the first batch.
- Keep every row at a fixed height with single-line ellipsized payload and no detail panel.
- Never allocate a `GlobalKey`, `LogEntry`, or ordinary Dart map for every source record.
- The original local file remains the payload store; do not copy complete imported payloads into SQLite or another database.
- Filter configured metadata before searching payload/message.
- Preserve existing per-keyword AND/OR and case-sensitive search semantics.
- Always show schema preview/mapping before import, even when detection succeeds.
- Support delimiter and named-group regex schemas, plus version-isolated AUTOSAR DLT codecs.
- View and Filter expose only fields in the confirmed schema.
- Persist parser presets only; never persist log contents, indexes, search results, or session history.
- Extra columns remain raw/unmapped and generate an aggregated Review mapping notification; missing columns render `—`.
- Closing/replacing a session cancels workers, closes handles, and deletes temporary index/cache resources.
- Preserve an appendable `LogSource` boundary for a future SSH `cat` source, but add no SSH dependency or live-log UI.
- Prefix every shell command with `rtk`.

---

## File Structure

### Core source and index

- Create `lib/features/log_viewer/sources/log_source.dart` — chunked and random-access byte source contract.
- Create `lib/features/log_viewer/sources/local_file_log_source.dart` — independent `dart:io` handles for streaming and range reads.
- Create `lib/features/log_viewer/index/chunked_record_index.dart` — typed offset/length/flag buffers and column-oriented metadata.
- Create `lib/features/log_viewer/index/indexed_log_reader.dart` — decode one indexed record for the viewport.

### Schema and parsing

- Create `lib/features/log_viewer/models/log_schema.dart` — parser type, normalized fields, mappings, and JSON serialization.
- Create `lib/features/log_viewer/models/schema_mismatch.dart` — aggregated mismatch counts and examples.
- Create `lib/features/log_viewer/services/schema_preset_repository.dart` — `SharedPreferencesAsync` preset persistence.
- Create `lib/features/log_viewer/parsers/log_parser.dart` — parser and batch contracts.
- Create `lib/features/log_viewer/parsers/delimited_log_parser.dart` — chunk-safe delimited text parsing.
- Create `lib/features/log_viewer/parsers/regex_log_parser.dart` — named-group text parsing.
- Create `lib/features/log_viewer/parsers/dlt_log_parser.dart` — storage-header detection and version dispatch.
- Create `lib/features/log_viewer/parsers/dlt_v1_codec.dart` — AUTOSAR DLT v1 record codec.
- Create `lib/features/log_viewer/parsers/dlt_v2_codec.dart` — AUTOSAR DLT v2 record codec.

### Session, filtering, and search

- Create `lib/features/log_viewer/services/log_session_controller.dart` — session lifecycle and progressive state.
- Create `lib/features/log_viewer/services/log_index_worker.dart` — isolate protocol for parsing/index batches.
- Create `lib/features/log_viewer/services/indexed_log_query_engine.dart` — filter-first background query and payload match ranges.
- Create `lib/features/log_viewer/models/log_session_state.dart` — immutable progress, schema, visible-index, warning, and error state.

### UI

- Modify `lib/features/log_viewer/widgets/log_table.dart` — fixed extent, index-driven rows, lazy record reads, no row keys.
- Modify `lib/features/log_viewer/widgets/log_row.dart` — single-line payload.
- Modify `lib/features/log_viewer/log_viewer_page.dart` — consume `LogSessionController`, cancel generations, and scroll by index.
- Modify `lib/features/log_viewer/widgets/log_viewer_header.dart` — Open file action and source/progress summary.
- Create `lib/features/log_viewer/widgets/schema_mapping_dialog.dart` — parser configuration and preview.
- Create `lib/features/log_viewer/widgets/schema_warning_toast.dart` — aggregated warning and Review mapping action.
- Modify `lib/features/log_viewer/widgets/filter_strip.dart` — schema-limited View and Filter definitions.

### Tests and benchmarks

- Create `test/chunked_record_index_test.dart`.
- Create `test/text_log_parser_test.dart`.
- Create `test/dlt_log_parser_test.dart`.
- Create `test/schema_preset_repository_test.dart`.
- Create `test/log_session_controller_test.dart`.
- Create `test/indexed_log_query_engine_test.dart`.
- Create `test/schema_mapping_dialog_test.dart`.
- Modify `test/widget_test.dart`.
- Modify `test/log_viewer_entries_lifecycle_test.dart`.
- Create `integration_test/large_log_performance_test.dart`.
- Create `tool/generate_large_log_fixture.dart`.

## Milestone 1: Virtualization and Source-Backed Index

### Task 1: Fixed-height table without per-row GlobalKeys

**Files:**
- Modify: `lib/features/log_viewer/widgets/log_row.dart`
- Modify: `lib/features/log_viewer/widgets/log_table.dart`
- Modify: `lib/features/log_viewer/log_viewer_page.dart`
- Modify: `test/widget_test.dart`
- Modify: `test/log_viewer_entries_lifecycle_test.dart`

**Interfaces:**
- Consumes: existing `visibleEntryIndexes`, search matches, selection, and `ScrollController`.
- Produces: `const logTableRowExtent = 28.0`, index-based scrolling, and a `LogTable` API with no `rowKeys` argument.

- [ ] **Step 1: Write failing fixed-row and no-GlobalKey tests**

Add tests asserting one-line layout and direct offset navigation:

```dart
testWidgets('log rows use a fixed extent and never wrap payload', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: LogViewerPage(
          entries: [
            LogEntry(
              time: '12:00:00',
              level: LogLevel.info,
              message: 'a payload long enough to wrap when width is narrow a payload long enough to wrap',
            ),
          ],
        ),
      ),
    ),
  );

  final list = tester.widget<ListView>(find.byType(ListView));
  expect(list.itemExtent, logTableRowExtent);
  final payload = tester.widget<Text>(find.textContaining('a payload long'));
  expect(payload.maxLines, 1);
  expect(payload.overflow, TextOverflow.ellipsis);
});

test('LogTable public fields contain no per-record GlobalKey map', () {
  expect(LogTable.debugUsesPerRecordGlobalKeys, isFalse);
});
```

- [ ] **Step 2: Run the tests to verify the old behavior fails**

```bash
rtk flutter test test/widget_test.dart --plain-name "log rows use a fixed extent and never wrap payload"
rtk flutter test test/widget_test.dart --plain-name "LogTable public fields contain no per-record GlobalKey map"
```

Expected: FAIL because row height is variable, payload has no one-line constraint, and `LogTable` still requires `rowKeys`.

- [ ] **Step 3: Implement fixed rows and direct index scrolling**

Define the extent beside `LogTable`:

```dart
const logTableRowExtent = 28.0;
```

Set `itemExtent: logTableRowExtent` on `ListView.builder`, remove `rowKeys`, `_rowKeys`, `_createRowKeys`, `_seekToBuiltRow`, `_isRowVisible`, and render rows without the keyed wrapper. Add this test-only static contract to `LogTable`:

```dart
static const debugUsesPerRecordGlobalKeys = false;
```

Replace context-based navigation with:

```dart
void _scrollToVisibleIndex(int visibleIndex) {
  if (!_logScrollController.hasClients) return;
  final position = _logScrollController.position;
  final target = (visibleIndex * logTableRowExtent)
      .clamp(position.minScrollExtent, position.maxScrollExtent)
      .toDouble();
  _logScrollController.animateTo(
    target,
    duration: const Duration(milliseconds: 150),
    curve: Curves.easeOut,
  );
}
```

In `LogPayloadCell`, render non-highlighted payload with:

```dart
Text(entry.message, maxLines: 1, overflow: TextOverflow.ellipsis, style: baseStyle)
```

Wrap highlighted `RichText` in `ClipRect` and set `maxLines: 1`, `overflow: TextOverflow.ellipsis`.

- [ ] **Step 4: Update navigation tests and run regressions**

Replace tests that assert variable-height context seeking with assertions that the scroll offset approaches `visibleIndex * logTableRowExtent`. Then run:

```bash
rtk flutter test test/widget_test.dart
rtk flutter test test/log_viewer_entries_lifecycle_test.dart
rtk flutter analyze
```

Expected: PASS with no `GlobalKey` map in production log-row code.

- [ ] **Step 5: Commit the virtualization change**

```bash
rtk git add lib/features/log_viewer/widgets/log_row.dart lib/features/log_viewer/widgets/log_table.dart lib/features/log_viewer/log_viewer_page.dart test/widget_test.dart test/log_viewer_entries_lifecycle_test.dart
rtk git commit -m "perf: virtualize fixed-height log rows"
```

### Task 2: Chunked source and compact record index

**Files:**
- Create: `lib/features/log_viewer/sources/log_source.dart`
- Create: `lib/features/log_viewer/sources/local_file_log_source.dart`
- Create: `lib/features/log_viewer/index/chunked_record_index.dart`
- Test: `test/chunked_record_index_test.dart`

**Interfaces:**
- Produces: `LogSource`, `LocalFileLogSource`, `RecordLocator`, `IndexedMetadata`, and `ChunkedRecordIndex`.
- Consumes: no UI types.

- [ ] **Step 1: Write failing source/index tests**

```dart
test('chunked index preserves offsets beyond 32-bit range and optional metadata', () {
  final index = ChunkedRecordIndex(chunkCapacity: 2);
  index.append(
    const RecordLocator(offset: 5_000_000_000, length: 64),
    metadata: const IndexedMetadata({'apid': 'CORE'}),
  );
  index.append(
    const RecordLocator(offset: 5_000_000_064, length: 32),
    metadata: const IndexedMetadata({}),
    flags: RecordFlags.schemaMismatch,
  );

  expect(index.length, 2);
  expect(index.locatorAt(0).offset, 5_000_000_000);
  expect(index.metadataAt(0).value('apid'), 'CORE');
  expect(index.metadataAt(1).value('apid'), isNull);
  expect(index.flagsAt(1).hasSchemaMismatch, isTrue);
});

test('local file source streams chunks and supports independent range reads', () async {
  final file = File('${Directory.systemTemp.path}/logger-source-test.bin');
  addTearDown(() async { if (await file.exists()) await file.delete(); });
  await file.writeAsBytes(List<int>.generate(32, (index) => index));
  final source = LocalFileLogSource(file.path, chunkSize: 7);
  addTearDown(source.close);

  expect(await source.open().expand((bytes) => bytes).toList(), List<int>.generate(32, (index) => index));
  expect(await source.readRange(9, 4), [9, 10, 11, 12]);
});
```

- [ ] **Step 2: Run tests and verify missing-type failures**

```bash
rtk flutter test test/chunked_record_index_test.dart
```

Expected: FAIL because the source and index types do not exist.

- [ ] **Step 3: Implement the source contract and local file source**

```dart
abstract interface class LogSource {
  String get id;
  int? get byteLength;
  Stream<Uint8List> open({int startOffset = 0});
  Future<Uint8List> readRange(int offset, int length);
  Future<void> close();
}
```

`LocalFileLogSource` opens a fresh `RandomAccessFile` for each stream/range operation, emits fixed-size `Uint8List` chunks, closes handles in `finally`, rejects negative ranges, and prevents reads after `close()`.

- [ ] **Step 4: Implement chunked typed buffers**

Store offsets in `Uint64List`, lengths in `Uint32List`, and flags in `Uint8List`, allocating a new bounded chunk only when the previous one is full. Store metadata column-wise as dictionary-coded integer IDs rather than a map per record:

```dart
final class RecordLocator {
  const RecordLocator({required this.offset, required this.length});
  final int offset;
  final int length;
}

final class IndexedMetadata {
  const IndexedMetadata(this.values);
  final Map<String, String> values; // batch input only; never retained per record
  String? value(String fieldId) => values[fieldId];
}
```

`ChunkedRecordIndex.append` converts the input metadata into per-field dictionary IDs before returning. `metadataAt` exposes a short-lived view backed by the column store.

- [ ] **Step 5: Verify and commit**

```bash
rtk flutter test test/chunked_record_index_test.dart
rtk flutter analyze
rtk git add lib/features/log_viewer/sources lib/features/log_viewer/index test/chunked_record_index_test.dart
rtk git commit -m "perf: add source-backed record index"
```

## Milestone 2: Schema and Text Import

### Task 3: Schema model and persistent presets

**Files:**
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Create: `lib/features/log_viewer/models/log_schema.dart`
- Create: `lib/features/log_viewer/services/schema_preset_repository.dart`
- Test: `test/schema_preset_repository_test.dart`

**Interfaces:**
- Produces: `LogParserType`, `LogFieldMapping`, `LogSchema`, `SchemaPreset`, and `SchemaPresetRepository`.
- Consumes: `SharedPreferencesAsync` from `shared_preferences: ^2.5.5`.

- [ ] **Step 1: Add dependencies and failing serialization tests**

Add:

```yaml
dependencies:
  file_selector: ^1.1.0
  shared_preferences: ^2.5.5

dev_dependencies:
  integration_test:
    sdk: flutter
```

Test exact round-trip behavior:

```dart
test('schema JSON preserves delimiter and normalized mappings', () {
  const schema = LogSchema(
    id: 'pipe-v1',
    name: 'Pipe logs',
    parserType: LogParserType.delimited,
    delimiter: '|',
    mappings: [
      LogFieldMapping(source: '0', fieldId: 'time'),
      LogFieldMapping(source: '1', fieldId: 'log_level'),
      LogFieldMapping(source: '2', fieldId: 'message'),
    ],
  );
  expect(LogSchema.fromJson(schema.toJson()), schema);
  expect(schema.availableFieldIds, {'time', 'log_level', 'message'});
});

test('schema rejects a mapping without message', () {
  expect(
    () => LogSchema(
      id: 'invalid',
      name: 'Invalid',
      parserType: LogParserType.delimited,
      delimiter: '|',
      mappings: const [LogFieldMapping(source: '0', fieldId: 'time')],
    ),
    throwsArgumentError,
  );
});
```

- [ ] **Step 2: Implement immutable schema types**

Use value equality, JSON primitives only, unique normalized field IDs, a required `message` mapping, non-empty delimiter for delimited schemas, and a compilable regex containing a named `message` group for regex schemas.

- [ ] **Step 3: Implement preset persistence with an injectable store**

```dart
abstract interface class StringPreferenceStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
}

final class SchemaPresetRepository {
  SchemaPresetRepository(this.store);
  final StringPreferenceStore store;
  Future<List<SchemaPreset>> load();
  Future<void> save(SchemaPreset preset);
  Future<void> delete(String schemaId);
}
```

Use one versioned JSON key, `logger.schema-presets.v1`, reject duplicate IDs by replacement, sort presets by name, and recover from malformed stored JSON by returning an empty list without deleting the raw value.

- [ ] **Step 4: Test repository behavior and commit**

Cover save/update/delete/malformed JSON using an in-memory `StringPreferenceStore`, then run:

```bash
rtk flutter test test/schema_preset_repository_test.dart
rtk flutter analyze
rtk git add pubspec.yaml pubspec.lock lib/features/log_viewer/models/log_schema.dart lib/features/log_viewer/services/schema_preset_repository.dart test/schema_preset_repository_test.dart
rtk git commit -m "feat: add configurable log schemas"
```

### Task 4: Chunk-safe delimiter and regex parsers

**Files:**
- Create: `lib/features/log_viewer/models/schema_mismatch.dart`
- Create: `lib/features/log_viewer/parsers/log_parser.dart`
- Create: `lib/features/log_viewer/parsers/delimited_log_parser.dart`
- Create: `lib/features/log_viewer/parsers/regex_log_parser.dart`
- Test: `test/text_log_parser_test.dart`

**Interfaces:**
- Consumes: `LogSchema`, source byte offsets.
- Produces: `ParsedRecord`, `ParsedRecordBatch`, `SchemaMismatchSummary`, and `LogParser.parse(Stream<Uint8List>)`.

- [ ] **Step 1: Write failing chunk-boundary and mismatch tests**

```dart
test('delimited parser joins a line split across chunks and preserves offsets', () async {
  const schema = LogSchema(
    id: 'pipe', name: 'Pipe', parserType: LogParserType.delimited,
    delimiter: '|',
    mappings: [
      LogFieldMapping(source: '0', fieldId: 'time'),
      LogFieldMapping(source: '1', fieldId: 'message'),
    ],
  );
  final parser = DelimitedLogParser(schema, batchSize: 2);
  final batches = await parser.parse(Stream.fromIterable([
    Uint8List.fromList(utf8.encode('10:00|hel')),
    Uint8List.fromList(utf8.encode('lo\n10:01|world\n')),
  ])).toList();

  final records = batches.expand((batch) => batch.records).toList();
  expect(records.map((record) => record.message), ['hello', 'world']);
  expect(records.first.locator, const RecordLocator(offset: 0, length: 11));
});

test('extra and missing columns preserve records and aggregate mismatches', () async {
  final result = await parsePipeLines(['a|b|extra', 'a']);
  expect(result.records, hasLength(2));
  expect(result.records.first.rawUnmapped, ['extra']);
  expect(result.records.last.metadata['message'], isNull);
  expect(result.mismatches.extraColumnRecords, 1);
  expect(result.mismatches.missingColumnRecords, 1);
});
```

- [ ] **Step 2: Define parser contracts**

```dart
abstract interface class LogParser {
  Stream<ParsedRecordBatch> parse(Stream<Uint8List> bytes, {required int generation});
}

final class ParsedRecord {
  const ParsedRecord({
    required this.locator,
    required this.metadata,
    required this.message,
    this.rawUnmapped = const [],
    this.hasSchemaMismatch = false,
  });
  final RecordLocator locator;
  final Map<String, String> metadata; // transient batch value
  final String message;
  final List<String> rawUnmapped;
  final bool hasSchemaMismatch;
}
```

`ParsedRecordBatch` is capped by `batchSize`, carries generation, bytes consumed, records, and mismatch deltas.

- [ ] **Step 3: Implement delimiter and regex parsing**

Use a streaming UTF-8 decoder with replacement enabled, preserve incomplete lines between chunks, handle CRLF without including `\r`, emit the final unterminated line, and compute byte offsets from consumed source bytes rather than decoded character counts.

Delimiter mapping uses numeric token positions. Regex mapping uses named groups and treats a non-matching line as one mismatch record whose raw text remains recoverable. Never drop a line due only to a schema mismatch.

- [ ] **Step 4: Verify parsers and commit**

```bash
rtk flutter test test/text_log_parser_test.dart
rtk flutter analyze
rtk git add lib/features/log_viewer/models/schema_mismatch.dart lib/features/log_viewer/parsers test/text_log_parser_test.dart
rtk git commit -m "feat: parse configurable text logs"
```

### Task 5: Preview and mapping workflow

**Files:**
- Modify: `lib/features/log_viewer/widgets/log_viewer_header.dart`
- Create: `lib/features/log_viewer/widgets/schema_mapping_dialog.dart`
- Create: `lib/features/log_viewer/widgets/schema_warning_toast.dart`
- Test: `test/schema_mapping_dialog_test.dart`

**Interfaces:**
- Consumes: `file_selector.openFile`, schema presets, text parsers, and a sample capped at 256 KiB or 200 records.
- Produces: `Future<ConfirmedLogImport?> showSchemaMappingDialog(...)`.

- [ ] **Step 1: Write failing Open file and preview tests**

```dart
testWidgets('Open file always shows mapping preview before confirmation', (tester) async {
  final picker = FakeLogFilePicker(path: fixturePath('pipe.log'));
  await tester.pumpWidget(TestApp(filePicker: picker));
  await tester.tap(find.byKey(const Key('open_log_file_button'));
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('schema_mapping_dialog')), findsOneWidget);
  expect(find.byKey(const Key('schema_preview_table')), findsOneWidget);
  expect(find.byKey(const Key('confirm_log_import')), findsOneWidget);
});

testWidgets('mapping limits Filter and View fields after confirmation', (tester) async {
  await openPipeFixtureAndMap(tester, const {'time', 'log_level', 'message'});
  await tester.tap(find.byKey(const Key('view_columns_button')));
  expect(find.byKey(const Key('view_column_option_log_level')), findsOneWidget);
  expect(find.byKey(const Key('view_column_option_apid')), findsNothing);
  await openFilterMenu(tester);
  expect(find.byKey(const Key('add_filter_log_level')), findsOneWidget);
  expect(find.byKey(const Key('add_filter_apid')), findsNothing);
});
```

- [ ] **Step 2: Introduce injectable file selection**

```dart
abstract interface class LogFilePicker {
  Future<String?> openLogFile();
}
```

The production implementation calls `openFile` with extensions `log`, `txt`, and `dlt`, returning `XFile.path`. Tests inject a fake and never open a native dialog.

- [ ] **Step 3: Implement the mapping dialog**

The dialog always appears. It offers parser type, preset, delimiter/regex input, field mappings, a preview table, inline validation, Save preset, Cancel, and Confirm. Disable Confirm until the schema is valid and preview contains at least one recoverable record.

Return:

```dart
final class ConfirmedLogImport {
  const ConfirmedLogImport({required this.path, required this.schema});
  final String path;
  final LogSchema schema;
}
```

- [ ] **Step 4: Implement aggregated schema warning UI**

Show at most one visible notification per generation with message `Some records do not match the configured N-column schema` and action `Review mapping`. Updating counts changes the existing notification state rather than stacking new overlays.

- [ ] **Step 5: Verify and commit**

```bash
rtk flutter test test/schema_mapping_dialog_test.dart
rtk flutter test test/widget_test.dart
rtk flutter analyze
rtk git add lib/features/log_viewer/widgets lib/features/log_viewer/log_viewer_page.dart test/schema_mapping_dialog_test.dart test/widget_test.dart
rtk git commit -m "feat: configure schemas before log import"
```

## Milestone 3: Progressive Sessions, DLT, and Querying

### Task 6: Progressive index worker and session lifecycle

**Files:**
- Create: `lib/features/log_viewer/models/log_session_state.dart`
- Create: `lib/features/log_viewer/services/log_index_worker.dart`
- Create: `lib/features/log_viewer/services/log_session_controller.dart`
- Create: `lib/features/log_viewer/index/indexed_log_reader.dart`
- Modify: `lib/features/log_viewer/log_viewer_page.dart`
- Modify: `lib/features/log_viewer/widgets/log_table.dart`
- Test: `test/log_session_controller_test.dart`

**Interfaces:**
- Consumes: `LogSource`, `LogParser`, `ChunkedRecordIndex`, and `ConfirmedLogImport`.
- Produces: `LogSessionController.open`, `reconfigure`, `cancel`, `dispose`, and immutable `LogSessionState`.

- [ ] **Step 1: Write failing progressive and cancellation tests**

```dart
test('session publishes its first batch before source completion', () async {
  final source = ControlledLogSource();
  final controller = LogSessionController(worker: FakeIndexWorker());
  final states = <LogSessionState>[];
  controller.addListener(() => states.add(controller.state));
  final opening = controller.open(source, pipeSchema);

  source.addText('10:00|first\n');
  await eventually(() => controller.state.indexedRecordCount == 1);
  expect(controller.state.isIndexing, isTrue);
  source.closeStream();
  await opening;
  expect(controller.state.isIndexing, isFalse);
});

test('opening a replacement source rejects stale batches and closes the old source', () async {
  final first = ControlledLogSource();
  final second = ControlledLogSource();
  final controller = LogSessionController(worker: FakeIndexWorker());
  unawaited(controller.open(first, pipeSchema));
  await controller.open(second, pipeSchema);
  first.addLateBatch('stale');
  expect(controller.state.sourceId, second.id);
  expect(controller.state.indexedRecordCount, 0);
  expect(first.wasClosed, isTrue);
});
```

- [ ] **Step 2: Define immutable session state**

Include generation, source ID/name, schema, bytes consumed/total, indexed count, indexing/query flags, mismatch summary, available field IDs, visible/matched index buffers, active match, and typed error. State snapshots may reference immutable index chunks but must not copy all offsets.

- [ ] **Step 3: Implement isolate message protocol and backpressure**

Use sealed messages:

```dart
sealed class IndexWorkerMessage { const IndexWorkerMessage(this.generation); final int generation; }
final class IndexBatchMessage extends IndexWorkerMessage { /* locators, dictionaries, progress */ }
final class IndexDoneMessage extends IndexWorkerMessage { /* final progress */ }
final class IndexErrorMessage extends IndexWorkerMessage { /* typed error */ }
```

Keep at most two unacknowledged batches. The controller acknowledges after appending to the index. Drop every message whose generation differs from current state.

- [ ] **Step 4: Integrate lazy visible-record reads**

`IndexedLogReader.read(visibleIndex)` resolves the source index, range-reads the record, and parses only that record into a short-lived `LogEntry`. Add a bounded LRU cache sized to viewport usage, default 512 records, cleared on schema/session replacement.

`LogTable` renders loading placeholders for records not yet decoded and requests only viewport/cache-extent records.

- [ ] **Step 5: Verify lifecycle and commit**

```bash
rtk flutter test test/log_session_controller_test.dart
rtk flutter test test/log_viewer_entries_lifecycle_test.dart
rtk flutter analyze
rtk git add lib/features/log_viewer/models/log_session_state.dart lib/features/log_viewer/services/log_index_worker.dart lib/features/log_viewer/services/log_session_controller.dart lib/features/log_viewer/index/indexed_log_reader.dart lib/features/log_viewer/log_viewer_page.dart lib/features/log_viewer/widgets/log_table.dart test/log_session_controller_test.dart test/log_viewer_entries_lifecycle_test.dart
rtk git commit -m "perf: stream indexed log sessions"
```

### Task 7: AUTOSAR DLT codecs and recovery

**Files:**
- Create: `lib/features/log_viewer/parsers/dlt_log_parser.dart`
- Create: `lib/features/log_viewer/parsers/dlt_v1_codec.dart`
- Create: `lib/features/log_viewer/parsers/dlt_v2_codec.dart`
- Test: `test/dlt_log_parser_test.dart`

**Interfaces:**
- Consumes: `LogParser`, `ParsedRecordBatch`, and AUTOSAR R24-11 DLT protocol definitions.
- Produces: storage-header detection, version dispatch, normalized DLT metadata, and resynchronization warnings.

- [ ] **Step 1: Add explicit byte fixtures and failing codec tests**

Build fixtures in test code with `BytesBuilder`, never opaque checked-in binaries. The v1 fixture includes the storage pattern `DLT\x01`, storage timestamp/ECU, standard header HTYP/MCNT/LEN, optional ECU/session/timestamp fields controlled by HTYP bits, extended header MSIN/NOAR/APID/CTID, and payload. The v2 fixture follows the R24-11 standard-header version and length rules.

```dart
test('DLT parser dispatches versions and normalizes optional fields', () async {
  final records = await parseDltBytes([
    buildDltV1Record(payload: 'v1', apid: 'CORE', ctid: 'NET'),
    buildDltV2Record(payload: 'v2', apid: 'DIAG', ctid: 'CTRL'),
  ]);
  expect(records.map((record) => record.message), ['v1', 'v2']);
  expect(records.first.metadata['apid'], 'CORE');
  expect(records.last.metadata['ctid'], 'CTRL');
});

test('DLT parser keeps a partial record and resynchronizes after corruption', () async {
  final valid = buildDltV1Record(payload: 'after');
  final chunks = splitAt([...buildDltV1Record(payload: 'before'), 0xff, 0x00, ...valid], 13);
  final result = await parseDltChunks(chunks);
  expect(result.records.map((record) => record.message), ['before', 'after']);
  expect(result.mismatches.corruptRecordCount, 1);
});
```

- [ ] **Step 2: Implement storage/header detection and version codecs**

Use `ByteData.sublistView` and explicit endian reads. Validate declared length before slicing. Map optional ECU ID, session ID, timestamp, message type/subtype, verbosity, argument count, APID, CTID, and payload into normalized fields. A codec returns `needMoreBytes`, `parsed(record, consumed)`, `invalid(consumedHint)`, or `unsupportedVersion` rather than throwing for corrupt source data.

- [ ] **Step 3: Implement bounded resynchronization**

After invalid input, scan for the next storage signature/header candidate within a bounded window, preserve a suffix long enough to match a signature split across chunks, and emit one mismatch delta per skipped region. Unsupported protocol versions produce a typed fatal error naming the detected version.

- [ ] **Step 4: Verify against AUTOSAR-defined fixtures and commit**

```bash
rtk flutter test test/dlt_log_parser_test.dart
rtk flutter analyze
rtk git add lib/features/log_viewer/parsers/dlt_log_parser.dart lib/features/log_viewer/parsers/dlt_v1_codec.dart lib/features/log_viewer/parsers/dlt_v2_codec.dart test/dlt_log_parser_test.dart
rtk git commit -m "feat: parse progressive DLT files"
```

### Task 8: Filter-first indexed search

**Files:**
- Create: `lib/features/log_viewer/services/indexed_log_query_engine.dart`
- Modify: `lib/features/log_viewer/services/log_session_controller.dart`
- Modify: `lib/features/log_viewer/log_viewer_page.dart`
- Test: `test/indexed_log_query_engine_test.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: immutable index chunks, `DltFilter`, `SearchKeyword`, source path/schema, and generation.
- Produces: progressive `QueryBatch` values with filtered indexes, matches/ranges, scanned count, and completion.

- [ ] **Step 1: Write failing filter-order, progressive, and cancellation tests**

```dart
test('query filters metadata before reading payload', () async {
  final source = CountingRangeSource(records: fixtureRecords);
  final engine = IndexedLogQueryEngine(source: source, index: fixtureIndex);
  final batches = await engine.query(
    filters: const [DltFilter(fieldId: 'apid', values: ['CORE'])],
    keywords: const [SearchKeyword(text: 'timeout')],
    generation: 7,
  ).toList();

  expect(batches.last.matchedSourceIndexes, expectedCoreTimeoutIndexes);
  expect(source.payloadReadIndexes, everyElement(isIn(expectedCoreIndexes)));
});

test('query emits existing results progressively and stops a cancelled generation', () async {
  final token = QueryCancellationToken(9);
  final stream = engine.query(keywords: timeoutKeywords, generation: 9, cancellation: token);
  final first = await stream.first;
  expect(first.isComplete, isFalse);
  token.cancel();
  await expectLater(stream, emitsDone);
  expect(engine.completedGenerations, isNot(contains(9)));
});
```

- [ ] **Step 2: Implement column-first filtering and payload search**

Evaluate structured filters using dictionary-coded index columns without reading payload. Then range-read only accepted records and reuse the existing substring/range-merging semantics in the worker. Process bounded chunks and emit immutable typed index chunks rather than rebuilding full integer lists.

- [ ] **Step 3: Integrate incremental new batches and progress UI**

When indexing appends a batch, query only that new source-index range using the current generation and append results. Display `N matches · scanning P%` while incomplete and the existing `current/total` navigation when complete. `All logs` uses filtered indexes; `Matches only` uses matched indexes.

- [ ] **Step 4: Verify search compatibility and commit**

```bash
rtk flutter test test/indexed_log_query_engine_test.dart
rtk flutter test test/log_search_engine_test.dart
rtk flutter test test/widget_test.dart
rtk flutter analyze
rtk git add lib/features/log_viewer/services/indexed_log_query_engine.dart lib/features/log_viewer/services/log_session_controller.dart lib/features/log_viewer/log_viewer_page.dart test/indexed_log_query_engine_test.dart test/widget_test.dart
rtk git commit -m "perf: query indexed logs in background"
```

## Milestone 4: Resource Safety and Performance Evidence

### Task 9: Session cleanup, schema review, and errors

**Files:**
- Modify: `lib/features/log_viewer/services/log_session_controller.dart`
- Modify: `lib/features/log_viewer/widgets/schema_warning_toast.dart`
- Modify: `lib/features/log_viewer/widgets/schema_mapping_dialog.dart`
- Test: `test/log_session_controller_test.dart`
- Test: `test/schema_mapping_dialog_test.dart`

**Interfaces:**
- Consumes: typed parser/source/query errors and mismatch deltas.
- Produces: deterministic cleanup and schema rebuild behavior.

- [ ] **Step 1: Add failing cleanup and Review mapping tests**

```dart
test('session replacement disposes resources and rejects late batches', () async {
  final first = ControlledLogSource(id: 'first');
  final second = ControlledLogSource(id: 'second');
  final worker = ControlledIndexWorker();
  final controller = LogSessionController(worker: worker);

  unawaited(controller.open(first, pipeSchema));
  final firstGeneration = controller.state.generation;
  await controller.open(second, pipeSchema);
  worker.emitBatch(generation: firstGeneration, records: oneRecordBatch);

  expect(first.closeCount, 1);
  expect(worker.cancelledGenerations, contains(firstGeneration));
  expect(controller.state.sourceId, 'second');
  expect(controller.state.indexedRecordCount, 0);
  expect(controller.debugDecodedCacheLength, 0);
});

testWidgets('mismatch batches update one toast and Review mapping rebuilds', (tester) async {
  final controller = FakeLogSessionController(schema: fourColumnSchema);
  await tester.pumpWidget(TestApp(controller: controller));
  for (var index = 0; index < 10; index++) {
    controller.emitMismatch(extraColumnRecords: 1);
  }
  await tester.pump();

  expect(find.byKey(const Key('schema_warning_toast')), findsOneWidget);
  expect(find.textContaining('10 records'), findsOneWidget);
  await tester.tap(find.text('Review mapping'));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('schema_mapping_dialog')), findsOneWidget);

  final previousGeneration = controller.state.generation;
  await confirmFiveColumnMapping(tester);
  expect(controller.state.generation, previousGeneration + 1);
  expect(controller.rebuildCount, 1);
});
```

- [ ] **Step 2: Implement typed error and cleanup state transitions**

Use `LogSessionErrorType.unreadableSource`, `invalidEncoding`, `invalidDlt`, `unsupportedDltVersion`, and `workerFailure`. Make cleanup idempotent. Keep the selected file path available for Review mapping after parse errors, but never retain it after session close.

- [ ] **Step 3: Verify and commit**

```bash
rtk flutter test test/log_session_controller_test.dart
rtk flutter test test/schema_mapping_dialog_test.dart
rtk flutter analyze
rtk git add lib/features/log_viewer/services/log_session_controller.dart lib/features/log_viewer/widgets/schema_warning_toast.dart lib/features/log_viewer/widgets/schema_mapping_dialog.dart test/log_session_controller_test.dart test/schema_mapping_dialog_test.dart
rtk git commit -m "fix: make large log sessions disposable"
```

### Task 10: Windows 100 MB benchmark and final verification

**Files:**
- Create: `tool/generate_large_log_fixture.dart`
- Create: `integration_test/large_log_performance_test.dart`
- Modify: `README.md`

**Interfaces:**
- Consumes: the completed local-file import pipeline.
- Produces: repeatable 100 MB fixture generation and recorded performance metrics.

- [ ] **Step 1: Add deterministic fixture generation**

The tool accepts `--output` and `--bytes`, writes deterministic pipe-delimited UTF-8 rows until file length is at least the requested byte count, and prints exact bytes and record count. It streams output through an `IOSink` and never constructs the fixture in memory.

```bash
rtk dart run tool/generate_large_log_fixture.dart --output build/fixtures/large-100mb.log --bytes 104857600
```

- [ ] **Step 2: Add a Windows profile benchmark harness**

The integration test opens the generated fixture with a fixed schema and records:

```dart
final metrics = LargeLogMetrics(
  timeToFirstBatch: firstBatchAt.difference(startedAt),
  totalIndexDuration: finishedAt.difference(startedAt),
  indexedBytes: controller.state.bytesConsumed,
  indexedRecords: controller.state.indexedRecordCount,
  searchDuration: searchFinishedAt.difference(searchStartedAt),
  peakWorkingSetBytes: workingSetSamples.reduce(math.max),
);
print(jsonEncode(metrics.toJson()));
```

Collect `workingSetSamples` from `ProcessInfo.currentRss` every 100 ms while
indexing and searching; cancel the periodic sampler in `finally`.

Assert correctness invariants only: first batch arrives before indexing completes, bytes consumed reach the fixture size, UI heartbeat continues during indexing/search, no production per-row GlobalKey exists, and built rows stay below viewport rows plus cache extent. Record approximately one-second time-to-first-batch as a target, not a hardware-independent CI assertion.

- [ ] **Step 3: Document benchmark and future source contract**

Add exact profile-mode Windows commands, the metrics JSON format, expected qualitative acceptance criteria, and a short example showing that future `SshCatSource` implements `LogSource` and writes to a session spool without adding transport behavior now.

- [ ] **Step 4: Run full verification**

```bash
rtk dart format --output=none --set-exit-if-changed lib test integration_test tool
rtk flutter analyze
rtk flutter test
rtk flutter test integration_test/large_log_performance_test.dart -d windows --profile
rtk git diff --check
```

Expected: unit/widget suites pass, analysis is clean, the Windows profile run produces metrics for the 100 MB fixture, and the UI heartbeat/virtualization correctness assertions pass. Record machine specifications and metrics in the implementation report rather than committing the generated fixture.

- [ ] **Step 5: Commit benchmark tooling and documentation**

```bash
rtk git add tool/generate_large_log_fixture.dart integration_test/large_log_performance_test.dart README.md
rtk git commit -m "test: benchmark 100 MB log sessions"
```

## Plan Self-Review Checklist

- Every approved design section maps to Tasks 1–10.
- Live SSH transport remains outside scope; only `LogSource` append semantics are preserved.
- File contents and indexes are session-only; only schema presets persist.
- Text and DLT parsing, schema mismatches, filter-before-search, cancellation, and fixed-row navigation have explicit tests.
- The 100 MB file is generated outside Git and streamed rather than retained in memory.
- Types consumed by later tasks are produced by earlier tasks with consistent names.
