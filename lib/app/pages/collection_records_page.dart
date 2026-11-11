import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_database/shared_database.dart';

import '../dialogs/manager_dialogs.dart';
import '../dialogs/manager_editors.dart';
import '../state/collection_records_controller.dart';
import '../state/host_console_controller.dart';
import '../theme/app_theme.dart';
import '../util/json_format.dart';
import '../widgets/app_empty.dart';
import '../widgets/host_loading_view.dart';
import '../widgets/host_shell.dart';

class CollectionRecordsPage extends StatelessWidget {
  const CollectionRecordsPage({super.key, required this.collection});

  final CollectionInfo collection;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CollectionRecordsController(collection.name),
      child: const _CollectionRecordsView(),
    );
  }
}

class _CollectionRecordsView extends StatefulWidget {
  const _CollectionRecordsView();

  @override
  State<_CollectionRecordsView> createState() => _CollectionRecordsViewState();
}

class _CollectionRecordsViewState extends State<_CollectionRecordsView> {
  String? _lastWatchError;
  CollectionRecordsController? _records;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _records = context.read<CollectionRecordsController>();
      _records!.addListener(_onRecordsUpdate);
    });
  }

  @override
  void dispose() {
    _records?.removeListener(_onRecordsUpdate);
    super.dispose();
  }

  void _onRecordsUpdate() {
    if (!mounted) return;
    final err = context.read<CollectionRecordsController>().watchError;
    if (err != null && err != _lastWatchError) {
      _lastWatchError = err;
      showManagerMessage(context, err);
    }
  }

  void _refreshHost(BuildContext context) {
    context.read<HostConsoleController>().notifyDataChanged();
  }

  Future<void> _openRecordEditor(
    BuildContext context, {
    SharedRecord? record,
  }) async {
    final records = context.read<CollectionRecordsController>();
    final changed = await showRecordEditorSheet(
      context,
      collection: records.collectionName,
      mode: record == null ? RecordEditorMode.create : RecordEditorMode.edit,
      existing: record,
    );
    if (changed && context.mounted) _refreshHost(context);
  }

  Future<void> _onCollectionMenu(BuildContext context, String action) async {
    final records = context.read<CollectionRecordsController>();
    switch (action) {
      case 'rename':
        await runCollectionRename(
          context,
          currentName: records.collectionName,
          onChanged: () => _refreshHost(context),
          onRenamed: records.renameCollection,
        );
      case 'delete':
        final deleted = await runCollectionDelete(
          context,
          name: records.collectionName,
          recordCount: records.records.length,
          onChanged: () => _refreshHost(context),
        );
        if (deleted && context.mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CollectionRecordsController>(
      builder: (context, records, _) {
        final scheme = Theme.of(context).colorScheme;

        return ManagerScaffold(
          title: Text(records.collectionName),
          actions: [
            PopupMenuButton<String>(
              onSelected: (action) => _onCollectionMenu(context, action),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'rename',
                  child: Text('Rename collection'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Delete collection',
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
          ],
          floatingActionButton: FloatingActionButton.extended(
            onPressed: records.initialLoading
                ? null
                : () => _openRecordEditor(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Record'),
          ),
          body: _RecordsBody(
            records: records,
            onAdd: () => _openRecordEditor(context),
            onEdit: (r) => _openRecordEditor(context, record: r),
          ),
        );
      },
    );
  }
}

class _RecordsBody extends StatelessWidget {
  const _RecordsBody({
    required this.records,
    required this.onAdd,
    required this.onEdit,
  });

  final CollectionRecordsController records;
  final VoidCallback onAdd;
  final ValueChanged<SharedRecord> onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (records.initialLoading) {
      return const HostLoadingView(message: 'Loading records…');
    }
    if (records.records.isEmpty) {
      return Center(
        child: Padding(
          padding: AppLayout.pagePadding,
          child: AppEmpty(
            icon: Icons.inbox_outlined,
            message:
                'No records in “${records.collectionName}” yet.\n'
                'Add a record or write from a client with put(...).',
            action: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add record'),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: AppLayout.pagePaddingFab,
      itemCount: records.records.length,
      itemBuilder: (context, i) {
        final r = records.records[i];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            onTap: () => onEdit(r),
            title: Text(
              r.id,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
            subtitle: Text(
              formatJsonMap(r.data),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Icon(Icons.edit_outlined, color: scheme.primary),
          ),
        );
      },
    );
  }
}
