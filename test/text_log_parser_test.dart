import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/features/log_viewer/index/chunked_record_index.dart';
import 'package:logger/features/log_viewer/models/log_schema.dart';
import 'package:logger/features/log_viewer/parsers/delimited_log_parser.dart';
import 'package:logger/features/log_viewer/parsers/regex_log_parser.dart';

void main() {
  group('DelimitedLogParser', () {
    test(
      'joins a line split across chunks and preserves source offsets',
      () async {
        final parser = DelimitedLogParser(_pipeSchema(), batchSize: 2);

        final batches = await parser
            .parse(
              Stream.fromIterable([
                Uint8List.fromList(utf8.encode('10:00|hel')),
                Uint8List.fromList(utf8.encode('lo\n10:01|world\n')),
              ]),
              generation: 4,
            )
            .toList();

        final records = batches.expand((batch) => batch.records).toList();
        expect(records.map((record) => record.message), ['hello', 'world']);
        expect(records.map((record) => record.locator), const [
          RecordLocator(offset: 0, length: 11),
          RecordLocator(offset: 12, length: 11),
        ]);
        expect(batches.single.generation, 4);
        expect(batches.single.bytesConsumed, 24);
      },
    );

    test(
      'preserves extra and missing columns and reports mismatch deltas',
      () async {
        final parser = DelimitedLogParser(_pipeSchema(), batchSize: 2);

        final batches = await parser
            .parse(
              Stream.value(
                Uint8List.fromList(utf8.encode('a|b|extra\na\nz|q\n')),
              ),
              generation: 9,
            )
            .toList();

        expect(batches, hasLength(2));
        expect(batches.map((batch) => batch.records.length), [2, 1]);
        expect(batches.map((batch) => batch.bytesConsumed), [12, 16]);
        expect(batches.every((batch) => batch.generation == 9), isTrue);

        final records = batches.expand((batch) => batch.records).toList();
        expect(records, hasLength(3));
        expect(records.first.rawUnmapped, ['extra']);
        expect(records.first.hasSchemaMismatch, isTrue);
        expect(records[1].metadata['message'], isNull);
        expect(records[1].message, 'a');
        expect(records[1].hasSchemaMismatch, isTrue);
        expect(records.last.hasSchemaMismatch, isFalse);

        expect(batches.first.mismatches.extraColumnRecords, 1);
        expect(batches.first.mismatches.missingColumnRecords, 1);
        expect(batches.last.mismatches.isEmpty, isTrue);
      },
    );

    test('handles CRLF and emits the final unterminated line', () async {
      final parser = DelimitedLogParser(_pipeSchema(), batchSize: 8);

      final batches = await parser
          .parse(
            Stream.fromIterable([
              Uint8List.fromList(utf8.encode('a|b\r')),
              Uint8List.fromList(utf8.encode('\nc|d')),
            ]),
            generation: 1,
          )
          .toList();

      final records = batches.single.records;
      expect(records.map((record) => record.message), ['b', 'd']);
      expect(records.map((record) => record.locator), const [
        RecordLocator(offset: 0, length: 3),
        RecordLocator(offset: 5, length: 3),
      ]);
      expect(batches.single.bytesConsumed, 8);
    });

    test(
      'replaces malformed UTF-8 while keeping byte-based locators',
      () async {
        final parser = DelimitedLogParser(_pipeSchema(), batchSize: 8);

        final batches = await parser
            .parse(
              Stream.fromIterable([
                Uint8List.fromList([0xce]),
                Uint8List.fromList([
                  0xb1,
                  0x7c,
                  0x78,
                  0x0a,
                  0x66,
                  0x80,
                  0x6f,
                  0x7c,
                  0x79,
                ]),
              ]),
              generation: 2,
            )
            .toList();

        final records = batches.single.records;
        expect(records.first.metadata['time'], 'α');
        expect(records.last.metadata['time'], 'f�o');
        expect(records.map((record) => record.message), ['x', 'y']);
        expect(records.map((record) => record.locator), const [
          RecordLocator(offset: 0, length: 4),
          RecordLocator(offset: 5, length: 5),
        ]);
        expect(batches.single.bytesConsumed, 10);
      },
    );
  });

  group('RegexLogParser', () {
    test('maps named groups from a line split across chunks', () async {
      final parser = RegexLogParser(_regexSchema(), batchSize: 4);

      final batches = await parser
          .parse(
            Stream.fromIterable([
              Uint8List.fromList(utf8.encode('10:00 [INFO] hel')),
              Uint8List.fromList(utf8.encode('lo\n')),
            ]),
            generation: 5,
          )
          .toList();

      final record = batches.single.records.single;
      expect(record.message, 'hello');
      expect(record.metadata, {
        'time': '10:00',
        'log_level': 'INFO',
        'message': 'hello',
      });
      expect(record.locator, const RecordLocator(offset: 0, length: 18));
      expect(record.hasSchemaMismatch, isFalse);
    });

    test('keeps non-matching lines recoverable as mismatch records', () async {
      final parser = RegexLogParser(_regexSchema(), batchSize: 4);

      final batches = await parser
          .parse(
            Stream.value(Uint8List.fromList(utf8.encode('not a match'))),
            generation: 6,
          )
          .toList();

      final record = batches.single.records.single;
      expect(record.message, 'not a match');
      expect(record.metadata, isEmpty);
      expect(record.rawUnmapped, ['not a match']);
      expect(record.hasSchemaMismatch, isTrue);
      expect(batches.single.mismatches.regexNonMatchingRecords, 1);
      expect(batches.single.bytesConsumed, 11);
    });

    test('marks an unmatched optional mapped group as missing', () async {
      final schema = LogSchema(
        id: 'optional',
        name: 'Optional time',
        parserType: LogParserType.regex,
        regularExpression: r'^(?:(?<time>\d+) )?(?<message>\D+)$',
        mappings: [
          LogFieldMapping(source: 'time', fieldId: 'time'),
          LogFieldMapping(source: 'message', fieldId: 'message'),
        ],
      );
      final parser = RegexLogParser(schema, batchSize: 4);

      final batches = await parser
          .parse(
            Stream.value(Uint8List.fromList(utf8.encode('hello\n'))),
            generation: 7,
          )
          .toList();

      final record = batches.single.records.single;
      expect(record.message, 'hello');
      expect(record.metadata['time'], isNull);
      expect(record.metadata['message'], 'hello');
      expect(record.hasSchemaMismatch, isTrue);
      expect(batches.single.mismatches.missingColumnRecords, 1);
    });
  });
}

LogSchema _pipeSchema() => LogSchema(
  id: 'pipe',
  name: 'Pipe',
  parserType: LogParserType.delimited,
  delimiter: '|',
  mappings: [
    LogFieldMapping(source: '0', fieldId: 'time'),
    LogFieldMapping(source: '1', fieldId: 'message'),
  ],
);

LogSchema _regexSchema() => LogSchema(
  id: 'regex',
  name: 'Regex',
  parserType: LogParserType.regex,
  regularExpression: r'^(?<time>\S+) \[(?<level>[^\]]+)\] (?<message>.*)$',
  mappings: [
    LogFieldMapping(source: 'time', fieldId: 'time'),
    LogFieldMapping(source: 'level', fieldId: 'log_level'),
    LogFieldMapping(source: 'message', fieldId: 'message'),
  ],
);
