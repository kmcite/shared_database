import 'dart:convert';

import 'package:shared_database/shared_database.dart';

import '../models/collection_import_result.dart';
import 'collections_repository.dart';
import 'preferences_repository.dart';

/// JSON import/export and factory reset — orchestrates collections + preferences.
class BackupRepository {
  BackupRepository(
    SharedDatabase db, {
    CollectionsRepository? collections,
    PreferencesRepository? preferences,
  })  : _collections = collections ?? CollectionsRepository(db),
        _preferences = preferences ?? PreferencesRepository(db);

  final CollectionsRepository _collections;
  final PreferencesRepository _preferences;

  static Map<String, dynamic> recordToExportJson(SharedRecord r) => {
        'id': r.id,
        'data': r.data,
        'createdAt': r.createdAt,
        'updatedAt': r.updatedAt,
        'createdBy': r.createdBy,
        'updatedBy': r.updatedBy,
      };

  /// Single-collection backup JSON (includes every preference key — host legacy format).
  Future<String> exportCollectionJson(
    String collection, {
    List<SharedRecord>? records,
  }) async {
    records ??= await _collections.getAllRecords(collection);
    final prefs = await _preferences.readAll();
    final payload = {
      'collection': collection,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'preferences': prefs,
      'records': records.map(recordToExportJson).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<CollectionImportResult> importCollectionPayload(
    String collection,
    dynamic decoded,
  ) async {
    final list = decoded is Map && decoded['records'] is List
        ? decoded['records'] as List
        : decoded is List
            ? decoded
            : null;
    if (list == null) {
      throw FormatException('Unrecognized collection import format');
    }

    final recordCount = await _importRecordList(collection, list);

    var prefCount = 0;
    final prefs = decoded is Map ? decoded['preferences'] : null;
    if (prefs is Map) {
      for (final e in prefs.entries) {
        if (e.key is String) {
          await _preferences.set(
            e.key as String,
            e.value?.toString() ?? '',
          );
          prefCount++;
        }
      }
    }

    return CollectionImportResult(
      recordCount: recordCount,
      preferenceCount: prefCount,
    );
  }

  Future<({String json, int recordCount})> exportFullBackup(
    List<CollectionInfo> collections,
  ) async {
    final map = <String, dynamic>{};
    var totalRecords = 0;
    for (final c in collections) {
      final rows = await _collections.getAllRecords(c.name);
      totalRecords += rows.length;
      map[c.name] = rows.map(recordToExportJson).toList();
    }
    final payload = {
      'format': 'shared_database.backup',
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'collections': map,
      'preferences': await _preferences.readAll(),
    };
    return (
      json: const JsonEncoder.withIndent('  ').convert(payload),
      recordCount: totalRecords,
    );
  }

  Future<int> importFullBackup(Map<String, dynamic> decoded) async {
    final collections = decoded['collections'];
    if (collections is! Map) {
      throw FormatException('Not a shared_database backup file');
    }
    var imported = 0;
    for (final entry in collections.entries) {
      final name = entry.key;
      if (name is! String || entry.value is! List) continue;
      await _collections.ensure(name);
      imported += await _importRecordList(name, entry.value as List);
    }
    final prefs = decoded['preferences'];
    if (prefs is Map) {
      for (final e in prefs.entries) {
        if (e.key is String) {
          await _preferences.set(e.key as String, e.value?.toString() ?? '');
        }
      }
    }
    return imported;
  }

  Future<void> wipeAll(List<CollectionInfo> collections) async {
    for (final c in collections) {
      await _collections.remove(c.name);
    }
    for (final key in await _preferences.keys()) {
      await _preferences.remove(key);
    }
  }

  Future<int> _importRecordList(String collection, List list) async {
    var count = 0;
    final batch = <({String? id, Map<String, dynamic> data})>[];
    for (final item in list) {
      if (item is! Map) continue;
      final data = item['data'];
      if (data is! Map) continue;
      batch.add((
        id: item['id'] is String ? item['id'] as String : null,
        data: Map<String, dynamic>.from(data),
      ));
      if (batch.length >= 200) {
        await _collections.putMany(collection, batch);
        count += batch.length;
        batch.clear();
      }
    }
    if (batch.isNotEmpty) {
      await _collections.putMany(collection, batch);
      count += batch.length;
    }
    return count;
  }
}