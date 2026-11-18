import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_database/shared_database.dart';

import '../utils/json_format.dart';
import '../widgets/common.dart';

/// Collection-level operations shared by pages: create / rename /
/// delete / export / import / clear.

Future<void> runCollectionCreate(
  BuildContext context,
  VoidCallback onChanged,
) async {
  final name = await _nameDialog(
    context,
    title: 'New collection',
    confirmLabel: 'Create',
  );
  if (name == null || !context.mounted) return;
  try {
    await SharedDatabase.instance.ensureCollection(name);
    onChanged();
    if (context.mounted) Ui.message(context, 'Created "$name"');
  } catch (e) {
    if (context.mounted) Ui.error(context, e);
  }
}

Future<void> runCollectionRename(
  BuildContext context, {
  required String currentName,
  required VoidCallback onChanged,
  void Function(String newName)? onRenamed,
}) async {
  final to = await _nameDialog(
    context,
    title: 'Rename collection',
    initial: currentName,
    confirmLabel: 'Rename',
  );
  if (to == null || to == currentName || !context.mounted) return;
  try {
    await SharedDatabase.instance.renameCollection(currentName, to);
    onChanged();
    onRenamed?.call(to);
    if (context.mounted) Ui.message(context, 'Renamed to "$to"');
  } catch (e) {
    if (context.mounted) Ui.error(context, e);
  }
}

/// Returns true when the collection was deleted.
Future<bool> runCollectionDelete(
  BuildContext context, {
  required String name,
  required int recordCount,
  required VoidCallback onChanged,
}) async {
  final ok = await Ui.confirm(
    context,
    title: 'Delete collection?',
    message: recordCount == 0
        ? 'Delete "$name"? This cannot be undone.'
        : 'Delete "$name" and its $recordCount record(s)? '
            'This cannot be undone.',
  );
  if (!ok || !context.mounted) return false;
  try {
    await SharedDatabase.instance.removeCollection(name);
    onChanged();
    if (context.mounted) Ui.message(context, 'Deleted "$name"');
    return true;
  } catch (e) {
    if (context.mounted) Ui.error(context, e);
    return false;
  }
}

/// Remove every record but keep the collection.
Future<bool> runCollectionClear(
  BuildContext context, {
  required String name,
  required int recordCount,
  required VoidCallback onChanged,
}) async {
  final ok = await Ui.confirm(
    context,
    title: 'Clear collection?',
    message: 'Remove all $recordCount record(s) from "$name"? '
        'The collection itself is kept.',
    confirmLabel: 'Clear',
  );
  if (!ok || !context.mounted) return false;
  try {
    await SharedDatabase.instance.removeAll(name);
    onChanged();
    if (context.mounted) Ui.message(context, 'Cleared "$name"');
    return true;
  } catch (e) {
    if (context.mounted) Ui.error(context, e);
    return false;
  }
}

/// Exports a whole collection to a user-chosen JSON file.
Future<void> runCollectionExport(
  BuildContext context, {
  required String collection,
}) async {
  try {
    final db = SharedDatabase.instance;
    final records = await db.getAll(collection);
    final prefs = <String, String?>{};
    for (final key in await db.getPreferenceKeys()) {
      prefs[key] = await db.getPreference(key);
    }
    final payload = {
      'collection': collection,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'preferences': prefs,
      'records': records
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
    };
    final json = const JsonEncoder.withIndent('  ').convert(payload);
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Export $collection',
      fileName: '$collection.json',
      bytes: utf8.encode(json),
    );
    if (saved != null && context.mounted) {
      Ui.message(context, 'Exported ${records.length} record(s)');
    }
  } catch (e) {
    if (context.mounted) Ui.error(context, e);
  }
}

/// Imports records from a previously exported JSON file into [collection].
/// Existing ids are overwritten (upsert).
Future<int?> runCollectionImport(
  BuildContext context, {
  required String collection,
}) async {
  try {
    final files = await FilePicker.pickFiles(
      dialogTitle: 'Import into $collection',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final file = files.firstOrNull;
    if (file == null || !context.mounted) return null;
    final bytes = await file.readAsBytes();
    if (!context.mounted) return null;

    final decoded = jsonDecode(utf8.decode(bytes));
    final list = decoded is Map && decoded['records'] is List
        ? decoded['records'] as List
        : decoded is List
            ? decoded
            : null;
    if (list == null) {
      if (context.mounted) {
        Ui.message(context, 'Unrecognized file format');
      }
      return null;
    }

    final db = SharedDatabase.instance;
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
        await db.putMany(collection, batch);
        count += batch.length;
        batch.clear();
      }
    }
    if (batch.isNotEmpty) {
      await db.putMany(collection, batch);
      count += batch.length;
    }

    // Restore preferences when the file carries them.
    var prefCount = 0;
    final prefs = decoded is Map ? decoded['preferences'] : null;
    if (prefs is Map) {
      for (final e in prefs.entries) {
        if (e.key is String) {
          await db.setPreference(
            e.key as String,
            e.value?.toString() ?? '',
          );
          prefCount++;
        }
      }
    }
    if (context.mounted) {
      Ui.message(
        context,
        'Imported $count record(s)'
        '${prefCount > 0 ? ' + $prefCount preference(s)' : ''} '
        'into $collection',
      );
    }
    return count;
  } catch (e) {
    if (context.mounted) Ui.error(context, e);
    return null;
  }
}

Future<String?> _nameDialog(
  BuildContext context, {
  required String title,
  String? initial,
  required String confirmLabel,
}) {
  final controller = TextEditingController(text: initial ?? '');
  String? errorText;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + 24,
        ),
        child: StatefulBuilder(
          builder: (context, setLocal) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Collection name',
                    errorText: errorText,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => Navigator.pop(
                    context,
                    controller.text.trim(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        final err = validateCollectionName(controller.text);
                        if (err != null) {
                          setLocal(() => errorText = err);
                          return;
                        }
                        Navigator.pop(context, controller.text.trim());
                      },
                      child: Text(confirmLabel),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    },
  );
}
