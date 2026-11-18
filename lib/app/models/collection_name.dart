String? validateCollectionName(String? raw) {
  final name = raw?.trim() ?? '';
  if (name.isEmpty) return 'Name is required';
  if (name.length > 64) return 'Name is too long';
  if (name.contains('/') || name.contains(' ')) {
    return 'Use letters, numbers, and underscores only';
  }
  return null;
}