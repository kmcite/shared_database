import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_database/shared_database.dart';

import '../dialogs/manager_editors.dart';
import '../state/host_console_controller.dart';
import '../theme/app_theme.dart';
import '../util/date_format.dart';
import '../util/package_label.dart';
import '../widgets/app_empty.dart';
import '../widgets/host_shell.dart';
import 'collection_records_page.dart';

class AppCollectionsPage extends StatelessWidget {
  const AppCollectionsPage({super.key, required this.app});

  final AppDataInfo app;

  Future<void> _openRecords(BuildContext context, CollectionInfo c) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CollectionRecordsPage(collection: c),
      ),
    );
    if (context.mounted) {
      context.read<HostConsoleController>().notifyDataChanged();
    }
  }

  Future<void> _onMenu(
    BuildContext context,
    CollectionInfo c,
    String action,
  ) async {
    switch (action) {
      case 'rename':
        await runCollectionRename(
          context,
          currentName: c.name,
          onChanged: () =>
              context.read<HostConsoleController>().notifyDataChanged(),
        );
      case 'delete':
        await runCollectionDelete(
          context,
          name: c.name,
          recordCount: c.recordCount,
          onChanged: () =>
              context.read<HostConsoleController>().notifyDataChanged(),
        );
      case 'open':
        await _openRecords(context, c);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HostConsoleController>(
      builder: (context, host, _) {
        final match = host.apps.where((a) => a.packageName == app.packageName);
        final latest = match.isEmpty ? app : match.first;
        final scheme = Theme.of(context).colorScheme;
        final text = Theme.of(context).textTheme;

        return ManagerScaffold(
          title: Text(packageLabel(latest.packageName)),
          body: ListView(
            padding: AppLayout.pagePadding,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latest.packageName,
                        style: text.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${latest.collectionCount} collections · '
                        '${latest.recordCount} records from this app',
                        style: text.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const AppSectionTitle('Collections'),
              if (latest.collections.isEmpty)
                const AppEmpty(
                  icon: Icons.folder_outlined,
                  message: 'This app has no collections in the database.',
                )
              else
                ...latest.collections.map(
                  (c) => Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: Icon(Icons.table_rows_outlined, color: scheme.primary),
                      title: Text(c.name),
                      subtitle: Text(
                        '${c.recordCount} records · ${formatEpochMillis(c.createdAt)}'
                        '${c.createdByPackage == latest.packageName ? '' : ' · ${packageLabel(c.createdByPackage)}'}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) => _onMenu(context, c, action),
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'open', child: Text('Open')),
                          const PopupMenuItem(value: 'rename', child: Text('Rename')),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete', style: TextStyle(color: scheme.error)),
                          ),
                        ],
                      ),
                      onTap: () => _openRecords(context, c),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
