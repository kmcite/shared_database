String formatEpochMillis(int millis) {
  final dt = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
  return '${dt.year}-${_two(dt.month)}-${_two(dt.day)} '
      '${_two(dt.hour)}:${_two(dt.minute)}:${_two(dt.second)}';
}

/// Short relative label for overview timelines.
String formatRelativeEpoch(int millis) {
  final dt = DateTime.fromMillisecondsSinceEpoch(millis);
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return formatEpochMillis(millis).split(' ').first;
}

String _two(int n) => n.toString().padLeft(2, '0');
