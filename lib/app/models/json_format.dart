import 'dart:convert';

String formatJsonMap(Map<String, dynamic> data) {
  return const JsonEncoder.withIndent('  ').convert(data);
}

String formatJsonValue(Object? value) {
  return const JsonEncoder.withIndent('  ').convert(value);
}

Map<String, dynamic>? parseJsonObject(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final decoded = jsonDecode(trimmed);
  if (decoded is! Map<String, dynamic>) return null;
  return decoded;
}

/// Parses any JSON value (object, array, scalar).
Object? parseJsonValue(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  try {
    return jsonDecode(trimmed);
  } on FormatException {
    return null;
  }
}

/// Short one-line preview of a JSON value for tables/lists.
String summarizeValue(Object? value, {int maxLen = 80}) {
  final String raw;
  if (value == null) {
    raw = 'null';
  } else if (value is String) {
    raw = value;
  } else if (value is num || value is bool) {
    raw = '$value';
  } else if (value is Map) {
    raw = '{${value.length} keys}';
  } else if (value is List) {
    raw = '[${value.length} items]';
  } else {
    raw = '$value';
  }
  return raw.length <= maxLen ? raw : '${raw.substring(0, maxLen - 1)}…';
}

/// JSON-encodes [value]; returns null when it cannot be encoded.
String? tryEncodeJson(Object? value) {
  try {
    return jsonEncode(value);
  } catch (_) {
    return null;
  }
}

/// Recursively collects every scalar string/number leaf into [out]
/// (used by global search).
void collectSearchableText(Object? value, void Function(String text) out) {
  if (value == null) return;
  if (value is String) {
    out(value);
  } else if (value is num || value is bool) {
    out('$value');
  } else if (value is Map) {
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is String) out(key);
      collectSearchableText(entry.value, out);
    }
  } else if (value is List) {
    for (final item in value) {
      collectSearchableText(item, out);
    }
  }
}

/// Returns a new map with [patch] merged at the top level only.
Map<String, dynamic> shallowMerge(
  Map<String, dynamic> base,
  Map<String, dynamic> patch,
) {
  return {...base, ...patch};
}