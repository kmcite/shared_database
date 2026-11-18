import 'package:shared_database/shared_database.dart';

/// Overview of collections, apps, and preference counts for the admin console.
class ConsoleState {
  const ConsoleState({
    this.collections = const [],
    this.apps = const [],
    this.preferenceCount = 0,
    this.error,
    this.loading = true,
    this.hasData = false,
  });

  final List<CollectionInfo> collections;
  final List<AppDataInfo> apps;
  final int preferenceCount;
  final String? error;
  final bool loading;
  final bool hasData;

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

  ConsoleState copyWith({
    List<CollectionInfo>? collections,
    List<AppDataInfo>? apps,
    int? preferenceCount,
    String? error,
    bool? loading,
    bool? hasData,
    bool clearError = false,
  }) {
    return ConsoleState(
      collections: collections ?? this.collections,
      apps: apps ?? this.apps,
      preferenceCount: preferenceCount ?? this.preferenceCount,
      error: clearError ? null : (error ?? this.error),
      loading: loading ?? this.loading,
      hasData: hasData ?? this.hasData,
    );
  }
}