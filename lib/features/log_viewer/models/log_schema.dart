enum LogParserType { delimited, regex, dlt }

final class LogFieldMapping {
  LogFieldMapping({required String source, required String fieldId})
    : source = source.trim(),
      fieldId = _normalizeFieldId(fieldId) {
    if (this.source.isEmpty || this.fieldId.isEmpty) {
      throw ArgumentError('Mapping sources and field IDs must not be empty.');
    }
  }

  final String source;
  final String fieldId;

  factory LogFieldMapping.fromJson(Map<String, Object?> json) {
    return LogFieldMapping(
      source: _requiredString(json, 'source'),
      fieldId: _requiredString(json, 'fieldId'),
    );
  }

  Map<String, Object> toJson() => {'source': source, 'fieldId': fieldId};

  @override
  bool operator ==(Object other) =>
      other is LogFieldMapping &&
      other.source == source &&
      other.fieldId == fieldId;

  @override
  int get hashCode => Object.hash(source, fieldId);
}

final class LogSchema {
  LogSchema({
    required this.id,
    required this.name,
    required this.parserType,
    required List<LogFieldMapping> mappings,
    this.delimiter,
    this.regularExpression,
  }) : mappings = List.unmodifiable(mappings) {
    _validate();
  }

  final String id;
  final String name;
  final LogParserType parserType;
  final String? delimiter;
  final String? regularExpression;
  final List<LogFieldMapping> mappings;

  Set<String> get availableFieldIds =>
      mappings.map((mapping) => _normalizeFieldId(mapping.fieldId)).toSet();

  factory LogSchema.fromJson(Map<String, Object?> json) {
    final parserTypeName = _requiredString(json, 'parserType');
    final parserType = LogParserType.values.where(
      (type) => type.name == parserTypeName,
    );
    if (parserType.length != 1) {
      throw ArgumentError.value(
        parserTypeName,
        'parserType',
        'Unknown parser type',
      );
    }
    final rawMappings = json['mappings'];
    if (rawMappings is! List) {
      throw ArgumentError.value(rawMappings, 'mappings', 'Expected a list');
    }
    return LogSchema(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      parserType: parserType.single,
      delimiter: _optionalString(json, 'delimiter'),
      regularExpression: _optionalString(json, 'regularExpression'),
      mappings: rawMappings
          .map((rawMapping) {
            if (rawMapping is! Map) {
              throw ArgumentError.value(
                rawMapping,
                'mappings',
                'Expected a map',
              );
            }
            return LogFieldMapping.fromJson(
              Map<String, Object?>.from(rawMapping),
            );
          })
          .toList(growable: false),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'parserType': parserType.name,
    'delimiter': delimiter,
    'regularExpression': regularExpression,
    'mappings': mappings
        .map((mapping) => mapping.toJson())
        .toList(growable: false),
  };

  void _validate() {
    if (id.trim().isEmpty || name.trim().isEmpty) {
      throw ArgumentError('Schema id and name must not be empty.');
    }
    if (mappings.isEmpty || !_hasMessageMapping(mappings)) {
      throw ArgumentError('A schema must map a message field.');
    }
    if (!_hasUniqueNormalizedFieldIds(mappings)) {
      throw ArgumentError('Schema field mappings must be unique.');
    }
    switch (parserType) {
      case LogParserType.delimited:
        if (delimiter == null || delimiter!.isEmpty) {
          throw ArgumentError('Delimited schemas require a delimiter.');
        }
      case LogParserType.regex:
        if (regularExpression == null || regularExpression!.isEmpty) {
          throw ArgumentError('Regex schemas require a regular expression.');
        }
        if (!_hasNamedMessageGroup(regularExpression)) {
          throw ArgumentError('Regex schemas require a named message group.');
        }
      case LogParserType.dlt:
        break;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is LogSchema &&
      other.id == id &&
      other.name == name &&
      other.parserType == parserType &&
      other.delimiter == delimiter &&
      other.regularExpression == regularExpression &&
      _sameMappings(other.mappings, mappings);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    parserType,
    delimiter,
    regularExpression,
    Object.hashAll(mappings),
  );
}

final class SchemaPreset {
  SchemaPreset({required this.schema});

  final LogSchema schema;

  factory SchemaPreset.fromJson(Map<String, Object?> json) {
    final rawSchema = json['schema'];
    if (rawSchema is! Map) {
      throw ArgumentError.value(rawSchema, 'schema', 'Expected a map');
    }
    return SchemaPreset(
      schema: LogSchema.fromJson(Map<String, Object?>.from(rawSchema)),
    );
  }

  Map<String, Object?> toJson() => {'schema': schema.toJson()};

  @override
  bool operator ==(Object other) =>
      other is SchemaPreset && other.schema == schema;

  @override
  int get hashCode => schema.hashCode;
}

bool _hasMessageMapping(List<LogFieldMapping> mappings) =>
    mappings.any((mapping) => _normalizeFieldId(mapping.fieldId) == 'message');

bool _hasUniqueNormalizedFieldIds(List<LogFieldMapping> mappings) {
  final fieldIds = mappings
      .map((mapping) => _normalizeFieldId(mapping.fieldId))
      .toList(growable: false);
  return fieldIds.toSet().length == fieldIds.length;
}

bool _hasNamedMessageGroup(String? expression) {
  if (expression == null) {
    return false;
  }
  try {
    RegExp(expression);
    return _containsNamedMessageGroup(expression);
  } on FormatException {
    return false;
  }
}

bool _containsNamedMessageGroup(String expression) {
  var inCharacterClass = false;

  for (var index = 0; index < expression.length; index++) {
    final character = expression[index];
    if (character == r'\') {
      index++;
      continue;
    }
    if (inCharacterClass) {
      if (character == ']') {
        inCharacterClass = false;
      }
      continue;
    }
    if (character == '[') {
      inCharacterClass = true;
      continue;
    }
    if (character != '(' || !expression.startsWith('?<message>', index + 1)) {
      continue;
    }
    return true;
  }

  return false;
}

bool _sameMappings(List<LogFieldMapping> left, List<LogFieldMapping> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

String _normalizeFieldId(String fieldId) => fieldId
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw ArgumentError.value(value, key, 'Expected a non-empty string');
  }
  return value;
}

String? _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw ArgumentError.value(value, key, 'Expected a string or null');
  }
  return value;
}
