import '../index/chunked_record_index.dart';
import '../models/log_schema.dart';
import '../models/schema_mismatch.dart';
import 'log_parser.dart';

final class DelimitedLogParser extends TextLogParserBase {
  DelimitedLogParser(this.schema, {super.batchSize = 512})
    : _mappings = _parseMappings(schema),
      _expectedColumnCount = _columnCount(schema) {
    if (schema.parserType != LogParserType.delimited) {
      throw ArgumentError.value(
        schema.parserType,
        'schema.parserType',
        'Expected a delimited schema',
      );
    }
  }

  final LogSchema schema;
  final List<_PositionMapping> _mappings;
  final int _expectedColumnCount;

  @override
  ParsedLineResult parseLine(String line, RecordLocator locator) {
    final tokens = line.split(schema.delimiter!);
    final metadata = <String, String>{};
    final rawUnmapped = <String>[];

    for (final mapping in _mappings) {
      if (mapping.position < tokens.length) {
        metadata[mapping.fieldId] = tokens[mapping.position];
      }
    }
    for (var position = 0; position < tokens.length; position++) {
      if (!_mappings.any((mapping) => mapping.position == position)) {
        rawUnmapped.add(tokens[position]);
      }
    }

    final hasExtraColumns = tokens.length > _expectedColumnCount;
    final hasMissingColumns = tokens.length < _expectedColumnCount;
    final hasMismatch = hasExtraColumns || hasMissingColumns;
    final mismatches = SchemaMismatchSummary(
      extraColumnRecords: hasExtraColumns ? 1 : 0,
      missingColumnRecords: hasMissingColumns ? 1 : 0,
    );

    return ParsedLineResult(
      record: ParsedRecord(
        locator: locator,
        metadata: Map.unmodifiable(metadata),
        message: metadata['message'] ?? line,
        rawUnmapped: List.unmodifiable(rawUnmapped),
        hasSchemaMismatch: hasMismatch,
      ),
      mismatches: mismatches,
    );
  }
}

final class _PositionMapping {
  const _PositionMapping(this.position, this.fieldId);

  final int position;
  final String fieldId;
}

List<_PositionMapping> _parseMappings(LogSchema schema) {
  return schema.mappings
      .map((mapping) {
        final position = int.tryParse(mapping.source);
        if (position == null || position < 0) {
          throw ArgumentError.value(
            mapping.source,
            'mapping.source',
            'Delimited mapping sources must be non-negative integers',
          );
        }
        return _PositionMapping(position, mapping.fieldId);
      })
      .toList(growable: false);
}

int _columnCount(LogSchema schema) {
  final mappings = _parseMappings(schema);
  return mappings.fold<int>(
    0,
    (count, mapping) =>
        mapping.position >= count ? mapping.position + 1 : count,
  );
}
