import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import 'shared_database_admin.dart';
import 'shared_database_config.dart';
import 'shared_database_exception.dart';
part 'shared_database_watch.dart';

/// Single API for the on-device shared SQLite database (Android & Windows).
class SharedDatabase {
  SharedDatabase._();

  static final SharedDatabase instance = SharedDatabase._();

  static const _channel = MethodChannel('shared_database');
  static const _uuid = Uuid();

  static bool _initialized = false;

  /// Writes stay serialized; reads may run concurrently (WAL-safe).
  static Future<void> _writeChain = Future<void>.value();

  static Future<T?> _invokeRead<T>(String method, [Object? arguments]) {
    return _channel.invokeMethod<T>(method, arguments);
  }

  static Future<T?> _invokeWrite<T>(String method, [Object? arguments]) {
    final completer = Completer<T?>();
    _writeChain = _writeChain.then((_) async {
      try {
        completer.complete(
          await _channel.invokeMethod<T>(method, arguments),
        );
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  int? _collectionsWatchSig;
  final Map<String, int> _collectionWatchSig = {};
  final Map<String, int> _recordWatchSig = {};

  final Map<String, List<SharedRecord>> _collectionCache = {};
  final Map<String, SharedRecord?> _recordCache = {};
  List<String>? _collectionsListCache;

  /// Default polling interval for [watchCollection], [watchRecord], etc.
  static const defaultWatchInterval = Duration(seconds: 2);

  // — Setup —

  /// Client apps: open connection to the installed Database host.
  static Future<SharedDatabase> open() async {
    await initialize(SharedDatabaseConfig.client());
    return instance;
  }

  /// This Database host APK only.
  static Future<SharedDatabase> openHost() async {
    await initialize(SharedDatabaseConfig.host());
    return instance;
  }

  /// Alias for [open].
  static Future<void> attach() => open();

  static Future<void> attachAndVerify() async {
    await open();
    try {
      await instance.listCollections();
    } on PlatformException catch (e) {
      throw SharedDatabaseException(
        'Cannot reach the shared database host. Install or run the Database app '
        '(${SharedDatabaseConfig.hostApplicationId}) on this device first.',
        cause: e,
      );
    }
  }

  static Future<void> initialize(SharedDatabaseConfig config) async {
    try {
      await _invokeWrite<void>('initialize', {
        'isHost': config.isHost,
        'authority': config.authority,
      });
    } on MissingPluginException catch (e) {
      throw SharedDatabaseException(
        'Native plugin not linked (channel shared_database). '
        'Add shared_database to pubspec, run flutter pub get, then rebuild '
        'for your platform (apk / windows).',
        cause: e,
      );
    }
    _initialized = true;
  }

  void _checkInitialized() {
    if (!_initialized) {
      throw StateError(
        'Call SharedDatabase.open() or SharedDatabase.openHost() first.',
      );
    }
  }

  // — Async writes —

  Future<void> ensure(String collection) => ensureCollection(collection);

  Future<void> ensureCollection(String name) async {
    _checkInitialized();
    await _invokeWrite<void>('ensureCollection', {'name': name});
  }

  Future<String> put(
    String collection,
    Map<String, dynamic> data, {
    String? id,
  }) async {
    _checkInitialized();
    if (id == null) {
      return create(collection, data);
    }
    final encoded = jsonEncode(data);
    await _invokeWrite<void>('insert', {
      'collection': collection,
      'id': id,
      'data': encoded,
      'upsert': true,
    });
    final record = SharedRecord(id: id, data: data);
    _recordCache[_recordKey(collection, id)] = record;
    final list = List<SharedRecord>.from(_collectionCache[collection] ?? []);
    final idx = list.indexWhere((r) => r.id == id);
    if (idx >= 0) {
      list[idx] = record;
    } else {
      list.add(record);
    }
    _collectionCache[collection] = list;
    _invalidateWatchTokens(collection: collection, recordId: id);
    return id;
  }

  Future<String> create(
    String collection,
    Map<String, dynamic> data, {
    String? id,
  }) async {
    _checkInitialized();
    final recordId = id ?? _uuid.v4();
    await _invokeWrite<String>('insert', {
      'collection': collection,
      'id': recordId,
      'data': jsonEncode(data),
    });
    final record = SharedRecord(id: recordId, data: data);
    _recordCache[_recordKey(collection, recordId)] = record;
    final list = List<SharedRecord>.from(_collectionCache[collection] ?? []);
    final idx = list.indexWhere((r) => r.id == recordId);
    if (idx >= 0) {
      list[idx] = record;
    } else {
      list.add(record);
    }
    _collectionCache[collection] = list;
    _invalidateWatchTokens(collection: collection, recordId: recordId);
    return recordId;
  }

  Future<void> patch(
    String collection,
    String id,
    Map<String, dynamic> data,
  ) =>
      update(collection, id, data);

  Future<void> update(
    String collection,
    String id,
    Map<String, dynamic> data,
  ) async {
    _checkInitialized();
    await _invokeWrite<void>('update', {
      'collection': collection,
      'id': id,
      'data': jsonEncode(data),
    });
    final record = SharedRecord(id: id, data: data);
    _recordCache[_recordKey(collection, id)] = record;
    final list = _collectionCache[collection];
    if (list != null) {
      final idx = list.indexWhere((r) => r.id == id);
      if (idx >= 0) list[idx] = record;
    }
    _invalidateWatchTokens(collection: collection, recordId: id);
  }

  Future<void> drop(String collection, String id) => delete(collection, id);

  Future<void> delete(String collection, String id) async {
    _checkInitialized();
    await _invokeWrite<void>('delete', {
      'collection': collection,
      'id': id,
    });
    _recordCache.remove(_recordKey(collection, id));
    _collectionCache[collection]?.removeWhere((r) => r.id == id);
    _invalidateWatchTokens(collection: collection, recordId: id);
  }

  // — Async reads —

  Future<List<String>> listCollections() async {
    _checkInitialized();
    final list =
        await _invokeRead<List<dynamic>>('listCollections');
    final names = list?.cast<String>() ?? [];
    _collectionsListCache = names;
    return names;
  }

  Future<List<SharedRecord>> all(String collection) => getAll(collection);

  Future<List<SharedRecord>> getAll(String collection) async {
    _checkInitialized();
    final raw = await _invokeRead<List<dynamic>>('getAll', {
      'collection': collection,
    });
    if (raw == null) {
      _collectionCache[collection] = [];
      return [];
    }
    final records =
        raw.cast<Map<dynamic, dynamic>>().map(_parseRecord).toList();
    _cacheCollection(collection, records);
    return records;
  }

  Future<SharedRecord?> get(String collection, String id) =>
      getById(collection, id);

  Future<SharedRecord?> getById(String collection, String id) async {
    _checkInitialized();
    final raw = await _invokeRead<Map<dynamic, dynamic>>('getById', {
      'collection': collection,
      'id': id,
    });
    if (raw == null) {
      _recordCache[_recordKey(collection, id)] = null;
      return null;
    }
    final record = _parseRecord(raw);
    _recordCache[_recordKey(collection, id)] = record;
    return record;
  }

  // — Sync reads (in-memory cache, updated by async calls & watches) —

  List<SharedRecord> allSync(String collection) {
    _checkInitialized();
    final cached = _collectionCache[collection];
    if (cached == null) {
      throw StateError(
        'No cached data for "$collection". Call await getAll("$collection") '
        'first, or subscribe to watchCollection("$collection").',
      );
    }
    return List<SharedRecord>.unmodifiable(cached);
  }

  SharedRecord? getSync(String collection, String id) {
    _checkInitialized();
    final key = _recordKey(collection, id);
    if (_recordCache.containsKey(key)) {
      return _recordCache[key];
    }
    if (_collectionCache.containsKey(collection)) {
      for (final r in _collectionCache[collection]!) {
        if (r.id == id) return r;
      }
      return null;
    }
    throw StateError(
      'No cached record "$id" in "$collection". Call await get(...) '
      'or watchRecord(...) first.',
    );
  }

  List<String> listCollectionsSync() {
    _checkInitialized();
    final cached = _collectionsListCache;
    if (cached == null) {
      throw StateError(
        'Collection list not cached. Call await listCollections() '
        'or watchCollections() first.',
      );
    }
    return List<String>.unmodifiable(cached);
  }

  // — Watch (async polling; updates sync cache) —

  Stream<List<String>> watchCollections({
    Duration interval = defaultWatchInterval,
  }) {
    _checkInitialized();
    return _sharedDatabasePollingStream<List<String>>(
      multiplexKey: 'collections',
      interval: interval,
      shouldFetch: _collectionsWatchShouldFetch,
      fetch: listCollections,
      hasChanged: _stringListChanged,
    );
  }

  Stream<List<SharedRecord>> watchCollection(
    String collection, {
    Duration interval = defaultWatchInterval,
  }) {
    _checkInitialized();
    return _sharedDatabasePollingStream<List<SharedRecord>>(
      multiplexKey: 'collection::$collection',
      interval: interval,
      shouldFetch: () => _collectionWatchShouldFetch(collection),
      fetch: () => getAll(collection),
      hasChanged: _sharedRecordsChanged,
    );
  }

  Stream<SharedRecord?> watchRecord(
    String collection,
    String id, {
    Duration interval = defaultWatchInterval,
  }) {
    _checkInitialized();
    return _sharedDatabasePollingStream<SharedRecord?>(
      multiplexKey: 'record::$collection::$id',
      interval: interval,
      shouldFetch: () => _recordWatchShouldFetch(collection, id),
      fetch: () => getById(collection, id),
      hasChanged: _recordChanged,
    );
  }

  /// Watches a single id; emits only when that document exists (non-null).
  Stream<SharedRecord> watchRecordId(
    String collection,
    String id, {
    Duration interval = defaultWatchInterval,
  }) async* {
    await for (final record in watchRecord(collection, id, interval: interval)) {
      if (record != null) yield record;
    }
  }

  // — Host manager —

  Future<DatabaseOverview> overview() => getOverview();

  Future<DatabaseOverview> getOverview() async {
    _checkInitialized();
    final raw =
        await _invokeRead<Map<dynamic, dynamic>>('getOverview');
    if (raw == null) {
      throw StateError('getOverview returned no data');
    }
    return DatabaseOverview.fromMap(raw);
  }

  Future<List<CollectionInfo>> collectionsDetailed() =>
      listCollectionsDetailed();

  Future<List<CollectionInfo>> listCollectionsDetailed() async {
    _checkInitialized();
    final raw =
        await _invokeRead<List<dynamic>>('listCollectionsDetailed');
    if (raw == null) return [];
    return raw.cast<Map<dynamic, dynamic>>().map(CollectionInfo.fromMap).toList();
  }

  /// Host manager: apps that own collections or records, with those collections.
  Future<List<AppDataInfo>> appsDetailed() async {
    _checkInitialized();
    final raw = await _invokeRead<List<dynamic>>('listAppsDetailed');
    if (raw == null) return [];
    return raw.cast<Map<dynamic, dynamic>>().map(AppDataInfo.fromMap).toList();
  }

  /// Host manager: rename a collection and move its records.
  Future<void> renameCollection(String from, String to) async {
    _checkInitialized();
    await _invokeWrite<void>('renameCollection', {
      'from': from,
      'to': to,
    });
    final records = _collectionCache.remove(from);
    if (records != null) {
      _collectionCache[to] = records;
      for (final r in records) {
        _recordCache.remove(_recordKey(from, r.id));
        _recordCache[_recordKey(to, r.id)] = r;
      }
    }
    final names = _collectionsListCache;
    if (names != null) {
      final idx = names.indexOf(from);
      if (idx >= 0) {
        names[idx] = to;
      }
    }
    _collectionsWatchSig = null;
    _collectionWatchSig.remove(from);
    _collectionWatchSig.remove(to);
  }

  /// Host manager: delete a collection and all of its records.
  Future<void> deleteCollection(String name) async {
    _checkInitialized();
    await _invokeWrite<void>('deleteCollection', {'name': name});
    _collectionCache.remove(name);
    _collectionsListCache?.remove(name);
    _recordCache.removeWhere((key, _) => key.startsWith('$name::'));
    _invalidateWatchTokens(collection: name);
    _collectionsWatchSig = null;
  }

  Future<bool> _collectionsWatchShouldFetch() async {
    try {
      final token = await _invokeRead<Map<dynamic, dynamic>>(
        'getCollectionsWatchToken',
      );
      if (token == null || token['forceRefresh'] == true) return true;
      final sig = _tokenFingerprint(token);
      if (_collectionsWatchSig != null && _collectionsWatchSig == sig) {
        return false;
      }
      _collectionsWatchSig = sig;
      return true;
    } on MissingPluginException {
      return true;
    } on PlatformException catch (e) {
      if (e.code == 'notImplemented') return true;
      rethrow;
    }
  }

  Future<bool> _collectionWatchShouldFetch(String collection) async {
    try {
      final token = await _invokeRead<Map<dynamic, dynamic>>(
        'getCollectionWatchToken',
        {'collection': collection},
      );
      if (token == null || token['forceRefresh'] == true) return true;
      final sig = _tokenFingerprint(token);
      final prev = _collectionWatchSig[collection];
      if (prev != null && prev == sig) return false;
      _collectionWatchSig[collection] = sig;
      return true;
    } on MissingPluginException {
      return true;
    } on PlatformException catch (e) {
      if (e.code == 'notImplemented') return true;
      rethrow;
    }
  }

  Future<bool> _recordWatchShouldFetch(String collection, String id) async {
    try {
      final token = await _invokeRead<Map<dynamic, dynamic>>(
        'getRecordWatchToken',
        {'collection': collection, 'id': id},
      );
      if (token == null || token['forceRefresh'] == true) return true;
      final sig = _tokenFingerprint(token);
      final key = _recordKey(collection, id);
      final prev = _recordWatchSig[key];
      if (prev != null && prev == sig) return false;
      _recordWatchSig[key] = sig;
      return true;
    } on MissingPluginException {
      return true;
    } on PlatformException catch (e) {
      if (e.code == 'notImplemented') return true;
      rethrow;
    }
  }

  void _invalidateWatchTokens({String? collection, String? recordId}) {
    _collectionsWatchSig = null;
    if (collection != null) {
      _collectionWatchSig.remove(collection);
      if (recordId != null) {
        _recordWatchSig.remove(_recordKey(collection, recordId));
      }
    }
  }

  void _cacheCollection(String collection, List<SharedRecord> records) {
    _collectionCache[collection] = records;
    for (final r in records) {
      _recordCache[_recordKey(collection, r.id)] = r;
    }
  }

  static String _recordKey(String collection, String id) => '$collection::$id';

  SharedRecord _parseRecord(Map<dynamic, dynamic> row) {
    final id = row['id'] as String;
    final dataJson = row['data'] as String;
    final map = jsonDecode(dataJson) as Map<String, dynamic>;
    return SharedRecord(id: id, data: map);
  }
}

/// One JSON document in a collection.
class SharedRecord {
  const SharedRecord({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}
