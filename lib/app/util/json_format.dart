import 'dart:convert';

String formatJsonMap(Map<String, dynamic> data) {
  return const JsonEncoder.withIndent('  ').convert(data);
}

Map<String, dynamic>? parseJsonObject(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final decoded = jsonDecode(trimmed);
  if (decoded is! Map<String, dynamic>) return null;
  return decoded;
}

String? validateCollectionName(String? raw) {
  final name = raw?.trim() ?? '';
  if (name.isEmpty) return 'Name is required';
  if (name.length > 64) return 'Name is too long';
  if (name.contains('/') || name.contains(' ')) {
    return 'Use letters, numbers, and underscores only';
  }
  return null;
}
