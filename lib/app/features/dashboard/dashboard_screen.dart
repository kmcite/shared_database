import 'package:flutter/material.dart';
import 'package:any/any.dart';
import '../../commands/console_commands.dart';
import '../../commands/collection_flow_commands.dart';
import '../../states/console_state.dart';
import '../shell/app_theme.dart';
import '../widgets/widgets.dart';
import '../../models/shell_tab.dart';
import '../shell/app_shell.dart';
import 'apps_overview_section.dart';
import 'recent_collections_section.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.of<ConsoleState>();
    if (state.loading && !state.hasData) {
      return const LoadingView(message: 'Loading database…');
    }
    if (state.error != null && !state.hasData) {
      return ErrorView(
        message: state.error!,
        onRetry: () =>
            context.call(const ReloadConsoleCommand(showSpinner: true)),
      );
    }
    if (!state.hasData) {
      return const LoadingView();
    }
    return _DashboardBody(state: state);
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.state});

  final ConsoleState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        const ScreenHeader(
          title: 'Overview',
          subtitle: 'Live view of everything in the shared database',
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                context.call(const ReloadConsoleCommand(showSpinner: true)),
            child: ListView(
              padding: AppLayout.pagePadding,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= AppLayout.wideBreakpoint
                  ? 4
                  : constraints.maxWidth >= AppLayout.compactBreakpoint
                      ? 2
                      : 2;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.3,
                children: [
                  StatTile(
                    icon: Icons.apps_rounded,
                    label: 'Apps',
                    value: '${state.apps.length}',
                    subtitle: 'writing to this database',
                    accent: scheme.primary,
                  ),
                  StatTile(
                    icon: Icons.folder_rounded,
                    label: 'Collections',
                    value: '${state.collectionCount}',
                    subtitle: 'tables of records',
                    accent: scheme.secondary,
                  ),
                  StatTile(
                    icon: Icons.description_rounded,
                    label: 'Records',
                    value: '${state.recordCount}',
                    subtitle: 'JSON documents',
                    accent: scheme.tertiary,
                  ),
                  StatTile(
                    icon: Icons.tune_rounded,
                    label: 'Preferences',
                    value: '${state.preferenceCount}',
                    subtitle: 'shared key/value pairs',
                    accent: scheme.error,
                  ),
                ],
              );
            },
          ),
          SectionTitle(
            'Apps',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state.apps.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '${state.apps.length} writers',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                const ShellTabMarker(
                  tab: ShellTab.collections,
                  label: 'By app',
                  compact: true,
                ),
              ],
            ),
          ),
          AppsOverviewSection(
            apps: state.apps,
            totalRecords: state.recordCount,
          ),
          const SizedBox(height: 8),
          SectionTitle(
            'Recent collections',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ShellTabMarker(
                  tab: ShellTab.collections,
                  label: 'All tables',
                  compact: true,
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'New collection',
                  onPressed: () =>
                      context.call(const ShowCreateCollectionPromptCommand()),
                  icon: const Icon(Icons.add_rounded),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          RecentCollectionsSection(
            collections: state.recentCollections,
            totalRecords: state.recordCount,
          ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

