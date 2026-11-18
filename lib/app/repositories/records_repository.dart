import 'dart:async';

import 'package:shared_database/shared_database.dart';

import 'database_repository.dart';

/// Live watch + CRUD for one collection (scoped per [RecordsScope]).
class RecordsRepository {
  RecordsRepository(this.collectionName, {DatabaseRepository? db})
      : _db = db ?? DatabaseRepository();

  final String collectionName;
  final DatabaseRepository _db;

  StreamSubscription<List<SharedRecord>>? _subscription;

  void watch(
    void Function(List<SharedRecord>) onData,
    void Function(Object) onError,
  ) {
    cancelWatch();
    _subscription = _db
        .watchCollection(collectionName)
        .listen(onData, onError: onError);
  }

  void cancelWatch() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<void> removeById(String id) =>
      _db.removeById(collectionName, id);

  DatabaseRepository get database => _db;
}