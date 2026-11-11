import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_database/shared_database.dart';

/// Host home: apps that have data in the shared database.
class HostConsoleController extends ChangeNotifier with WidgetsBindingObserver {
  HostConsoleController({SharedDatabase? db})
      : _db = db ?? SharedDatabase.instance;

  final SharedDatabase _db;
  Timer? _poll;

  DatabaseOverview? overview;
  List<AppDataInfo> apps = [];
  String? error;
  bool initialLoading = true;

  bool get hasData => overview != null;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    reload(showSpinner: true);
    _poll = Timer.periodic(SharedDatabase.defaultWatchInterval, (_) {
      reload();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) reload();
  }

  Future<void> reload({bool showSpinner = false}) async {
    if (showSpinner) {
      initialLoading = true;
      error = null;
      notifyListeners();
    }
    try {
      final results = await Future.wait<Object>([
        _db.overview(),
        _db.appsDetailed(),
      ]);
      overview = results[0] as DatabaseOverview;
      apps = results[1] as List<AppDataInfo>;
      initialLoading = false;
      error = null;
      notifyListeners();
    } catch (e) {
      error = e.toString();
      initialLoading = false;
      notifyListeners();
    }
  }

  void notifyDataChanged() => reload();
}
