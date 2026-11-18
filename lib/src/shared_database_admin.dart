/// Host-console types (manager app / `openHost()`).
class DatabaseOverview {
  const DatabaseOverview({
    required this.collectionCount,
    required this.recordCount,
  });

  final int collectionCount;
  final int recordCount;
}

class CollectionInfo {
  const CollectionInfo({
    required this.name,
    required this.createdAt,
    required this.createdByPackage,
    required this.recordCount,
  });

  final String name;
  final int createdAt;
  final String createdByPackage;
  final int recordCount;
}

/// An app that created collections in the shared database.
class AppDataInfo {
  const AppDataInfo({
    required this.packageName,
    required this.collectionCount,
    required this.recordCount,
    required this.collections,
  });

  final String packageName;
  final int collectionCount;
  final int recordCount;
  final List<CollectionInfo> collections;
}
