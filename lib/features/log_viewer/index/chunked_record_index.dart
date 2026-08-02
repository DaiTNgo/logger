import 'dart:collection';
import 'dart:typed_data';

/// The byte location of one record in its [LogSource] payload.
final class RecordLocator {
  const RecordLocator({required this.offset, required this.length});

  final int offset;
  final int length;

  @override
  bool operator ==(Object other) =>
      other is RecordLocator && other.offset == offset && other.length == length;

  @override
  int get hashCode => Object.hash(offset, length);
}

/// Transient metadata supplied while appending a record.
///
/// Its map is converted to dictionary-coded columns by [ChunkedRecordIndex]
/// and is never retained as record storage.
class IndexedMetadata {
  const IndexedMetadata(this.values);

  final Map<String, String> values;

  String? value(String fieldId) => values[fieldId];
}

/// Compact bit flags describing import-time record conditions.
final class RecordFlags {
  const RecordFlags._(this._bits);

  static const none = RecordFlags._(0);
  static const schemaMismatch = RecordFlags._(1);

  final int _bits;

  bool get hasSchemaMismatch => (_bits & schemaMismatch._bits) != 0;
}

/// A compact, chunked index of record locations and dictionary-coded metadata.
final class ChunkedRecordIndex {
  ChunkedRecordIndex({int chunkCapacity = 4096})
      : chunkCapacity = _validateCapacity(chunkCapacity);

  final int chunkCapacity;
  final List<_RecordChunk> _chunks = [];
  final Map<String, _MetadataColumn> _metadataColumns = {};
  int _length = 0;

  int get length => _length;

  static int _validateCapacity(int capacity) {
    if (capacity <= 0) {
      throw ArgumentError.value(capacity, 'chunkCapacity', 'Must be positive');
    }
    return capacity;
  }

  void append(
    RecordLocator locator, {
    IndexedMetadata metadata = const IndexedMetadata({}),
    RecordFlags flags = RecordFlags.none,
  }) {
    _validateLocator(locator);
    final chunkIndex = _length ~/ chunkCapacity;
    final rowIndex = _length % chunkCapacity;
    if (rowIndex == 0) _chunks.add(_RecordChunk(chunkCapacity));
    final chunk = _chunks[chunkIndex];
    chunk.offsets[rowIndex] = locator.offset;
    chunk.lengths[rowIndex] = locator.length;
    chunk.flags[rowIndex] = flags._bits;

    for (final entry in metadata.values.entries) {
      final column = _metadataColumns.putIfAbsent(
        entry.key,
        () => _MetadataColumn(chunkCapacity, _chunks.length),
      );
      column.set(chunkIndex, rowIndex, entry.value);
    }
    _length++;
  }

  RecordLocator locatorAt(int index) {
    _validateIndex(index);
    final chunk = _chunks[index ~/ chunkCapacity];
    final row = index % chunkCapacity;
    return RecordLocator(offset: chunk.offsets[row], length: chunk.lengths[row]);
  }

  RecordFlags flagsAt(int index) {
    _validateIndex(index);
    return RecordFlags._(_chunks[index ~/ chunkCapacity].flags[index % chunkCapacity]);
  }

  IndexedMetadata metadataAt(int index) {
    _validateIndex(index);
    return _MetadataView(this, index);
  }

  String? _metadataValueAt(int index, String fieldId) =>
      _metadataColumns[fieldId]?.valueAt(index ~/ chunkCapacity, index % chunkCapacity);

  void _validateLocator(RecordLocator locator) {
    if (locator.offset < 0) {
      throw ArgumentError.value(locator.offset, 'locator.offset', 'Must not be negative');
    }
    if (locator.length < 0 || locator.length > 0xffffffff) {
      throw ArgumentError.value(locator.length, 'locator.length', 'Must fit Uint32');
    }
  }

  void _validateIndex(int index) {
    if (index < 0 || index >= _length) {
      throw RangeError.index(index, this, 'index', null, _length);
    }
  }
}

final class _RecordChunk {
  _RecordChunk(int capacity)
      : offsets = Uint64List(capacity),
        lengths = Uint32List(capacity),
        flags = Uint8List(capacity);

  final Uint64List offsets;
  final Uint32List lengths;
  final Uint8List flags;
}

final class _MetadataColumn {
  _MetadataColumn(this._chunkCapacity, int chunkCount) {
    for (var i = 0; i < chunkCount; i++) {
      _ids.add(Uint32List(_chunkCapacity));
    }
  }

  final int _chunkCapacity;
  final List<Uint32List> _ids = [];
  final Map<String, int> _valueIds = {};
  final List<String> _values = [];

  void set(int chunkIndex, int rowIndex, String value) {
    while (_ids.length <= chunkIndex) {
      _ids.add(Uint32List(_chunkCapacity));
    }
    final id = _valueIds.putIfAbsent(value, () {
      _values.add(value);
      return _values.length;
    });
    _ids[chunkIndex][rowIndex] = id;
  }

  String? valueAt(int chunkIndex, int rowIndex) {
    if (chunkIndex >= _ids.length) return null;
    final id = _ids[chunkIndex][rowIndex];
    return id == 0 ? null : _values[id - 1];
  }
}

final class _MetadataView implements IndexedMetadata {
  _MetadataView(this._index, this._recordIndex);

  final ChunkedRecordIndex _index;
  final int _recordIndex;

  @override
  Map<String, String> get values => _MetadataValuesView(_index, _recordIndex);

  @override
  String? value(String fieldId) => _index._metadataValueAt(_recordIndex, fieldId);
}

final class _MetadataValuesView extends MapBase<String, String> {
  _MetadataValuesView(this._index, this._recordIndex);

  final ChunkedRecordIndex _index;
  final int _recordIndex;

  @override
  String? operator [](Object? key) =>
      key is String ? _index._metadataValueAt(_recordIndex, key) : null;

  @override
  Iterable<String> get keys => _index._metadataColumns.keys.where(
        (fieldId) => _index._metadataValueAt(_recordIndex, fieldId) != null,
      );

  @override
  void operator []=(String key, String value) {
    throw UnsupportedError('Indexed metadata views are read-only.');
  }

  @override
  String? remove(Object? key) {
    throw UnsupportedError('Indexed metadata views are read-only.');
  }

  @override
  void clear() {
    throw UnsupportedError('Indexed metadata views are read-only.');
  }
}
