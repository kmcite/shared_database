String packageLabel(String packageName) {
  if (packageName.isEmpty) return 'Unknown app';
  final parts = packageName.split(RegExp(r'[.\\/]'));
  if (parts.length >= 2) {
    return '${parts[parts.length - 2]}.${parts.last}';
  }
  return packageName;
}

String packageInitial(String packageName) {
  final label = packageLabel(packageName);
  return label.isEmpty ? '?' : label[0].toUpperCase();
}