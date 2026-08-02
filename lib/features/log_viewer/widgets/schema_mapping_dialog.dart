import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:logger/features/log_viewer/index/chunked_record_index.dart';
import 'package:logger/features/log_viewer/models/log_schema.dart';
import 'package:logger/features/log_viewer/parsers/delimited_log_parser.dart';
import 'package:logger/features/log_viewer/parsers/log_parser.dart';
import 'package:logger/features/log_viewer/parsers/regex_log_parser.dart';
import 'package:logger/features/log_viewer/services/schema_preset_repository.dart';

const maxLogSampleBytes = 256 * 1024;
const maxLogSampleRecords = 200;

final class ConfirmedLogImport {
  const ConfirmedLogImport({required this.path, required this.schema});

  final String path;
  final LogSchema schema;
}

final class LogSample {
  LogSample({required this.bytes, required List<String> lines})
    : lines = List.unmodifiable(lines);

  final Uint8List bytes;
  final List<String> lines;
}

Future<LogSample> loadLogSample(String path) async {
  final file = File(path).openSync();
  try {
    final length = file.lengthSync();
    final bytes = file.readSync(
      length < maxLogSampleBytes ? length : maxLogSampleBytes,
    );
    var end = bytes.length;
    var records = 0;
    for (var index = 0; index < bytes.length; index++) {
      if (bytes[index] != 0x0a) continue;
      records++;
      if (records == maxLogSampleRecords) {
        end = index + 1;
        break;
      }
    }
    final boundedBytes = end == bytes.length
        ? bytes
        : Uint8List.sublistView(bytes, 0, end);
    final decoded = utf8.decode(boundedBytes, allowMalformed: true);
    final lines = const LineSplitter()
        .convert(decoded)
        .take(maxLogSampleRecords)
        .toList(growable: false);
    return LogSample(bytes: boundedBytes, lines: lines);
  } finally {
    file.closeSync();
  }
}

Future<ConfirmedLogImport?> showSchemaMappingDialog({
  required BuildContext context,
  required String path,
  required SchemaPresetRepository presetRepository,
  LogSchema? initialSchema,
}) async {
  LogSample sample;
  String? loadError;
  try {
    sample = await loadLogSample(path);
  } on FileSystemException catch (error) {
    sample = LogSample(bytes: Uint8List(0), lines: const []);
    loadError = error.message;
  }
  if (!context.mounted) return null;

  final presets = await presetRepository.load();
  if (!context.mounted) return null;
  return showDialog<ConfirmedLogImport>(
    context: context,
    barrierDismissible: false,
    builder: (context) => SchemaMappingDialog(
      path: path,
      sample: sample,
      presets: presets,
      presetRepository: presetRepository,
      initialSchema: initialSchema,
      loadError: loadError,
    ),
  );
}

class SchemaMappingDialog extends StatefulWidget {
  const SchemaMappingDialog({
    super.key,
    required this.path,
    required this.sample,
    required this.presets,
    required this.presetRepository,
    this.initialSchema,
    this.loadError,
  });

  final String path;
  final LogSample sample;
  final List<SchemaPreset> presets;
  final SchemaPresetRepository presetRepository;
  final LogSchema? initialSchema;
  final String? loadError;

  @override
  State<SchemaMappingDialog> createState() => _SchemaMappingDialogState();
}

