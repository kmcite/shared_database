import 'dart:async';

import 'package:shared_database/shared_database.dart';

import 'collections_repository.dart';
import 'database_repository.dart';
import 'preferences_repository.dart';

/// Live watch + CRUD for one collection (scoped per [RecordsScope]).
class RecordsRepository {
  RecordsRepository(this.collectionName, {DatabaseRepository? database}) {
    final root = database ?? DatabaseRepository();
    _collections = root.collections;
    preferences = root.preferences;
  }

  final String collectionName;
  late final CollectionsRepository _collections;
  late final PreferencesRepository preferences;

  StreamSubscription<List<SharedRecord>>? _subscription;

  void watch(
    void Function(List<SharedRecord>) onData,
    void Function(Object) onError,
  ) {
    cancelWatch();
    _subscription = _collections
        .watch(collectionName)
        .listen(onData, onError: onError);
  }

  void cancelWatch() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<void> removeById(String id) =>
      _collections.removeRecordById(collectionName, id);

  Future<String> put(Map<String, dynamic> data, {String? id}) =>
      _collections.putRecord(collectionName, data, id: id);
}