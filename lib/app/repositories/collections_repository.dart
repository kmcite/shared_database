import 'package:shared_database/shared_database.dart';

/// Collection metadata and per-collection record I/O.
class CollectionsRepository {
  CollectionsRepository(this._db);

  final SharedDatabase _db;

  Future<List<CollectionInfo>> listDetailed() => _db.collectionsDetailed();

  Future<void> ensure(String name) => _db.ensureCollection(name);

  Future<void> rename(String from, String to) => _db.renameCollection(from, to);

  Future<void> remove(String name) => _db.removeCollection(name);

  Future<void> clearRecords(String name) => _db.removeAll(name);

  Stream<List<SharedRecord>> watch(String name) => _db.watchCollection(name);

  Future<List<SharedRecord>> getAllRecords(String name) => _db.getAll(name);

  Future<String> putRecord(
    String collection,
    Map<String, dynamic> data, {
    String? id,
  }) =>
      _db.put(collection, data, id: id);

  Future<void> putMany(
    String collection,
    List<({String? id, Map<String, dynamic> data})> batch,
  ) =>
      _db.putMany(collection, batch);

  Future<void> removeRecordById(String collection, String id) =>
      _db.removeById(collection, id);
}