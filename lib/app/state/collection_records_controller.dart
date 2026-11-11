import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_database/shared_database.dart';

/// Watches one collection and exposes record rows for the records screen.
class CollectionRecordsController extends ChangeNotifier {
  CollectionRecordsController(
    this.collectionName, {
    SharedDatabase? db,
  }) : _db = db ?? SharedDatabase.instance {
    _subscribe();
  }

  final SharedDatabase _db;
  String collectionName;
  List<SharedRecord> records = [];
  bool initialLoading = true;
  String? watchError;

  StreamSubscription<List<SharedRecord>>? _watch;

  void _subscribe() {
    _watch?.cancel();
    initialLoading = records.isEmpty;
    watchError = null;
    _watch = _db
        .watchCollection(collectionName)
        .listen(_onRecords, onError: _onWatchError);
  }

  void _onRecords(List<SharedRecord> rows) {
    records = rows;
    initialLoading = false;
    watchError = null;
    notifyListeners();
  }

  void _onWatchError(Object error) {
    initialLoading = false;
    watchError = error.toString();
    notifyListeners();
  }

  void renameCollection(String name) {
    if (name == collectionName) return;
    collectionName = name;
    records = [];
    initialLoading = true;
    _subscribe();
    notifyListeners();
  }

  @override
  void dispose() {
    _watch?.cancel();
    super.dispose();
  }
}
