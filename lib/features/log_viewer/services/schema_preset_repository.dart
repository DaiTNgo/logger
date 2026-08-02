import 'dart:convert';

import 'package:logger/features/log_viewer/models/log_schema.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class StringPreferenceStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
}

final class SharedPreferencesStringStore implements StringPreferenceStore {
  SharedPreferencesStringStore(this.preferences);

  final SharedPreferencesAsync preferences;

  @override
  Future<String?> getString(String key) => preferences.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      preferences.setString(key, value);
}

/// Uses platform preferences when available and retains process-local values
/// when the platform service is unavailable (for example, in widget tests).
final class ResilientSharedPreferencesStringStore
    implements StringPreferenceStore {
  SharedPreferencesAsync? _preferences;
  final Map<String, String> _fallbackValues = {};
  var _platformUnavailable = false;

  @override
  Future<String?> getString(String key) async {
    if (_platformUnavailable) return _fallbackValues[key];
    try {
      _preferences ??= SharedPreferencesAsync();
      return await _preferences!.getString(key) ?? _fallbackValues[key];
    } catch (_) {
      _platformUnavailable = true;
      return _fallbackValues[key];
    }
  }

  @override
  Future<void> setString(String key, String value) async {
    _fallbackValues[key] = value;
    if (_platformUnavailable) return;
    try {
      _preferences ??= SharedPreferencesAsync();
      await _preferences!.setString(key, value);
    } catch (_) {
      _platformUnavailable = true;
    }
  }
}

final class SchemaPresetRepository {
  SchemaPresetRepository(this.store);

  static const storageKey = 'logger.schema-presets.v1';

  final StringPreferenceStore store;

  Future<List<SchemaPreset>> load() async {
    final value = await store.getString(storageKey);
    if (value == null) {
      return const [];
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) {
        return const [];
      }
      final presets = decoded
          .map((item) {
            if (item is! Map) {
              throw const FormatException('A stored preset must be an object.');
            }
            return SchemaPreset.fromJson(Map<String, Object?>.from(item));
          })
          .toList(growable: false);
      return _sorted(presets);
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(SchemaPreset preset) async {
    final presets = await load();
    final updated = [
      ...presets.where((existing) => existing.schema.id != preset.schema.id),
      preset,
    ];
    await _write(_sorted(updated));
  }

  Future<void> delete(String schemaId) async {
    final presets = await load();
    await _write(
      presets
          .where((preset) => preset.schema.id != schemaId)
          .toList(growable: false),
    );
  }

  Future<void> _write(List<SchemaPreset> presets) => store.setString(
    storageKey,
    jsonEncode(
      presets.map((preset) => preset.toJson()).toList(growable: false),
    ),
  );
}

List<SchemaPreset> _sorted(Iterable<SchemaPreset> presets) {
  final sorted = presets.toList(growable: false);
  sorted.sort((left, right) => left.schema.name.compareTo(right.schema.name));
  return sorted;
}
