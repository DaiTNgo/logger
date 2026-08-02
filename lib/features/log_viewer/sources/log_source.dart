import 'dart:typed_data';

/// A byte-addressable log payload store.
///
/// Implementations can provide local files today and remote sources later
/// without changing parsers or the record index.
abstract interface class LogSource {
  String get id;
  int? get byteLength;
  Stream<Uint8List> open({int startOffset = 0});
  Future<Uint8List> readRange(int offset, int length);
  Future<void> close();
}
