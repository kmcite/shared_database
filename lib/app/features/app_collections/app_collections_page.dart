import 'package:flutter/material.dart';
import 'package:any/any.dart';
import 'package:shared_database/shared_database.dart';

import '../../commands/console_commands.dart';
import '../../dialogs/collection_ops.dart';
import '../../states/console_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/date_format.dart';
import '../../utils/package_label.dart';
import '../../widgets/common.dart';
import '../collection/collection_page.dart';

/// Collections belonging to one app (package). Pushed as a route.
class AppCollectionsPage extends StatelessWidget {
  const AppCollectionsPage({super.key, required this.packageName});

  final String packageName;

  Future<void> _openRecords(BuildContext context, CollectionInfo c) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CollectionPage(collection: c),
      ),
    );
    if (context.mounted) {
      context.call(const ReloadConsoleCommand());
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
          onChanged: () => context.call(const ReloadConsoleCommand()),
        );
      case 'delete':
        final deleted = await runCollectionDelete(
          context,
          name: c.name,
          recordCount: c.recordCount,
          onChanged: () => context.call(const ReloadConsoleCommand()),
        );
        if (deleted && context.mounted) Navigator.of(context).pop();
      case 'export':
        await runCollectionExport(context, collection: c.name);
      case 'open':
        await _openRecords(context, c);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.of<ConsoleState>();
        final app = state.apps
            .where((a) => a.packageName == packageName)
            .firstOrNull;
        final collections = app?.collections ?? const <CollectionInfo>[];
        final scheme = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(title: Text(packageLabel(packageName))),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => runCollectionCreate(
              context,
              () => context.call(const ReloadConsoleCommand()),
            ),
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('Collection'),
          ),
          body: ListView(
            padding: AppLayout.pagePaddingFab,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        packageName,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              fontFamily: 'monospace',
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${app?.collectionCount ?? collections.length} '
                        'collections · ${app?.recordCount ?? 0} records',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SectionTitle('Collections'),
              if (collections.isEmpty)
                const EmptyState(
                  icon: Icons.folder_off_outlined,
                  message: 'This app has no collections.',
                )
              else
                for (final c in collections)
                  Card(
                    clipBehavior: Clip.antiAlias,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(Icons.table_rows_outlined,
                          color: scheme.primary),
                      title: Text(c.name),
                      subtitle: Text(
                        '${c.recordCount} records · '
                        '${formatEpochMillis(c.createdAt)}'
                        '${c.createdByPackage == packageName ? '' : ' · ${packageLabel(c.createdByPackage)}'}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) => _onMenu(context, c, action),
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'open', child: Text('Open')),
                          PopupMenuItem(
                              value: 'rename', child: Text('Rename')),
                          PopupMenuItem(
                              value: 'export', child: Text('Export JSON')),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                      onTap: () => _openRecords(context, c),
                    ),
                  ),
            ],
          ),
        );
  }
}
