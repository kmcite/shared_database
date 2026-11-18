import 'dart:convert';

import 'package:shared_database/shared_database.dart';

import '../models/records_view.dart';
import '../utils/json_format.dart';

/// Mutable browser state for one collection (filters, selection, pins).
class RecordsState {
  RecordsState({required this.collectionName});

  String collectionName;
  List<SharedRecord> records = [];
  bool initialLoading = true;
  String? watchError;

  String query = '';
  RecordsSort sort = RecordsSort.updatedDesc;
  RecordsViewMode viewMode = RecordsViewMode.cards;
  final Set<String> selected = {};
  bool selectMode = false;

  final Set<String> pinned = {};
  final Map<String, Set<String>> tags = {};

  List<String> get allTags {
    final s = tags.values.expand((e) => e).toSet().toList()..sort();
    return s;
  }

  List<SharedRecord> get visibleRecords {
    final q = query.trim().toLowerCase();
    var out = records;
    if (q.isNotEmpty) {
      out = out.where((r) => _matches(r, q)).toList();
    }
    out = [...out]..sort(_compare);
    return out;
  }

  bool get allVisibleSelected =>
      visibleRecords.isNotEmpty &&
      visibleRecords.every((r) => selected.contains(r.id));

  bool _matches(SharedRecord r, String q) {
    if (r.id.toLowerCase().contains(q)) return true;
    if (tags[r.id]?.any((t) => t.toLowerCase().contains(q)) ?? false) {
      return true;
    }
    final buffer = StringBuffer();
    collectSearchableText(r.data, buffer.write);
    return buffer.toString().toLowerCase().contains(q);
  }

  int _compare(SharedRecord a, SharedRecord b) {
    int cmp;
    switch (sort) {
      case RecordsSort.updatedDesc:
        cmp = (b.updatedAt ?? 0).compareTo(a.updatedAt ?? 0);
      case RecordsSort.updatedAsc:
        cmp = (a.updatedAt ?? 0).compareTo(b.updatedAt ?? 0);
      case RecordsSort.createdDesc:
        cmp = (b.createdAt ?? 0).compareTo(a.createdAt ?? 0);
      case RecordsSort.createdAsc:
        cmp = (a.createdAt ?? 0).compareTo(b.createdAt ?? 0);
      case RecordsSort.idAsc:
        cmp = a.id.compareTo(b.id);
      case RecordsSort.idDesc:
        cmp = b.id.compareTo(a.id);
    }
    if (cmp != 0) return cmp;
    final pa = pinned.contains(a.id) ? 0 : 1;
    final pb = pinned.contains(b.id) ? 0 : 1;
    if (pa != pb) return pa - pb;
    return a.id.compareTo(b.id);
  }

  String exportJson({required bool onlySelected}) {
    final source = onlySelected && selected.isNotEmpty
        ? records.where((r) => selected.contains(r.id)).toList()
        : records;
    return const JsonEncoder.withIndent('  ').convert({
      'collection': collectionName,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'records': source
          .map(
            (r) => {
              'id': r.id,
              'data': r.data,
              'createdAt': r.createdAt,
              'updatedAt': r.updatedAt,
              'createdBy': r.createdBy,
              'updatedBy': r.updatedBy,
            },
          )
          .toList(),
    });
  }
}