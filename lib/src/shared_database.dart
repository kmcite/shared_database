import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import 'pigeon/shared_database_api.g.dart';
import 'shared_database_admin.dart';
import 'shared_database_exception.dart';
part 'shared_database_watch.dart';

/// Single API for the on-device shared SQLite database (Android & Windows).
class SharedDatabase {
  SharedDatabase._();

  static final SharedDatabase instance = SharedDatabase._();

  static final SharedDatabaseApi _api = SharedDatabaseApi();
  static const _uuid = Uuid();

  static bool _initialized = false;

  /// Writes stay serialized; reads may run concurrently (WAL-safe).
  static Future<void> _writeChain = Future<void>.value();

  static Future<T?> _invokeWrite<T>(Future<T?> Function() call) {
    final completer = Completer<T?>();
    _writeChain = _writeChain.then((_) async {
      try {
        completer.complete(await call());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Object? _collectionsWatchToken;
  final Map<String, Object?> _collectionWatchToken = {};
  final Map<String, Object?> _recordWatchToken = {};
  final Map<String, Object?> _preferenceWatchToken = {};

  /// Default polling interval for [watchCollection], [watchRecord], etc.
  static const defaultWatchInterval = Duration(seconds: 2);

  // — Setup —

  /// Connects to the shared database. Every API method works for every app —
  /// on Android every app opens the same file under public Documents; on Windows
  /// it uses the shared file under ProgramData.
  ///
  /// Throws [SharedDatabaseException] when the native plugin is not linked.
  static Future<SharedDatabase> open() async {
    await _initialize();
    return instance;
  }

  /// @Deprecated Use [open]. Kept for source compatibility.
  @Deprecated('Use SharedDatabase.open() — there is no host/client split.')
  static Future<SharedDatabase> openHost() => open();

  static Future<void> _initialize() async {
    try {
      await _invokeWrite<void>(() => _api.initialize());
    } on MissingPluginException catch (e) {
      throw SharedDatabaseException(
        'Native plugin not linked (pigeon channel '
        'dev.flutter.pigeon.shared_database.SharedDatabaseApi). '
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
        'Call SharedDatabase.open() first.',
      );
    }
  }

  // — Collections —

  Future<void> ensureCollection(String name) async {
    _checkInitialized();
    await _invokeWrite<void>(() => _api.ensureCollection(name));
  }

  /// Rename a collection and move its records.
  Future<void> renameCollection(String from, String to) async {
    _checkInitialized();
    await _invokeWrite<void>(
      () => _api.renameCollection(from: from, to: to),
    );
    _collectionsWatchToken = null;
    _collectionWatchToken.remove(from);
    _collectionWatchToken.remove(to);
  }

  /// Delete a collection and all of its records.
  Future<void> removeCollection(String name) async {
    _checkInitialized();
    await _invokeWrite<void>(() => _api.removeCollection(name));
    _invalidateWatchTokens(collection: name);
    _collectionsWatchToken = null;
  }

  // — Records —

  /// Upserts a record (creates or updates when [id] already exists).
  /// Returns the record id — auto-generated when [id] is omitted.
  Future<String> put(
    String collection,
    Map<String, dynamic> data, {
    String? id,
  }) async {
    _checkInitialized();
    final recordId = id ?? _uuid.v4();
    await _invokeWrite<String>(
      () => _api.put(
        collection: collection,
        id: recordId,
        dataJson: jsonEncode(data),
      ),
    );
    _invalidateWatchTokens(collection: collection, recordId: recordId);
    return recordId;
  }

  /// Batch upserts multiple records in a single native transaction.
  /// Returns the record ids in the same order — auto-generated when a
  /// record's `id` is null.
  Future<List<String>> putMany(
    String collection,
    List<({String? id, Map<String, dynamic> data})> records,
  ) async {
    _checkInitialized();
    final requests = records
        .map(
          (r) => RecordPutRequest(
            id: r.id ?? _uuid.v4(),
            dataJson: jsonEncode(r.data),
          ),
        )
        .toList();
    final ids = (await _invokeWrite<List<String>>(
          () => _api.putMany(collection: collection, records: requests),
        )) ??
        const <String>[];
    _invalidateWatchTokens(collection: collection);
    return ids;
  }

  /// Partially updates an existing record: top-level keys of [data] are
  /// merged into the stored JSON (patch values win). Returns the record id.
  Future<String> patch(
    String collection,
    String id,
    Map<String, dynamic> data,
  ) async {
    _checkInitialized();
    await _invokeWrite<String>(
      () => _api.patch(
        collection: collection,
        id: id,
        dataJson: jsonEncode(data),
      ),
    );
    _invalidateWatchTokens(collection: collection, recordId: id);
    return id;
  }

  Future<void> removeById(String collection, String id) async {
    _checkInitialized();
    await _invokeWrite<void>(() => _api.removeById(collection, id));
    _invalidateWatchTokens(collection: collection, recordId: id);
  }

  /// Removes every record in [collection]; the collection itself is kept.
  Future<void> removeAll(String collection) async {
    _checkInitialized();
    await _invokeWrite<void>(() => _api.removeAll(collection));
    _invalidateWatchTokens(collection: collection);
  }

  // — Preferences —

  /// Returns the stored value for [key], or null when unset.
  Future<String?> getPreference(String key) async {
    _checkInitialized();
    return _api.getPreferenceValue(key);
  }

  Future<void> setPreference(String key, String value) async {
    _checkInitialized();
    await _invokeWrite<void>(
      () => _api.setPreferenceValue(key: key, value: value),
    );
    _preferenceWatchToken.remove(key);
  }

  Future<void> removePreference(String key) async {
    _checkInitialized();
    await _invokeWrite<void>(() => _api.removePreference(key));
    _preferenceWatchToken.remove(key);
  }

  /// All preference keys currently stored.
  Future<List<String>> getPreferenceKeys() async {
    _checkInitialized();
    return _api.getPreferences();
  }

  // — Reads —

  Future<List<String>> listCollections() async {
    _checkInitialized();
    return _api.getCollections();
  }

  Future<List<SharedRecord>> getAll(
    String collection, {
    int? limit,
    int? offset,
  }) async {
    _checkInitialized();
    return (await _api.getAll(
      collection: collection,
      limit: limit,
      offset: offset,
    ))
        .map(_recordFromDto)
        .toList();
  }

  Future<SharedRecord?> getById(String collection, String id) async {
    _checkInitialized();
    final dto = await _api.getById(collection, id);
    return dto == null ? null : _recordFromDto(dto);
  }

  // — Watch (async polling) —

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

  /// Emits the current value, then re-emits whenever it changes.
  Stream<String?> watchPreference(
    String key, {
    Duration interval = defaultWatchInterval,
  }) {
    _checkInitialized();
    return _sharedDatabasePollingStream<String?>(
      multiplexKey: 'preference::$key',
      interval: interval,
      shouldFetch: () => _preferenceWatchShouldFetch(key),
      fetch: () => getPreference(key),
      hasChanged: _nullableStringChanged,
    );
  }

  // — Collections detail (console UI) —

  Future<List<CollectionInfo>> collectionsDetailed() async {
    _checkInitialized();
    final dtos = await _api.getCollectionsDetailed();
    return dtos.map(_collectionInfoFromDto).toList();
  }

  // — Watch tokens —

  Future<bool> _collectionsWatchShouldFetch() async {
    try {
      final token = await _api.getCollectionsWatchToken();
      if (token.forceRefresh) return true;
      if (_collectionsWatchToken == token) return false;
      _collectionsWatchToken = token;
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
      final token = await _api.getCollectionWatchToken(collection);
      if (token.forceRefresh) return true;
      final prev = _collectionWatchToken[collection];
      if (prev == token) return false;
      _collectionWatchToken[collection] = token;
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
      final token = await _api.getRecordWatchToken(collection, id);
      if (token.forceRefresh) return true;
      final key = _recordKey(collection, id);
      final prev = _recordWatchToken[key];
      if (prev == token) return false;
      _recordWatchToken[key] = token;
      return true;
    } on MissingPluginException {
      return true;
    } on PlatformException catch (e) {
      if (e.code == 'notImplemented') return true;
      rethrow;
    }
  }

  Future<bool> _preferenceWatchShouldFetch(String key) async {
    try {
      final token = await _api.getPreferenceWatchToken(key);
      if (token.forceRefresh) return true;
      final prev = _preferenceWatchToken[key];
      if (prev == token) return false;
      _preferenceWatchToken[key] = token;
      return true;
    } on MissingPluginException {
      return true;
    } on PlatformException catch (e) {
      if (e.code == 'notImplemented') return true;
      rethrow;
    }
  }

  void _invalidateWatchTokens({String? collection, String? recordId}) {
    _collectionsWatchToken = null;
    if (collection != null) {
      _collectionWatchToken.remove(collection);
      if (recordId != null) {
        _recordWatchToken.remove(_recordKey(collection, recordId));
      }
    }
  }

  static String _recordKey(String collection, String id) => '$collection::$id';

  SharedRecord _recordFromDto(RecordData dto) {
    final map = jsonDecode(dto.dataJson) as Map<String, dynamic>;
    return SharedRecord(
      id: dto.id,
      data: map,
      createdAt: dto.createdAt,
      updatedAt: dto.updatedAt,
      createdBy: dto.createdBy,
      updatedBy: dto.updatedBy,
    );
  }

  CollectionInfo _collectionInfoFromDto(CollectionData dto) {
    return CollectionInfo(
      name: dto.name,
      createdAt: dto.createdAt,
      createdByPackage: dto.createdByPackage,
      recordCount: dto.recordCount,
    );
  }
}

/// One JSON document in a collection.
class SharedRecord {
  const SharedRecord({
    required this.id,
    required this.data,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  final String id;
  final Map<String, dynamic> data;
  final int? createdAt;
  final int? updatedAt;
  final String? createdBy;
  final String? updatedBy;
}
