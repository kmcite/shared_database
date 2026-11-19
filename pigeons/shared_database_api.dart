import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/pigeon/shared_database_api.g.dart',
    kotlinOut:
        'shared_database_android/android/src/main/kotlin/dev/loner/shared_database/SharedDatabaseApi.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'dev.loner.shared_database',
    ),
    cppHeaderOut:
        'shared_database_windows/windows/shared_database_api.g.h',
    cppSourceOut:
        'shared_database_windows/windows/shared_database_api.g.cpp',
    cppOptions: CppOptions(
      namespace: 'shared_database_windows_pigeon',
    ),
  ),
)
@HostApi()
abstract class SharedDatabaseApi {
  /// Android: runtime storage / all-files access for the shared Documents path.
  /// Windows: no-op (always true).
  @async
  bool prepareStorageAccess();

  void initialize();

  // — Collections (Console UI & Setup) —

  void ensureCollection(String name);

  List<String> getCollections();

  void renameCollection({required String from, required String to});

  void removeCollection(String name);

  List<CollectionData> getCollectionsDetailed();

  // — Records (Put, Get, All, Remove on a Specific Collection) —

  /// Upserts a record (creates or updates if ID exists). Returns record id.
  String put({
    required String collection,
    String? id,
    required String dataJson,
  });

  /// Batch upserts multiple records in a single transaction.
  List<String> putMany({
    required String collection,
    required List<RecordPutRequest> records,
  });

  /// Partially updates an existing record's JSON data.
  String patch({
    required String collection,
    required String id,
    required String dataJson,
  });

  RecordData? getById(String collection, String id);

  /// Retrieves records for a collection with optional pagination.
  List<RecordData> getAll({
    required String collection,
    int? limit,
    int? offset,
  });

  void removeById(String collection, String id);

  /// Clears all records in [collection] without deleting the collection itself.
  void removeAll(String collection);

  // — Preferences Store —

  String? getPreferenceValue(String key);

  void setPreferenceValue({required String key, required String value});

  void removePreference(String key);

  List<String> getPreferences();

  // — Watch Tokens (Polling & Reactive Streams) —

  CollectionsWatchToken getCollectionsWatchToken();

  CollectionWatchToken getCollectionWatchToken(String collection);

  RecordWatchToken getRecordWatchToken(String collection, String id);

  PreferenceWatchToken getPreferenceWatchToken(String key);
}

class RecordPutRequest {
  RecordPutRequest({
    required this.id,
    required this.dataJson,
  });

  String? id;
  String dataJson;
}

class RecordData {
  RecordData({
    required this.id,
    required this.collection,
    required this.dataJson,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
  });

  String id;
  String collection;
  String dataJson;
  int createdAt;
  int updatedAt;
  String createdBy;
  String updatedBy;
}

class CollectionData {
  CollectionData({
    required this.name,
    required this.createdAt,
    required this.createdByPackage,
    required this.recordCount,
  });

  String name;
  int createdAt;
  String createdByPackage;
  int recordCount;
}

class CollectionsWatchToken {
  CollectionsWatchToken({
    required this.count,
    required this.fingerprint,
    required this.forceRefresh,
  });

  int count;
  int fingerprint;
  bool forceRefresh;
}

class CollectionWatchToken {
  CollectionWatchToken({
    required this.count,
    required this.maxUpdatedAt,
    required this.forceRefresh,
  });

  int count;
  int maxUpdatedAt;
  bool forceRefresh;
}

class RecordWatchToken {
  RecordWatchToken({
    required this.exists,
    required this.updatedAt,
    required this.forceRefresh,
  });

  bool exists;
  int? updatedAt;
  bool forceRefresh;
}

class PreferenceWatchToken {
  PreferenceWatchToken({
    required this.exists,
    required this.updatedAt,
    required this.forceRefresh,
  });

  bool exists;
  int? updatedAt;
  bool forceRefresh;
}
