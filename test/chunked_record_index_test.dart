import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/features/log_viewer/index/chunked_record_index.dart';
import 'package:logger/features/log_viewer/sources/local_file_log_source.dart';

void main() {
  test('chunked index preserves offsets beyond 32-bit range and metadata', () {
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

  test('chunked index grows into bounded typed-buffer chunks', () {
    final index = ChunkedRecordIndex(chunkCapacity: 2);
    for (var i = 0; i < 3; i++) {
      index.append(RecordLocator(offset: i * 10, length: 10));
    }

    expect(index.length, 3);
    expect(index.locatorAt(2), const RecordLocator(offset: 20, length: 10));
  });

  test('metadata view exposes stored fields and can be appended', () {
    final sourceIndex = ChunkedRecordIndex();
    sourceIndex.append(
      const RecordLocator(offset: 0, length: 1),
      metadata: const IndexedMetadata({'apid': 'CORE', 'ctid': 'CTRL'}),
    );

    final metadata = sourceIndex.metadataAt(0);
    expect(metadata.values, {'apid': 'CORE', 'ctid': 'CTRL'});

    final destinationIndex = ChunkedRecordIndex();
    destinationIndex.append(
      const RecordLocator(offset: 1, length: 1),
      metadata: metadata,
    );
    expect(destinationIndex.metadataAt(0).values, {
      'apid': 'CORE',
      'ctid': 'CTRL',
    });
  });

  test('source and index reject nonpositive capacities at runtime', () {
    expect(() => ChunkedRecordIndex(chunkCapacity: 0), throwsArgumentError);
    expect(
      () => LocalFileLogSource('unused.bin', chunkSize: 0),
      throwsArgumentError,
    );
  });

  test('local file source streams chunks and supports independent range reads',
      () async {
    final file = File('${Directory.systemTemp.path}/logger-source-test.bin');
    addTearDown(() async {
      if (await file.exists()) await file.delete();
    });
    await file.writeAsBytes(List<int>.generate(32, (index) => index));
    final source = LocalFileLogSource(file.path, chunkSize: 7);
    addTearDown(source.close);

    expect(
      await source.open().expand((bytes) => bytes).toList(),
      List<int>.generate(32, (index) => index),
    );
    expect(await source.readRange(9, 4), [9, 10, 11, 12]);
  });

  test('local file source rejects invalid ranges and reads after close', () async {
    final file = File('${Directory.systemTemp.path}/logger-source-close-test.bin');
    addTearDown(() async {
      if (await file.exists()) await file.delete();
    });
    await file.writeAsBytes([1, 2, 3]);
    final source = LocalFileLogSource(file.path);

    expect(() => source.readRange(-1, 1), throwsArgumentError);
    await source.close();
    expect(() => source.open(), throwsStateError);
    expect(() => source.readRange(0, 1), throwsStateError);
  });
}
