part of 'shared_database.dart';

int _tokenFingerprint(Map<dynamic, dynamic>? token) {
  if (token == null) return 0;
  final count = token['count'];
  final fingerprint = token['fingerprint'];
  final maxUpdatedAt = token['maxUpdatedAt'];
  final exists = token['exists'];
  final updatedAt = token['updatedAt'];
  return Object.hash(count, fingerprint, maxUpdatedAt, exists, updatedAt);
}

/// One poll loop per [multiplexKey]; fans out to many stream listeners.
final _watchRegistry = _SharedWatchRegistry();

class _SharedWatchRegistry {
  final _entries = <String, _SharedWatchEntry<dynamic>>{};

  Stream<T> stream<T>({
    required String multiplexKey,
    required Duration interval,
    required Future<bool> Function() shouldFetch,
    required Future<T> Function() fetch,
    required bool Function(T? previous, T next) hasChanged,
  }) {
    late final StreamController<T> controller;
    controller = StreamController<T>(
      onListen: () {
        var entry = _entries[multiplexKey] as _SharedWatchEntry<T>?;
        entry ??= _SharedWatchEntry<T>(
          interval: interval,
          shouldFetch: shouldFetch,
          fetch: fetch,
          hasChanged: hasChanged,
        );
        _entries[multiplexKey] = entry;
        entry.addListener(controller);
      },
      onCancel: () {
        final entry = _entries[multiplexKey] as _SharedWatchEntry<T>?;
        entry?.removeListener(controller);
        if (entry != null && entry.isEmpty) {
          entry.dispose();
          _entries.remove(multiplexKey);
        }
      },
    );
    return controller.stream;
  }
}

class _SharedWatchEntry<T> {
  _SharedWatchEntry({
    required this.interval,
    required this.shouldFetch,
    required this.fetch,
    required this.hasChanged,
  });

  final Duration interval;
  final Future<bool> Function() shouldFetch;
  final Future<T> Function() fetch;
  final bool Function(T? previous, T next) hasChanged;

  final _listeners = <StreamController<T>>[];
  Timer? _timer;
  T? _snapshot;
  var _inFlight = false;

  bool get isEmpty => _listeners.isEmpty;

  void addListener(StreamController<T> listener) {
    final wasEmpty = _listeners.isEmpty;
    _listeners.add(listener);
    if (wasEmpty) {
      _kick();
      _timer = Timer.periodic(interval, (_) => _kick());
    } else if (_snapshot != null) {
      listener.add(_snapshot as T);
    }
  }

  void removeListener(StreamController<T> listener) {
    _listeners.remove(listener);
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _kick() async {
    if (_inFlight || _listeners.isEmpty) return;
    _inFlight = true;
    try {
      final needsData = await shouldFetch();
      if (!needsData && _snapshot != null) return;

      final next = await fetch();
      if (!hasChanged(_snapshot, next)) return;
      _snapshot = next;

      final stale = <StreamController<T>>[];
      for (final c in _listeners) {
        if (c.isClosed) {
          stale.add(c);
        } else {
          c.add(next);
        }
      }
      for (final c in stale) {
        _listeners.remove(c);
      }
    } catch (e, st) {
      for (final c in List<StreamController<T>>.from(_listeners)) {
        if (!c.isClosed) c.addError(e, st);
      }
    } finally {
      _inFlight = false;
    }
  }
}

Stream<T> _sharedDatabasePollingStream<T>({
  required String multiplexKey,
  required Future<bool> Function() shouldFetch,
  required Future<T> Function() fetch,
  required bool Function(T? previous, T next) hasChanged,
  Duration interval = SharedDatabase.defaultWatchInterval,
}) {
  return _watchRegistry.stream<T>(
    multiplexKey: multiplexKey,
    interval: interval,
    shouldFetch: shouldFetch,
    fetch: fetch,
    hasChanged: hasChanged,
  );
}

bool _sharedRecordsChanged(List<SharedRecord>? a, List<SharedRecord> b) {
  if (a == null || a.length != b.length) return true;
  for (var i = 0; i < a.length; i++) {
    if (a[i].id != b[i].id) return true;
    final prev = a[i].data;
    final next = b[i].data;
    if (identical(prev, next)) continue;
    if (prev.length != next.length) return true;
    for (final key in prev.keys) {
      if (!next.containsKey(key) || next[key] != prev[key]) return true;
    }
  }
  return false;
}

bool _stringListChanged(List<String>? a, List<String> b) {
  if (a == null || a.length != b.length) return true;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return true;
  }
  return false;
}

bool _recordChanged(SharedRecord? a, SharedRecord? b) {
  if (a == null && b == null) return false;
  if (a == null || b == null) return true;
  if (a.id != b.id) return true;
  final prev = a.data;
  final next = b.data;
  if (identical(prev, next)) return false;
  if (prev.length != next.length) return true;
  for (final key in prev.keys) {
    if (!next.containsKey(key) || next[key] != prev[key]) return true;
  }
  return false;
}
