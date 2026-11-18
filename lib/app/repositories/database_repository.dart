import 'package:shared_database/shared_database.dart';

/// Shared DB access for commands and repositories.
class DatabaseRepository {
  DatabaseRepository({SharedDatabase? db}) : _db = db ?? SharedDatabase.instance;

  final SharedDatabase _db;

  SharedDatabase get db => _db;

  Future<List<CollectionInfo>> collectionsDetailed() => _db.collectionsDetailed();

  Future<List<String>> preferenceKeys() => _db.getPreferenceKeys();

  Future<String?> getPreference(String key) => _db.getPreference(key);

  Future<void> setPreference(String key, String value) =>
      _db.setPreference(key, value);

  Future<void> removePreference(String key) => _db.removePreference(key);

  Future<void> removeById(String collection, String id) =>
      _db.removeById(collection, id);

  Stream<List<SharedRecord>> watchCollection(String name) =>
      _db.watchCollection(name);
}