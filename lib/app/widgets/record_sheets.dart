import 'package:flutter/material.dart';
import 'package:shared_database/shared_database.dart';

import '../utils/date_format.dart';
import '../utils/json_format.dart';
import '../utils/package_label.dart';
import 'common.dart';
import 'json_tree.dart';

enum RecordEditorMode { create, edit }

/// Full editor for one record: visual JSON tree + raw JSON tabs.
/// Returns true when a write happened.
Future<bool> showRecordEditorSheet(
  BuildContext context, {
  required String collection,
  RecordEditorMode mode = RecordEditorMode.edit,
  SharedRecord? existing,
}) async {
  final editRecord = existing;
  assert(mode == RecordEditorMode.create || editRecord != null);

  final idController = TextEditingController(
    text: mode == RecordEditorMode.edit ? editRecord!.id : '',
  );
  final jsonController = TextEditingController(
    text: mode == RecordEditorMode.edit
        ? formatJsonMap(editRecord!.data)
        : '{\n  \n}',
  );
  // Working copy for the tree tab.
  Object? treeValue = mode == RecordEditorMode.edit
      ? Map<String, dynamic>.from(editRecord!.data)
      : <String, dynamic>{};
  var tab = 0;
  var saving = false;
  String? jsonError;
  bool dirty = false;

  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setLocal) {
          Future<void> save() async {
            Map<String, dynamic>? data;
            if (tab == 0) {
              data = treeValue is Map
                  ? Map<String, dynamic>.from(treeValue as Map)
                  : null;
              if (data == null) {
                setLocal(() => jsonError = 'Root must be a JSON object');
                return;
              }
            } else {
              data = parseJsonObject(jsonController.text);
              if (data == null) {
                setLocal(() => jsonError = 'JSON must be a {...} object');
                return;
              }
            }
            setLocal(() {
              saving = true;
              jsonError = null;
            });
            try {
              final db = SharedDatabase.instance;
              if (mode == RecordEditorMode.create) {
                final id = idController.text.trim();
                await db.put(collection, data, id: id.isEmpty ? null : id);
              } else {
                await db.put(collection, data, id: editRecord!.id);
              }
              if (context.mounted) Navigator.pop(context, true);
            } catch (e) {
              setLocal(() => saving = false);
              if (context.mounted) Ui.error(context, e);
            }
          }

          Future<void> remove() async {
            if (mode != RecordEditorMode.edit) return;
            final ok = await Ui.confirm(
              context,
              title: 'Delete record?',
              message: 'This removes "${editRecord!.id}" from $collection.',
            );
            if (!ok || !context.mounted) return;
            setLocal(() => saving = true);
            try {
              await SharedDatabase.instance.removeById(
                collection,
                editRecord.id,
              );
              if (context.mounted) Navigator.pop(context, true);
            } catch (e) {
              setLocal(() => saving = false);
              if (context.mounted) Ui.error(context, e);
            }
          }

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
                ),
                child: Column(
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
                    const SizedBox(height: 8),
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
                        onChanged: (_) => dirty = true,
                      )
                    else
                      SelectableText(
                        editRecord!.id,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontFamily: 'monospace'),
                      ),
                    const SizedBox(height: 8),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(
                          value: 0,
                          icon: Icon(Icons.account_tree_outlined, size: 18),
                          label: Text('Tree'),
                        ),
                        ButtonSegment(
                          value: 1,
                          icon: Icon(Icons.code_rounded, size: 18),
                          label: Text('JSON'),
                        ),
                      ],
                      selected: {tab},
                      onSelectionChanged: saving
                          ? null
                          : (s) => setLocal(() => tab = s.first),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: tab == 0
                          ? JsonTreeEditor(
                              key: ValueKey(
                                'tree_${mode.name}_${editRecord?.id ?? 'new'}',
                              ),
                              initialValue: treeValue,
                              onChanged: (v) {
                                dirty = true;
                                treeValue = v;
                                // Keep JSON tab in sync.
                                final encoded = tryEncodeJson(v);
                                if (encoded != null) {
                                  jsonController.text = formatJsonValue(
                                    jsonDecodeSafe(encoded),
                                  );
                                }
                              },
                            )
                          : TextField(
                              controller: jsonController,
                              scrollController: scrollController,
                              maxLines: null,
                              expands: true,
                              textAlignVertical: TextAlignVertical.top,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                height: 1.5,
                              ),
                              decoration: InputDecoration(
                                labelText: 'JSON data',
                                alignLabelWithHint: true,
                                errorText: jsonError,
                              ),
                              onChanged: (_) => dirty = true,
                            ),
                    ),
                    if (jsonError != null && tab == 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          jsonError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
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
                        FilledButton.icon(
                          onPressed: saving ||
                                  (!dirty && mode == RecordEditorMode.edit)
                              ? null
                              : save,
                          icon: saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  );

  return changed ?? false;
}

