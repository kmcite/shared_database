import 'package:flutter/material.dart';
import 'package:shared_database/shared_database.dart';

import '../util/json_format.dart';
import 'manager_dialogs.dart';

enum RecordEditorMode { create, edit }

/// Bottom sheet to create or edit a record. Returns `true` when data changed.
Future<bool> showRecordEditorSheet(
  BuildContext context, {
  required String collection,
  RecordEditorMode mode = RecordEditorMode.edit,
  SharedRecord? existing,
}) async {
  assert(mode == RecordEditorMode.create || existing != null);
  final editRecord = existing;

  final idController = TextEditingController(
    text: mode == RecordEditorMode.edit ? existing!.id : '',
  );
  final jsonController = TextEditingController(
    text: mode == RecordEditorMode.edit
        ? formatJsonMap(existing!.data)
        : '{\n  \n}',
  );
  var saving = false;
  String? jsonError;

  final changed = await showModalBottomSheet<bool>(
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
            Future<void> save() async {
              final data = parseJsonObject(jsonController.text);
              if (data == null) {
                setLocal(() => jsonError = 'JSON must be a {...} object');
                return;
              }
              setLocal(() {
                saving = true;
                jsonError = null;
              });
              try {
                final db = SharedDatabase.instance;
                if (mode == RecordEditorMode.create) {
                  final id = idController.text.trim();
                  await db.create(
                    collection,
                    data,
                    id: id.isEmpty ? null : id,
                  );
                } else {
                  await db.update(collection, editRecord!.id, data);
                }
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                setLocal(() => saving = false);
                if (context.mounted) {
                  showManagerMessage(context, e.toString());
                }
              }
            }

            Future<void> remove() async {
              if (mode != RecordEditorMode.edit) return;
              final ok = await confirmDestructive(
                context,
                title: 'Delete record?',
                message: 'This removes "${editRecord!.id}" from $collection.',
              );
              if (!ok || !context.mounted) return;
              setLocal(() => saving = true);
              try {
                await SharedDatabase.instance.delete(collection, editRecord.id);
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                setLocal(() => saving = false);
                if (context.mounted) showManagerMessage(context, e.toString());
              }
            }

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          mode == RecordEditorMode.create
                              ? 'New record'
                              : 'Edit record',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      if (mode == RecordEditorMode.edit)
                        IconButton(
                          onPressed: saving ? null : remove,
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          tooltip: 'Delete record',
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (mode == RecordEditorMode.create)
                    TextField(
                      controller: idController,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Record id (optional)',
                        hintText: 'Auto-generated if empty',
                      ),
                    )
                  else
                    Text(
                      editRecord!.id,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: jsonController,
                    minLines: 8,
                    maxLines: 16,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      labelText: 'JSON data',
                      alignLabelWithHint: true,
                      errorText: jsonError,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tip: paste a JSON object with string keys.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: saving
                            ? null
                            : () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: saving ? null : save,
                        child: saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );

  return changed ?? false;
}

Future<void> runCollectionCreate(BuildContext context, VoidCallback onChanged) async {
  final name = await showCollectionNameDialog(
    context,
    title: 'New collection',
    confirmLabel: 'Create',
  );
  if (name == null || !context.mounted) return;
  try {
    await SharedDatabase.instance.ensureCollection(name);
    onChanged();
    if (!context.mounted) return;
    showManagerMessage(context, 'Created "$name"');
  } catch (e) {
    if (context.mounted) showManagerMessage(context, e.toString());
  }
}

Future<void> runCollectionRename(
  BuildContext context, {
  required String currentName,
  required VoidCallback onChanged,
  void Function(String newName)? onRenamed,
}) async {
  final to = await showCollectionNameDialog(
    context,
    title: 'Rename collection',
    initial: currentName,
  );
  if (to == null || to == currentName || !context.mounted) return;
  try {
    await SharedDatabase.instance.renameCollection(currentName, to);
    onChanged();
    onRenamed?.call(to);
    if (!context.mounted) return;
    showManagerMessage(context, 'Renamed to "$to"');
  } catch (e) {
    if (context.mounted) showManagerMessage(context, e.toString());
  }
}

Future<bool> runCollectionDelete(
  BuildContext context, {
  required String name,
  required int recordCount,
  required VoidCallback onChanged,
}) async {
  final ok = await confirmDestructive(
    context,
    title: 'Delete collection?',
    message: recordCount == 0
        ? 'Delete "$name"? This cannot be undone.'
        : 'Delete "$name" and its $recordCount record(s)? This cannot be undone.',
  );
  if (!ok || !context.mounted) return false;
  try {
    await SharedDatabase.instance.deleteCollection(name);
    onChanged();
    if (!context.mounted) return true;
    showManagerMessage(context, 'Deleted "$name"');
    return true;
  } catch (e) {
    if (context.mounted) showManagerMessage(context, e.toString());
    return false;
  }
}
