import 'package:flutter/material.dart';
import 'package:any/any.dart';
import 'package:shared_database/shared_database.dart';

import '../../commands/console_commands.dart';
import '../../commands/records_commands.dart';
import '../../dialogs/collection_ops.dart';
import '../../models/records_view.dart';
import '../../states/records_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_format.dart';
import '../../utils/json_format.dart';
import '../../widgets/common.dart';
import '../../widgets/record_sheets.dart';
import 'records_scope.dart';

/// Records browser for one collection: live watch, search, sort,
/// table/card views, multi-select bulk ops, pins and tags.
class CollectionPage extends StatelessWidget {
  const CollectionPage({
    super.key,
    required this.collection,
    this.focusRecordId,
  });

  final CollectionInfo collection;

  /// When set, opens the detail sheet for this record once loaded
  /// (used by global search results).
  final String? focusRecordId;

  @override
  Widget build(BuildContext context) {
    return RecordsScope(
      collectionName: collection.name,
      child: _CollectionView(focusRecordId: focusRecordId),
    );
  }
}

class _CollectionView extends StatefulWidget {
  const _CollectionView({this.focusRecordId});

  final String? focusRecordId;

  @override
  State<_CollectionView> createState() => _CollectionViewState();
}

class _CollectionViewState extends State<_CollectionView> {
  bool _focusHandled = false;

  @override
  Widget build(BuildContext context) {
    final records = context.of<RecordsState>();
    _maybeFocusRecord(context, records);
    return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(records.collectionName),
                Text(
                  '${records.records.length} records',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                ),
              ],
            ),
            actions: [
              _CollectionMenu(records: records),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              _Toolbar(records: records),
              if (records.selectMode) _SelectionBar(records: records),
              Expanded(child: _Body(records: records)),
            ],
          ),
          floatingActionButton: records.initialLoading
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _openEditor(context, records),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Record'),
                ),
        );
  }

  void _maybeFocusRecord(BuildContext context, RecordsState records) {
    final id = widget.focusRecordId;
    if (_focusHandled || id == null || records.initialLoading) return;
    final record = records.records
        .where((r) => r.id == id)
        .firstOrNull;
    if (record == null) return;
    _focusHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      _openDetail(context, records, record);
    });
  }

  Future<void> _openEditor(
    BuildContext context,
    RecordsState records, {
    SharedRecord? record,
  }) async {
    final changed = await showRecordEditorSheet(
      context,
      collection: records.collectionName,
      mode: record == null ? RecordEditorMode.create : RecordEditorMode.edit,
      existing: record,
    );
    if (changed && context.mounted) {
      context.call(const ReloadConsoleCommand());
    }
  }

  void _openDetail(
    BuildContext context,
    RecordsState records,
    SharedRecord record,
  ) {
    showRecordDetailSheet(
      context,
      collection: records.collectionName,
      record: record,
      pinned: records.pinned,
      recordTags: records.tags[record.id] ?? const {},
      onTogglePin: (id) => context.call(TogglePinRecordCommand(id)),
      onSetTags: (id, tags) =>
          context.call(SetRecordTagsCommand(id, tags)),
      onChanged: () => context.call(const ReloadConsoleCommand()),
    );
  }
}

