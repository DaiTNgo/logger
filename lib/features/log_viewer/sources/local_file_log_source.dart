import 'dart:io';
import 'dart:typed_data';

import 'log_source.dart';

/// A [LogSource] backed by an on-disk file.
final class LocalFileLogSource implements LogSource {
  LocalFileLogSource(this.path, {int chunkSize = 64 * 1024})
      : chunkSize = _validateChunkSize(chunkSize);

  final String path;
  final int chunkSize;
  bool _isClosed = false;

  static int _validateChunkSize(int chunkSize) {
    if (chunkSize <= 0) {
      throw ArgumentError.value(chunkSize, 'chunkSize', 'Must be positive');
    }
    return chunkSize;
  }

  @override
  String get id => path;

  @override
  int? get byteLength => File(path).lengthSync();

  @override
  Stream<Uint8List> open({int startOffset = 0}) {
    _ensureOpen();
    if (startOffset < 0) {
      throw ArgumentError.value(startOffset, 'startOffset', 'Must not be negative');
    }
    return _streamFrom(startOffset);
  }

  Stream<Uint8List> _streamFrom(int startOffset) async* {
    final handle = await File(path).open();
    try {
      await handle.setPosition(startOffset);
      while (true) {
        final bytes = await handle.read(chunkSize);
        if (bytes.isEmpty) return;
        yield bytes;
      }
    } finally {
      await handle.close();
    }
  }

  @override
  Future<Uint8List> readRange(int offset, int length) {
    _ensureOpen();
    if (offset < 0) {
      throw ArgumentError.value(offset, 'offset', 'Must not be negative');
    }
    if (length < 0) {
      throw ArgumentError.value(length, 'length', 'Must not be negative');
    }
    return _readRange(offset, length);
  }

  Future<Uint8List> _readRange(int offset, int length) async {
    final handle = await File(path).open();
    try {
      await handle.setPosition(offset);
      return await handle.read(length);
    } finally {
      await handle.close();
    }
  }

  @override
  Future<void> close() async {
    _isClosed = true;
  }

  void _ensureOpen() {
    if (_isClosed) throw StateError('The log source has been closed.');
  }
}
