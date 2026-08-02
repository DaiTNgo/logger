import '../index/chunked_record_index.dart';
import '../models/log_schema.dart';
import '../models/schema_mismatch.dart';
import 'log_parser.dart';

final class RegexLogParser extends TextLogParserBase {
  RegexLogParser(this.schema, {super.batchSize = 512})
    : _expression = RegExp(schema.regularExpression ?? '') {
    if (schema.parserType != LogParserType.regex) {
      throw ArgumentError.value(
        schema.parserType,
        'schema.parserType',
        'Expected a regex schema',
      );
    }
  }

  final LogSchema schema;
  final RegExp _expression;

  @override
  ParsedLineResult parseLine(String line, RecordLocator locator) {
    final match = _expression.firstMatch(line);
    if (match == null) {
      return ParsedLineResult(
        record: ParsedRecord(
          locator: locator,
          metadata: const {},
          message: line,
          rawUnmapped: List.unmodifiable([line]),
          hasSchemaMismatch: true,
        ),
        mismatches: const SchemaMismatchSummary(regexNonMatchingRecords: 1),
      );
    }

    final metadata = <String, String>{};
    var hasMissingGroup = false;
    for (final mapping in schema.mappings) {
      String? value;
      try {
        value = match.namedGroup(mapping.source);
      } on ArgumentError {
        value = null;
      }
      if (value == null) {
        hasMissingGroup = true;
      } else {
        metadata[mapping.fieldId] = value;
      }
    }

    return ParsedLineResult(
      record: ParsedRecord(
        locator: locator,
        metadata: Map.unmodifiable(metadata),
        message: metadata['message'] ?? line,
        hasSchemaMismatch: hasMissingGroup,
      ),
      mismatches: SchemaMismatchSummary(
        missingColumnRecords: hasMissingGroup ? 1 : 0,
      ),
    );
  }
}
