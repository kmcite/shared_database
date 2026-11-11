import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_database/shared_database.dart';

import '../dialogs/manager_editors.dart';
import '../state/host_console_controller.dart';
import '../theme/app_theme.dart';
import '../util/package_label.dart';
import '../widgets/app_empty.dart';
import '../widgets/host_error_view.dart';
import '../widgets/host_loading_view.dart';
import '../widgets/host_shell.dart';
import 'app_collections_page.dart';

class HostConsolePage extends StatelessWidget {
  const HostConsolePage({super.key});

  Future<void> _openApp(BuildContext context, AppDataInfo app) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AppCollectionsPage(app: app),
      ),
    );
    if (context.mounted) {
      context.read<HostConsoleController>().notifyDataChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return ManagerScaffold(
      showHostPill: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => runCollectionCreate(
          context,
          () => context.read<HostConsoleController>().notifyDataChanged(),
        ),
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('Collection'),
      ),
      body: Consumer<HostConsoleController>(
        builder: (context, host, _) {
          if (host.initialLoading && !host.hasData) {
            return const HostLoadingView(message: 'Loading apps…');
          }
          if (host.error != null && !host.hasData) {
            return HostErrorView(
              message: host.error!,
              onRetry: () => host.reload(showSpinner: true),
            );
          }
          if (!host.hasData) {
            return const HostLoadingView(message: 'Loading apps…');
          }

          final overview = host.overview!;

          return ListView(
            padding: AppLayout.pagePaddingFab,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Shared database', style: text.titleLarge),
                      const SizedBox(height: 8),
                      Text(
                        '${host.apps.length} apps · '
                        '${overview.collectionCount} collections · '
                        '${overview.recordCount} records',
                        style: text.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        overview.hostPackage,
                        style: text.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const AppSectionTitle('Apps'),
              if (host.apps.isEmpty)
                const AppEmpty(
                  icon: Icons.apps_outlined,
                  message:
                      'No app has written data yet.\n'
                      'Create a collection, or open a client that uses SharedDatabase.',
                )
              else
                ...host.apps.map(
                  (app) => Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: scheme.primaryContainer,
                        foregroundColor: scheme.onPrimaryContainer,
                        child: Text(packageInitial(app.packageName)),
                      ),
                      title: Text(packageLabel(app.packageName)),
                      subtitle: Text(
                        '${app.collectionCount} collections · ${app.recordCount} records\n'
                        '${app.packageName}',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openApp(context, app),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
