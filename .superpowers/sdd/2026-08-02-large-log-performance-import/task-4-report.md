# Task 4 Report: Chunk-safe delimiter and regex parsers

## Status

Complete. Task 4 is implemented on `codex/large-log-performance-import` from
base `4525a913dba55da20fde7a8d533c0957c59e54af` without changes to UI,
session, or DLT code.

## Changed files

- `lib/features/log_viewer/models/schema_mismatch.dart`
  - Adds immutable mismatch delta counters for extra columns, missing columns,
    regex non-matches, and future DLT corruption reporting.
- `lib/features/log_viewer/parsers/log_parser.dart`
  - Defines `LogParser`, `ParsedRecord`, `ParsedRecordBatch`, and the shared
    chunk-safe text-line stream implementation.
- `lib/features/log_viewer/parsers/delimited_log_parser.dart`
  - Maps numeric token positions, preserves unmapped values, and reports
    missing/extra-column mismatch deltas without dropping records.
- `lib/features/log_viewer/parsers/regex_log_parser.dart`
  - Maps named groups and preserves non-matching or partially mapped lines as
    recoverable mismatch records.
- `test/text_log_parser_test.dart`
  - Adds seven focused parser behavior tests.

## TDD failing-test evidence

The tests were written before parser production code. The initial command was:

```text
rtk flutter test test/text_log_parser_test.dart
```

It failed at test loading because the requested feature libraries did not yet
exist:

```text
Error when reading 'lib/features/log_viewer/parsers/delimited_log_parser.dart':
No such file or directory
Error when reading 'lib/features/log_viewer/parsers/log_parser.dart':
No such file or directory
Error when reading 'lib/features/log_viewer/parsers/regex_log_parser.dart':
No such file or directory
00:00 +0 -1: Some tests failed.
```

The first implementation run also identified an independently hand-calculated
fixture error: `α|x` occupies four source bytes rather than five. The literal
expected locator was corrected to offset `0`, length `4`; the following record
begins at byte `5`. No production behavior was changed for that fixture error.

## Passing-test evidence

Focused verification:

```text
rtk flutter test test/text_log_parser_test.dart
00:00 +7: All tests passed!
```

The focused tests verify:

- chunk-boundary line joining;
- source byte offsets and consumed-byte progress;
- bounded batch sizes and generation propagation;
- extra/missing delimiter fields with raw recovery;
- CRLF stripping and final unterminated lines;
- split and malformed UTF-8 with replacement decoding;
- named regex groups, optional missing groups, and non-matching raw lines.

Full regression verification:

```text
rtk flutter test
00:06 +114: All tests passed!
```

## Analyze and formatting output

```text
rtk flutter analyze
Analyzing large-log-performance-import...
No issues found! (ran in 0.7s)
```

All five scoped implementation/test files were formatted with `dart format`,
and `git diff --cached --check` reported no whitespace errors before commit.

## Self-review

- Offsets and locator lengths are computed from raw source bytes, never decoded
  character counts.
- Line state survives arbitrary input chunks. UTF-8 decoding uses replacement
  for malformed sequences after a complete raw line has been assembled.
- `\r` is removed only when it is part of a `\r\n` terminator. Both terminator
  bytes still advance the next source offset.
- A trailing unterminated line is emitted; a trailing newline does not create a
  phantom record.
- Extra, missing, optional-group, and regex non-match cases always emit a
  record. Raw data remains available through `rawUnmapped`, the fallback
  `message`, and the source locator.
- Missing mapped values are absent from metadata, allowing readers to render
  the required `—` placeholder later.
- Ordinary maps and lists exist only in the parser's bounded active batch and
  emitted `ParsedRecordBatch`; no parser collection is retained in
  `ChunkedRecordIndex` per source record.
- Batch mismatch summaries are deltas, reset after each emitted batch, and the
  record count never exceeds `batchSize`.
- No UI, session lifecycle, index storage, source, or DLT files were modified.

## Commit

Implementation commit:

```text
607f3100f614d15dcb99d519b84e23193d6064b8
feat: parse configurable text logs
```

## Concerns

No blocking concerns. Temporary line buffering is bounded by the longest
individual text line rather than the whole source; batches are separately
bounded by `batchSize`. An undefined regex mapping source is treated as a
missing field mismatch so malformed source/schema combinations preserve the
record instead of aborting the stream.
