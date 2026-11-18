import 'dart:convert';

import 'package:shared_database/shared_database.dart';

/// Preference keys used by the Database app itself (dogfooding the API).
abstract final class AppPrefs {
  static const themeMode = 'dbui.theme_mode'; // system | light | dark
  static const accentSeed = 'dbui.accent_seed'; // #RRGGBB
  static const watchIntervalMs = 'dbui.watch_interval_ms';

  static String pinsFor(String collection) => 'dbui.pins.$collection';
  static String tagsFor(String collection) => 'dbui.tags.$collection';
}

/// Reads a JSON string list preference; empty on any failure.
Future<Set<String>> readStringSetPref(
  SharedDatabase db,
  String key,
) async {
  try {
    final raw = await db.getPreference(key);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! List) return {};
    return decoded.whereType<String>().toSet();
  } catch (_) {
    return {};
  }
}

Future<void> writeStringSetPref(
  SharedDatabase db,
  String key,
  Set<String> values,
) async {
  await db.setPreference(key, jsonEncode(values.toList()..sort()));
}
