import 'dart:convert';
import 'dart:typed_data';

import '../index/chunked_record_index.dart';
import '../models/schema_mismatch.dart';

abstract interface class LogParser {
  Stream<ParsedRecordBatch> parse(
    Stream<Uint8List> bytes, {
    required int generation,
  });
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
  final Map<String, String> metadata;
  final String message;
  final List<String> rawUnmapped;
  final bool hasSchemaMismatch;
}

final class ParsedRecordBatch {
  ParsedRecordBatch({
    required this.generation,
    required this.bytesConsumed,
    required List<ParsedRecord> records,
    this.mismatches = const SchemaMismatchSummary(),
  }) : records = List.unmodifiable(records);

  final int generation;
  final int bytesConsumed;
  final List<ParsedRecord> records;
  final SchemaMismatchSummary mismatches;
}

abstract base class TextLogParserBase implements LogParser {
  TextLogParserBase({required int batchSize})
    : batchSize = _validateBatchSize(batchSize);

  final int batchSize;

  ParsedLineResult parseLine(String line, RecordLocator locator);

  @override
  Stream<ParsedRecordBatch> parse(
    Stream<Uint8List> bytes, {
    required int generation,
  }) async* {
    final lineBytes = BytesBuilder(copy: false);
    final records = <ParsedRecord>[];
    var mismatches = const SchemaMismatchSummary();
    var bytesConsumed = 0;
    var lineOffset = 0;

    ParsedRecordBatch takeBatch(int consumed) {
      final batch = ParsedRecordBatch(
        generation: generation,
        bytesConsumed: consumed,
        records: records,
        mismatches: mismatches,
      );
      records.clear();
      mismatches = const SchemaMismatchSummary();
      return batch;
    }

    void addLine(Uint8List rawBytes, {required bool terminatedByNewline}) {
      final hasCarriageReturn =
          terminatedByNewline && rawBytes.isNotEmpty && rawBytes.last == 0x0d;
      final contentLength = rawBytes.length - (hasCarriageReturn ? 1 : 0);
      final contentBytes = contentLength == rawBytes.length
          ? rawBytes
          : Uint8List.sublistView(rawBytes, 0, contentLength);
      final line = utf8.decode(contentBytes, allowMalformed: true);
      final parsed = parseLine(
        line,
        RecordLocator(offset: lineOffset, length: contentLength),
      );
      records.add(parsed.record);
      mismatches += parsed.mismatches;
    }

    await for (final chunk in bytes) {
      for (final byte in chunk) {
        bytesConsumed++;
        if (byte == 0x0a) {
          addLine(lineBytes.takeBytes(), terminatedByNewline: true);
          lineOffset = bytesConsumed;
          if (records.length == batchSize) {
            yield takeBatch(bytesConsumed);
          }
        } else {
          lineBytes.addByte(byte);
        }
      }
    }

    if (lineBytes.length > 0) {
      addLine(lineBytes.takeBytes(), terminatedByNewline: false);
    }
    if (records.isNotEmpty) {
      yield takeBatch(bytesConsumed);
    }
  }
}

final class ParsedLineResult {
  const ParsedLineResult({
    required this.record,
    this.mismatches = const SchemaMismatchSummary(),
  });

  final ParsedRecord record;
  final SchemaMismatchSummary mismatches;
}

int _validateBatchSize(int batchSize) {
  if (batchSize <= 0) {
    throw ArgumentError.value(batchSize, 'batchSize', 'Must be positive');
  }
  return batchSize;
}
