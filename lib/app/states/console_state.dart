import 'package:shared_database/shared_database.dart';

/// Overview of collections, apps, and preference counts — mutated by commands.
class ConsoleState {
  List<CollectionInfo> collections = [];
  List<AppDataInfo> apps = [];
  int preferenceCount = 0;
  String? error;
  bool loading = true;
  bool hasData = false;

  int get collectionCount => collections.length;

  int get recordCount =>
      collections.fold(0, (sum, c) => sum + c.recordCount);

  List<CollectionInfo> get recentCollections {
    final sorted = [...collections]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(8).toList();
  }

  CollectionInfo? collectionByName(String name) {
    for (final c in collections) {
      if (c.name == name) return c;
    }
    return null;
  }
}