// ————————————————————————————————————————————————
// Record detail sheet
// ————————————————————————————————————————————————

/// Read-only detail + actions for one record.
Future<void> showRecordDetailSheet(
  BuildContext context, {
  required String collection,
  required SharedRecord record,
  Set<String> pinned = const {},
  Set<String> recordTags = const {},
  Future<void> Function(String id)? onTogglePin,
  Future<void> Function(String id, Set<String> tags)? onSetTags,
  VoidCallback? onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) {
      var isPinned = pinned.contains(record.id);
      var tags = {...recordTags};
      return StatefulBuilder(
        builder: (context, setLocal) {
          Future<void> editTags() async {
            final controller = TextEditingController(
              text: tags.join(', '),
            );
            final result = await showDialog<String>(
              context: context,
              builder: (dctx) => AlertDialog(
                title: const Text('Tags'),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Comma-separated tags',
                    hintText: 'work, important',
                  ),
                  onSubmitted: (v) => Navigator.pop(dctx, v),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dctx),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () =>
                        Navigator.pop(dctx, controller.text),
                    child: const Text('Save'),
                  ),
                ],
              ),
            );
            if (result == null) return;
            final next = result
                .split(',')
                .map((t) => t.trim())
                .where((t) => t.isNotEmpty)
                .toSet();
            setLocal(() => tags = next);
            await onSetTags?.call(record.id, next);
          }

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.8,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Record',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              record.id,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: isPinned ? 'Unpin' : 'Pin',
                        icon: Icon(
                          isPinned
                              ? Icons.push_pin_rounded
                              : Icons.push_pin_outlined,
                          color: isPinned
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                        onPressed: () async {
                          await onTogglePin?.call(record.id);
                          setLocal(() => isPinned = !isPinned);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _MetaChip(
                        icon: Icons.schedule_outlined,
                        label: record.updatedAt == null
                            ? 'never'
                            : formatEpochMillis(record.updatedAt!),
                      ),
                      if (record.createdBy != null)
                        _MetaChip(
                          icon: Icons.person_outline_rounded,
                          label: packageLabel(record.createdBy!),
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.sell_outlined, size: 16),
                        label: Text(
                          tags.isEmpty ? 'Add tags' : tags.join(', '),
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: editTags,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  JsonTreeView(value: record.data),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () {
                          Navigator.pop(context);
                          Ui.copyText(
                            context,
                            formatJsonMap(record.data),
                            label: 'Record JSON copied',
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copy JSON'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final db = SharedDatabase.instance;
                          final newId = await db.put(
                            collection,
                            Map<String, dynamic>.from(record.data),
                          );
                          onChanged?.call();
                          if (context.mounted) {
                            Navigator.pop(context);
                            Ui.message(
                              context,
                              'Duplicated as $newId',
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_all_rounded, size: 18),
                        label: const Text('Duplicate'),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
        },
      );
    },
  );
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(icon, size: 14, color: scheme.onSurfaceVariant),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      side: BorderSide(color: scheme.outlineVariant),
    );
  }
}