class _SchemaMappingDialogState extends State<SchemaMappingDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _delimiterController;
  late final TextEditingController _regexController;
  final _mappingControllers = <TextEditingController>[];
  final _mappingSources = <String>[];
  late LogParserType _parserType;
  List<ParsedRecord> _preview = const [];
  String? _validationError;
  String? _selectedPresetId;
  var _previewRevision = 0;
  var _presetSaved = false;

  @override
  void initState() {
    super.initState();
    final initial =
        widget.initialSchema ?? _detectedSchema(widget.path, widget.sample);
    _nameController = TextEditingController(text: initial.name);
    _delimiterController = TextEditingController(
      text: initial.delimiter ?? '|',
    );
    _regexController = TextEditingController(
      text:
          initial.regularExpression ??
          r'^(?<time>\S+)\s+\[(?<log_level>[^\]]+)\]\s+(?<message>.*)$',
    );
    _parserType = initial.parserType;
    _setMappings(initial.mappings);
    _nameController.addListener(_configurationChanged);
    _delimiterController.addListener(_configurationChanged);
    _regexController.addListener(_configurationChanged);
    _refreshPreview();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _delimiterController.dispose();
    _regexController.dispose();
    for (final controller in _mappingControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _setMappings(List<LogFieldMapping> mappings) {
    for (final controller in _mappingControllers) {
      controller
        ..removeListener(_configurationChanged)
        ..dispose();
    }
    _mappingControllers.clear();
    _mappingSources
      ..clear()
      ..addAll(mappings.map((mapping) => mapping.source));
    for (final mapping in mappings) {
      final controller = TextEditingController(text: mapping.fieldId);
      controller.addListener(_configurationChanged);
      _mappingControllers.add(controller);
    }
  }

  void _configurationChanged() {
    _presetSaved = false;
    _refreshPreview();
  }

  LogSchema? _buildSchema() {
    try {
      return LogSchema(
        id: _schemaId(_nameController.text),
        name: _nameController.text.trim(),
        parserType: _parserType,
        delimiter: _parserType == LogParserType.delimited
            ? _delimiterController.text
            : null,
        regularExpression: _parserType == LogParserType.regex
            ? _regexController.text
            : null,
        mappings: [
          for (var index = 0; index < _mappingControllers.length; index++)
            LogFieldMapping(
              source: _mappingSources[index],
              fieldId: _mappingControllers[index].text,
            ),
        ],
      );
    } on ArgumentError catch (error) {
      _validationError = _friendlyValidationError(error);
      return null;
    } on FormatException catch (error) {
      _validationError = error.message;
      return null;
    }
  }

  Future<void> _refreshPreview() async {
    final revision = ++_previewRevision;
    _validationError = widget.loadError;
    final schema = _buildSchema();
    if (schema == null || widget.loadError != null) {
      if (mounted) setState(() => _preview = const []);
      return;
    }

    try {
      final parser = switch (schema.parserType) {
        LogParserType.delimited => DelimitedLogParser(
          schema,
          batchSize: maxLogSampleRecords,
        ),
        LogParserType.regex => RegexLogParser(
          schema,
          batchSize: maxLogSampleRecords,
        ),
        LogParserType.dlt => null,
      };
      final records = parser == null
          ? _dltPreview(widget.sample)
          : await parser
                .parse(Stream.value(widget.sample.bytes), generation: 0)
                .expand((batch) => batch.records)
                .take(maxLogSampleRecords)
                .toList();
      if (!mounted || revision != _previewRevision) return;
      setState(() {
        _preview = records;
        if (records.isEmpty) {
          _validationError =
              'The sample does not contain a recoverable record.';
        }
      });
    } on Object catch (error) {
      if (!mounted || revision != _previewRevision) return;
      setState(() {
        _preview = const [];
        _validationError = 'Unable to preview this mapping: $error';
      });
    }
  }

  void _selectParser(LogParserType? type) {
    if (type == null || type == _parserType) return;
    setState(() {
      _parserType = type;
      _selectedPresetId = null;
      final mappings = switch (type) {
        LogParserType.delimited => _detectedDelimitedMappings(widget.sample),
        LogParserType.regex => [
          LogFieldMapping(source: 'time', fieldId: 'time'),
          LogFieldMapping(source: 'log_level', fieldId: 'log_level'),
          LogFieldMapping(source: 'message', fieldId: 'message'),
        ],
        LogParserType.dlt => [
          LogFieldMapping(source: 'payload', fieldId: 'message'),
        ],
      };
      _setMappings(mappings);
    });
    _refreshPreview();
  }

  void _selectPreset(String? schemaId) {
    if (schemaId == null) return;
    final schema = widget.presets
        .firstWhere((preset) => preset.schema.id == schemaId)
        .schema;
    setState(() {
      _selectedPresetId = schemaId;
      _parserType = schema.parserType;
      _nameController.text = schema.name;
      _delimiterController.text = schema.delimiter ?? '|';
      _regexController.text = schema.regularExpression ?? _regexController.text;
      _setMappings(schema.mappings);
    });
    _refreshPreview();
  }

  Future<void> _savePreset() async {
    final schema = _buildSchema();
    if (schema == null || _preview.isEmpty) {
      setState(() {});
      return;
    }
    await widget.presetRepository.save(SchemaPreset(schema: schema));
    if (mounted) setState(() => _presetSaved = true);
  }

  @override
  Widget build(BuildContext context) {
    final schema = _buildSchema();
    final canConfirm = schema != null && _preview.isNotEmpty;
    return AlertDialog(
      key: const Key('schema_mapping_dialog'),
      title: const Text('Review log mapping'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.path, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<LogParserType>(
                      key: const Key('schema_parser_type'),
                      initialValue: _parserType,
                      decoration: const InputDecoration(
                        labelText: 'Parser type',
                      ),
                      items: [
                        for (final type in LogParserType.values)
                          DropdownMenuItem(value: type, child: Text(type.name)),
                      ],
                      onChanged: _selectParser,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: const Key('schema_preset'),
                      initialValue: _selectedPresetId,
                      decoration: const InputDecoration(labelText: 'Preset'),
                      items: [
                        for (final preset in widget.presets)
                          DropdownMenuItem(
                            value: preset.schema.id,
                            child: Text(preset.schema.name),
                          ),
                      ],
                      onChanged: _selectPreset,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('schema_name'),
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Schema name'),
              ),
              if (_parserType == LogParserType.delimited)
                TextField(
                  key: const Key('schema_delimiter'),
                  controller: _delimiterController,
                  decoration: const InputDecoration(labelText: 'Delimiter'),
                ),
              if (_parserType == LogParserType.regex)
                TextField(
                  key: const Key('schema_regular_expression'),
                  controller: _regexController,
                  decoration: const InputDecoration(
                    labelText: 'Regular expression',
                  ),
                ),
              const SizedBox(height: 12),
              const Text('Field mappings'),
              for (var index = 0; index < _mappingControllers.length; index++)
                Row(
                  children: [
                    SizedBox(width: 120, child: Text(_mappingSources[index])),
                    Expanded(
                      child: TextField(
                        key: Key('mapping_field_$index'),
                        controller: _mappingControllers[index],
                        decoration: const InputDecoration(labelText: 'Field'),
                      ),
                    ),
                  ],
                ),
              if (_validationError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _validationError!,
                    key: const Key('schema_mapping_error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              const Text('Preview'),
              _SchemaPreviewTable(schema: schema, records: _preview),
              if (_presetSaved)
                const Text('Preset saved', key: Key('schema_preset_saved')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('save_schema_preset'),
          onPressed: canConfirm ? _savePreset : null,
          child: const Text('Save preset'),
        ),
        TextButton(
          key: const Key('cancel_log_import'),
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('confirm_log_import'),
          onPressed: canConfirm
              ? () => Navigator.pop(
                  context,
                  ConfirmedLogImport(path: widget.path, schema: schema),
                )
              : null,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

class _SchemaPreviewTable extends StatelessWidget {
  const _SchemaPreviewTable({required this.schema, required this.records});

  final LogSchema? schema;
  final List<ParsedRecord> records;

  @override
  Widget build(BuildContext context) {
    final fieldIds =
        schema?.mappings
            .map((mapping) => mapping.fieldId)
            .toList(growable: false) ??
        const <String>[];
    return Container(
      key: const Key('schema_preview_table'),
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: records.isEmpty
          ? const Center(child: Text('No recoverable records'))
          : SingleChildScrollView(
              child: Table(
                border: TableBorder.all(color: Theme.of(context).dividerColor),
                children: [
                  TableRow(
                    children: [
                      for (final fieldId in fieldIds)
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(
                            fieldId,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  for (final record in records)
                    TableRow(
                      children: [
                        for (final fieldId in fieldIds)
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(
                              fieldId == 'message'
                                  ? record.message
                                  : record.metadata[fieldId] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}

LogSchema _detectedSchema(String path, LogSample sample) {
  if (path.toLowerCase().endsWith('.dlt')) {
    return LogSchema(
      id: 'dlt',
      name: 'DLT logs',
      parserType: LogParserType.dlt,
      mappings: [LogFieldMapping(source: 'payload', fieldId: 'message')],
    );
  }
  final delimiter = _detectDelimiter(_firstLine(sample));
  return LogSchema(
    id: 'detected-text',
    name: 'Detected text log',
    parserType: LogParserType.delimited,
    delimiter: delimiter,
    mappings: _detectedDelimitedMappings(sample, delimiter: delimiter),
  );
}

List<LogFieldMapping> _detectedDelimitedMappings(
  LogSample sample, {
  String? delimiter,
}) {
  final separator = delimiter ?? _detectDelimiter(_firstLine(sample));
  final count = _firstLine(sample).split(separator).length;
  if (count <= 1) {
    return [LogFieldMapping(source: '0', fieldId: 'message')];
  }
  return [
    for (var index = 0; index < count; index++)
      LogFieldMapping(
        source: '$index',
        fieldId: switch (index) {
          0 => 'time',
          1 when count >= 3 => 'log_level',
          _ when index == count - 1 => 'message',
          _ => 'field_$index',
        },
      ),
  ];
}

String _detectDelimiter(String line) {
  const candidates = ['|', '\t', ',', ';'];
  var selected = '|';
  var selectedCount = 1;
  for (final candidate in candidates) {
    final count = line.split(candidate).length;
    if (count > selectedCount) {
      selected = candidate;
      selectedCount = count;
    }
  }
  return selected;
}

List<ParsedRecord> _dltPreview(LogSample sample) {
  if (sample.bytes.isEmpty) return const [];
  final message = sample.lines.isEmpty
      ? '${sample.bytes.length} bytes'
      : sample.lines.first;
  return [
    ParsedRecord(
      locator: const RecordLocator(offset: 0, length: 0),
      metadata: {'message': message},
      message: message,
    ),
  ];
}

String _firstLine(LogSample sample) =>
    sample.lines.isEmpty ? '' : sample.lines.first;

String _schemaId(String name) {
  final normalized = name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return normalized.isEmpty ? 'custom-log-schema' : normalized;
}

String _friendlyValidationError(ArgumentError error) =>
    error.message?.toString() ?? 'The schema mapping is invalid.';