// ————————————————————————————————————————————————
// Toolbar
// ————————————————————————————————————————————————

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.records});

  final RecordsState records;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 240,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Filter ${records.visibleRecords.length} '
                    'of ${records.records.length}…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true,
                suffixIcon: records.query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => context.call(
                              const SetRecordsQueryCommand(''),
                            ),
                      ),
              ),
              onChanged: (v) => context.call(SetRecordsQueryCommand(v)),
            ),
          ),
          DropdownButton<RecordsSort>(
            value: records.sort,
            underline: const SizedBox.shrink(),
            items: [
              for (final s in RecordsSort.values)
                DropdownMenuItem(value: s, child: Text(s.label)),
            ],
            onChanged: (v) =>
                v == null ? null : context.call(SetRecordsSortCommand(v)),
          ),
          SegmentedButton<RecordsViewMode>(
            segments: const [
              ButtonSegment(
                value: RecordsViewMode.cards,
                icon: Icon(Icons.view_agenda_outlined, size: 18),
                tooltip: 'Cards',
              ),
              ButtonSegment(
                value: RecordsViewMode.table,
                icon: Icon(Icons.table_rows_outlined, size: 18),
                tooltip: 'Table',
              ),
            ],
            selected: {records.viewMode},
            onSelectionChanged: (s) =>
                context.call(SetRecordsViewModeCommand(s.first)),
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
          ),
          IconButton.filledTonal(
            tooltip: records.selectMode ? 'Exit select' : 'Select records',
            onPressed: () => context.call(
                  SetRecordSelectModeCommand(!records.selectMode),
                ),
            icon: Icon(
              records.selectMode
                  ? Icons.checklist_rounded
                  : Icons.checklist_outlined,
              color: records.selectMode ? scheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ————————————————————————————————————————————————
// Selection bar
// ————————————————————————————————————————————————

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.records});

  final RecordsState records;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Text(
              '${records.selected.length} selected',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () =>
                  context.call(const ToggleSelectAllVisibleCommand()),
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('All'),
            ),
            IconButton(
              tooltip: 'Copy selected as JSON',
              icon: const Icon(Icons.copy_rounded, size: 20),
              onPressed: () {
                Ui.copyText(
                  context,
                  records.exportJson(onlySelected: true),
                  label: 'Copied ${records.selected.length} record(s)',
                );
              },
            ),
            IconButton(
              tooltip: 'Delete selected',
              icon: Icon(Icons.delete_outline_rounded,
                  size: 20, color: scheme.error),
              onPressed: () => _deleteSelected(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSelected(BuildContext context) async {
    final ok = await Ui.confirm(
      context,
      title: 'Delete ${records.selected.length} record(s)?',
      message: 'This permanently removes the selected records from '
          '"${records.collectionName}".',
    );
    if (!ok || !context.mounted) return;
    try {
      final n = records.selected.length;
      await context.call(const DeleteSelectedRecordsCommand());
      if (context.mounted) {
        Ui.message(context, 'Deleted $n record(s)');
        context.call(const ReloadConsoleCommand());
      }
    } catch (e) {
      if (context.mounted) Ui.error(context, e);
    }
  }
}

// ————————————————————————————————————————————————
// Body
// ————————————————————————————————————————————————

class _Body extends StatelessWidget {
  const _Body({required this.records});

  final RecordsState records;

  @override
  Widget build(BuildContext context) {
    if (records.initialLoading) {
      return const LoadingView(message: 'Loading records…');
    }
    if (records.records.isEmpty) {
      return EmptyState(
        icon: Icons.inbox_outlined,
        message:
            'No records in "${records.collectionName}" yet.\n'
            'Add one or write from a client with put(...).',
        action: FilledButton.icon(
          onPressed: () => openRecordDetailEditor(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add record'),
        ),
      );
    }
    final visible = records.visibleRecords;
    if (visible.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        message: 'No records match the current filter.',
      );
    }
    return records.viewMode == RecordsViewMode.table
        ? _RecordsTable(records: records)
        : _RecordsCards(records: records);
  }
}

/// Opens the record editor for the collection behind [context].
void openRecordDetailEditor(BuildContext context) {
  final records = context.read<RecordsState>();
  showRecordEditorSheet(
    context,
    collection: records.collectionName,
    mode: RecordEditorMode.create,
  ).then((changed) {
    if (changed && context.mounted) {
      context.call(const ReloadConsoleCommand());
    }
  });
}

/// Opens the read-only detail sheet for [r].
void openRecordDetail(
  BuildContext context,
  RecordsState records,
  SharedRecord r,
) {
  showRecordDetailSheet(
    context,
    collection: records.collectionName,
    record: r,
    pinned: records.pinned,
    recordTags: records.tags[r.id] ?? const {},
    onTogglePin: (id) => context.call(TogglePinRecordCommand(id)),
    onSetTags: (id, tags) =>
        context.call(SetRecordTagsCommand(id, tags)),
    onChanged: () => context.call(const ReloadConsoleCommand()),
  );
}

// ————————————————————————————————————————————————
// Cards view
// ————————————————————————————————————————————————

class _RecordsCards extends StatelessWidget {
  const _RecordsCards({required this.records});

  final RecordsState records;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = records.visibleRecords;
    return ListView.builder(
      padding: AppLayout.pagePaddingFab,
      itemCount: visible.length,
      itemBuilder: (context, i) {
        final r = visible[i];
        final isPinned = records.pinned.contains(r.id);
        final recTags = records.tags[r.id] ?? const <String>{};
        final selected = records.selected.contains(r.id);
        return Card(
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () {
              if (records.selectMode) {
                context.call(ToggleRecordSelectionCommand(r.id));
              } else {
                openRecordDetail(context, records, r);
              }
            },
            onLongPress: () {
              if (!records.selectMode) {
                context.call(const SetRecordSelectModeCommand(true));
              }
              context.call(ToggleRecordSelectionCommand(r.id));
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (records.selectMode)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: 8),
                      child: Checkbox(
                        value: selected,
                        onChanged: (_) =>
                            context.call(ToggleRecordSelectionCommand(r.id)),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isPinned)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Icon(
                                  Icons.push_pin_rounded,
                                  size: 14,
                                  color: scheme.primary,
                                ),
                              ),
                            Expanded(
                              child: SelectableText(
                                r.id,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontFamily: 'monospace'),
                                maxLines: 1,
                              ),
                            ),
                            Text(
                              r.updatedAt == null
                                  ? ''
                                  : formatEpochMillis(r.updatedAt!),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: scheme.outline,
                                    fontSize: 11,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          formatJsonMap(r.data),
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                fontFamily: 'monospace',
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                        if (recTags.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 4,
                            children: [
                              for (final t in recTags)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: scheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    t,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: scheme.onSecondaryContainer,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!records.selectMode)
                    Icon(Icons.chevron_right_rounded,
                        color: scheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

}

// ————————————————————————————————————————————————
// Table view
// ————————————————————————————————————————————————

class _RecordsTable extends StatelessWidget {
  const _RecordsTable({required this.records});

  final RecordsState records;

  @override
  Widget build(BuildContext context) {
    final visible = records.visibleRecords;
    final columns = _columnsFor(visible);
    final scheme = Theme.of(context).colorScheme;
    final selectMode = records.selectMode;

    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          padding: AppLayout.pagePaddingFab,
          child: DataTable(
            columnSpacing: 24,
            horizontalMargin: 12,
            showCheckboxColumn: false,
            columns: [
              if (selectMode)
                const DataColumn(label: SizedBox(width: 36)),
              for (final col in columns)
                DataColumn(
                  label: Text(col, style: const TextStyle(fontSize: 12)),
                ),
            ],
            rows: [
              for (final r in visible)
                DataRow(
                  cells: [
                    if (selectMode)
                      DataCell(
                        Checkbox(
                          value: records.selected.contains(r.id),
                          onChanged: (_) =>
                            context.call(ToggleRecordSelectionCommand(r.id)),
                        ),
                      ),
                    for (final col in columns)
                      DataCell(
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => selectMode
                              ? context.call(
                                  ToggleRecordSelectionCommand(r.id),
                                )
                              : openRecordDetail(context, records, r),
                          child: _cell(context, r, col, scheme),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _columnsFor(List<SharedRecord> rows) {
    // Fixed columns + up to 5 most common data keys.
    final frequency = <String, int>{};
    for (final r in rows) {
      for (final key in r.data.keys) {
        frequency[key] = (frequency[key] ?? 0) + 1;
      }
    }
    final keys = frequency.keys.toList()
      ..sort((a, b) => frequency[b]!.compareTo(frequency[a]!));
    return [
      'id',
      'updated',
      ...keys.take(5),
    ];
  }

  Widget _cell(
    BuildContext context,
    SharedRecord r,
    String col,
    ColorScheme scheme,
  ) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          fontSize: 12,
          color: scheme.onSurfaceVariant,
        );
    return switch (col) {
      'id' => Tooltip(
          message: r.id,
          child: Text(
            r.id.length > 13 ? '${r.id.substring(0, 13)}…' : r.id,
            style: style,
          ),
        ),
      'updated' => Text(
          r.updatedAt == null ? '—' : formatEpochMillis(r.updatedAt!),
          style: style,
        ),
      _ => Text(
          summarizeValue(r.data[col], maxLen: 40),
          style: style,
          overflow: TextOverflow.ellipsis,
        ),
    };
  }
}

// ————————————————————————————————————————————————
// Collection overflow menu
// ————————————————————————————————————————————————

class _CollectionMenu extends StatelessWidget {
  const _CollectionMenu({required this.records});

  final RecordsState records;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: 'Collection actions',
      onSelected: (action) => _run(context, action),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'rename',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.drive_file_rename_outline, size: 20),
            title: Text('Rename'),
          ),
        ),
        const PopupMenuItem(
          value: 'export',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.upload_rounded, size: 20),
            title: Text('Export JSON'),
          ),
        ),
        const PopupMenuItem(
          value: 'import',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.download_rounded, size: 20),
            title: Text('Import JSON'),
          ),
        ),
        PopupMenuItem(
          value: 'clear',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_sweep_outlined,
                size: 20, color: scheme.error),
            title: Text('Clear records',
                style: TextStyle(color: scheme.error)),
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_forever_outlined,
                size: 20, color: scheme.error),
            title: Text('Delete collection',
                style: TextStyle(color: scheme.error)),
          ),
        ),
      ],
    );
  }

  Future<void> _run(BuildContext context, String action) async {
    void refresh() => context.call(const ReloadConsoleCommand());
    switch (action) {
      case 'rename':
        await runCollectionRename(
          context,
          currentName: records.collectionName,
          onChanged: refresh,
          onRenamed: (name) =>
              context.call(RenameRecordsCollectionCommand(name)),
        );
      case 'export':
        await runCollectionExport(
          context,
          collection: records.collectionName,
        );
      case 'import':
        final n = await runCollectionImport(
          context,
          collection: records.collectionName,
        );
        if (n != null) refresh();
      case 'clear':
        await runCollectionClear(
          context,
          name: records.collectionName,
          recordCount: records.records.length,
          onChanged: refresh,
        );
        // The watch stream picks up the change on its next poll.
      case 'delete':
        final deleted = await runCollectionDelete(
          context,
          name: records.collectionName,
          recordCount: records.records.length,
          onChanged: refresh,
        );
        if (deleted && context.mounted) Navigator.of(context).pop();
    }
  }
}
