import 'package:any/any.dart';
import 'package:flutter/material.dart';
import 'package:shared_database/shared_database.dart';

import '../../commands/navigation_commands.dart';
import '../../commands/collection_flow_commands.dart';
import '../collections/collection_file_actions.dart';
import '../../states/console_state.dart';
import '../shell/app_theme.dart';
import '../../models/date_format.dart';
import '../../models/package_label.dart';
import '../widgets/widgets.dart';

/// Collections belonging to one app (package). Pushed as a route.
class AppCollectionsScreen extends StatelessWidget {
  const AppCollectionsScreen({super.key, required this.packageName});

  final String packageName;

  void _openRecords(BuildContext context, CollectionInfo c) {
    context.call(PushCollectionRouteCommand(c));
  }

  Future<void> _onMenu(
    BuildContext context,
    CollectionInfo c,
    String action,
  ) async {
    switch (action) {
      case 'rename':
        context.call(ShowRenameCollectionPromptCommand(c.name));
      case 'delete':
        context.call(
          ShowDeleteCollectionConfirmCommand(
            name: c.name,
            recordCount: c.recordCount,
          ),
        );
      case 'export':
        await runCollectionExport(context, collection: c.name);
      case 'open':
        _openRecords(context, c);
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
        onPressed: () =>
            context.call(const ShowCreateCollectionPromptCommand()),
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('Collection'),
      ),
      body: ListView(
        padding: AppLayout.pagePaddingFab,
        children: [
          LiquidCard(
            padding: const EdgeInsets.all(16),
            accent: appAccent(packageName),
            featured: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  packageName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
          const SectionTitle('Collections'),
          if (collections.isEmpty)
            const EmptyState(
              icon: Icons.folder_off_outlined,
              message: 'This app has no collections.',
            )
          else
            for (final c in collections)
              LiquidCard(
                padding: EdgeInsets.zero,
                accent: appAccent(c.createdByPackage),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    Icons.table_rows_outlined,
                    color: scheme.primary,
                  ),
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
                      PopupMenuItem(value: 'rename', child: Text('Rename')),
                      PopupMenuItem(
                        value: 'export',
                        child: Text('Export JSON'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
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