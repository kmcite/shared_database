/// Host-console types (manager app / `openHost()`).
class DatabaseOverview {
  const DatabaseOverview({
    required this.collectionCount,
    required this.recordCount,
    required this.hostPackage,
  });

  final int collectionCount;
  final int recordCount;
  final String hostPackage;

  factory DatabaseOverview.fromMap(Map<dynamic, dynamic> map) {
    return DatabaseOverview(
      collectionCount: map['collectionCount'] as int? ?? 0,
      recordCount: map['recordCount'] as int? ?? 0,
      hostPackage: map['hostPackage'] as String? ?? '',
    );
  }
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

  factory CollectionInfo.fromMap(Map<dynamic, dynamic> map) {
    return CollectionInfo(
      name: map['name'] as String? ?? '',
      createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
      createdByPackage: map['createdByPackage'] as String? ?? '',
      recordCount: map['recordCount'] as int? ?? 0,
    );
  }
}

/// An app that created collections or records in the shared database.
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

  factory AppDataInfo.fromMap(Map<dynamic, dynamic> map) {
    final raw = map['collections'] as List<dynamic>? ?? [];
    return AppDataInfo(
      packageName: map['packageName'] as String? ?? '',
      collectionCount: map['collectionCount'] as int? ?? 0,
      recordCount: map['recordCount'] as int? ?? 0,
      collections: raw
          .cast<Map<dynamic, dynamic>>()
          .map(CollectionInfo.fromMap)
          .toList(),
    );
  }
}
