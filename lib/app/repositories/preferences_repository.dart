import 'dart:convert';

import 'package:shared_database/shared_database.dart';

/// Global key/value preference store.
class PreferencesRepository {
  PreferencesRepository(this._db);

  final SharedDatabase _db;

  Future<List<String>> keys() => _db.getPreferenceKeys();

  Future<String?> get(String key) => _db.getPreference(key);

  Future<void> set(String key, String value) => _db.setPreference(key, value);

  Future<void> remove(String key) => _db.removePreference(key);

  Future<Map<String, String?>> readAll() async {
    final map = <String, String?>{};
    for (final key in await keys()) {
      map[key] = await get(key);
    }
    return map;
  }

  /// JSON-encoded string list (pins, etc.); empty on any failure.
  Future<Set<String>> readStringSet(String key) async {
    try {
      final raw = await get(key);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! List) return {};
      return decoded.whereType<String>().toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> writeStringSet(String key, Set<String> values) async {
    await set(key, jsonEncode(values.toList()..sort()));
  }
}