import 'package:flutter_test/flutter_test.dart';
import 'package:logger/features/log_viewer/models/log_schema.dart';
import 'package:logger/features/log_viewer/services/schema_preset_repository.dart';

void main() {
  final pipeSchema = LogSchema(
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

  test('schema JSON preserves delimiter and normalized mappings', () {
    final schema = LogSchema(
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
        mappings: [LogFieldMapping(source: '0', fieldId: 'time')],
      ),
      throwsArgumentError,
    );
  });

  test('schema requires a named message group for regex schemas', () {
    expect(
      () => LogSchema(
        id: 'regex',
        name: 'Regex',
        parserType: LogParserType.regex,
        regularExpression: r'^(?<time>.+)$',
        mappings: [LogFieldMapping(source: 'time', fieldId: 'message')],
      ),
      throwsArgumentError,
    );
  });

  test('schema recognizes a message group after an escaped backslash', () {
    expect(
      () => LogSchema(
        id: 'escaped-backslash',
        name: 'Escaped backslash',
        parserType: LogParserType.regex,
        regularExpression: r'\\(?<message>.*)',
        mappings: [LogFieldMapping(source: 'message', fieldId: 'message')],
      ),
      returnsNormally,
    );
  });

  test('schema ignores a message-group lookalike inside a character class', () {
    expect(
      () => LogSchema(
        id: 'character-class',
        name: 'Character class',
        parserType: LogParserType.regex,
        regularExpression: r'[(?<message>]',
        mappings: [LogFieldMapping(source: 'message', fieldId: 'message')],
      ),
      throwsArgumentError,
    );
  });

  test(
    'repository saves sorted presets and replaces duplicate schema IDs',
    () async {
      final store = _MemoryStore();
      final repository = SchemaPresetRepository(store);
      final alpha = LogSchema(
        id: 'alpha',
        name: 'Alpha logs',
        parserType: LogParserType.dlt,
        mappings: [LogFieldMapping(source: 'payload', fieldId: 'message')],
      );
      final updatedPipe = LogSchema(
        id: 'pipe-v1',
        name: 'Updated pipe logs',
        parserType: LogParserType.delimited,
        delimiter: ',',
        mappings: [LogFieldMapping(source: '0', fieldId: 'message')],
      );

      await repository.save(SchemaPreset(schema: pipeSchema));
      await repository.save(SchemaPreset(schema: alpha));
      await repository.save(SchemaPreset(schema: updatedPipe));

      expect(await repository.load(), [
        SchemaPreset(schema: alpha),
        SchemaPreset(schema: updatedPipe),
      ]);
    },
  );

  test(
    'repository deletes one preset without retaining any other data',
    () async {
      final store = _MemoryStore();
      final repository = SchemaPresetRepository(store);
      await repository.save(SchemaPreset(schema: pipeSchema));

      await repository.delete('pipe-v1');

      expect(await repository.load(), isEmpty);
    },
  );

  test(
    'repository recovers from malformed JSON without deleting raw storage',
    () async {
      final store = _MemoryStore()
        ..values[SchemaPresetRepository.storageKey] = '{not JSON';
      final repository = SchemaPresetRepository(store);

      expect(await repository.load(), isEmpty);
      expect(store.values[SchemaPresetRepository.storageKey], '{not JSON');
    },
  );
}

final class _MemoryStore implements StringPreferenceStore {
  final Map<String, String> values = {};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}
