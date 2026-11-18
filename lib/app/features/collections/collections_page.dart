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
import '../../widgets/page_header.dart';
import '../collection/collection_page.dart';

enum _SortMode { name, records, recent }

/// Flat browser of every collection in the database, with search,
/// per-app filter and sorting.
class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key});

  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  String _query = '';
  String? _appFilter;
  _SortMode _sort = _SortMode.recent;

  List<CollectionInfo> _filtered(ConsoleState state) {
    var list = state.collections;
    if (_appFilter != null) {
      list = list.where((c) => c.createdByPackage == _appFilter).toList();
    }
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (c) =>
                c.name.toLowerCase().contains(q) ||
                c.createdByPackage.toLowerCase().contains(q),
          )
          .toList();
    }
    list = [...list];
    switch (_sort) {
      case _SortMode.name:
        list.sort((a, b) => a.name.compareTo(b.name));
      case _SortMode.records:
        list.sort((a, b) => b.recordCount.compareTo(a.recordCount));
      case _SortMode.recent:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.of<ConsoleState>();
    final list = _filtered(state);
    return Column(
          children: [
            const PageHeader(
              title: 'Collections',
              subtitle: 'Every table in the shared database',
            ),
            _Toolbar(
              query: _query,
              onQuery: (v) => setState(() => _query = v),
              appFilter: _appFilter,
              apps: state.apps,
              onAppFilter: (v) => setState(() => _appFilter = v),
              sort: _sort,
              onSort: (v) => setState(() => _sort = v),
              onCreate: () => runCollectionCreate(
                context,
                () => context.call(const ReloadConsoleCommand()),
              ),
            ),
            Expanded(
              child: state.loading && !state.hasData
                  ? const LoadingView(message: 'Loading collections…')
                  : state.error != null && !state.hasData
                      ? ErrorView(
                          message: state.error!,
                          onRetry: () => context.call(
                                const ReloadConsoleCommand(showSpinner: true),
                              ),
                        )
                      : list.isEmpty
                          ? EmptyState(
                              icon: Icons.search_off_rounded,
                              message: state.collections.isEmpty
                                  ? 'No collections yet.\nTap + to create one.'
                                  : 'No collections match your filters.',
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final wide = constraints.maxWidth >=
                                    AppLayout.compactBreakpoint;
                                if (wide) {
                                  return GridView.builder(
                                    padding: AppLayout.pagePadding,
                                    gridDelegate:
                                        const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 460,
                                      mainAxisSpacing: 8,
                                      crossAxisSpacing: 8,
                                      childAspectRatio: 3.4,
                                    ),
                                    itemCount: list.length,
                                    itemBuilder: (context, i) =>
                                        _CollectionCard(collection: list[i]),
                                  );
                                }
                                return ListView.builder(
                                  padding: AppLayout.pagePadding,
                                  itemCount: list.length,
                                  itemBuilder: (context, i) =>
                                      _CollectionCard(collection: list[i]),
                                );
                              },
                            ),
            ),
          ],
        );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.query,
    required this.onQuery,
    required this.appFilter,
    required this.apps,
    required this.onAppFilter,
    required this.sort,
    required this.onSort,
    required this.onCreate,
  });

  final String query;
  final ValueChanged<String> onQuery;
  final String? appFilter;
  final List<AppDataInfo> apps;
  final ValueChanged<String?> onAppFilter;
  final _SortMode sort;
  final ValueChanged<_SortMode> onSort;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Filter collections…',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
                isDense: true,
              ),
              onChanged: onQuery,
            ),
          ),
          _FilterDropdown<String?>(
            hint: 'All apps',
            value: appFilter,
            options: [
              (null, 'All apps'),
              for (final a in apps)
                (a.packageName, packageLabel(a.packageName)),
            ],
            onChanged: onAppFilter,
          ),
          _FilterDropdown<_SortMode>(
            hint: 'Sort',
            value: sort,
            options: const [
              (_SortMode.recent, 'Recent'),
              (_SortMode.name, 'Name'),
              (_SortMode.records, 'Most records'),
            ],
            onChanged: (v) => v == null ? null : onSort(v),
          ),
          IconButton.filledTonal(
            tooltip: 'New collection',
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.collection});

  final CollectionInfo collection;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CollectionPage(collection: collection),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.table_rows_outlined,
                      size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      collection.name,
                      style: text.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _Badge('${collection.recordCount}'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                packageLabel(collection.createdByPackage),
                style: text.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                formatEpochMillis(collection.createdAt),
                style: text.bodySmall?.copyWith(
                  color: scheme.outline,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

/// Rounded, bordered picker matching the text-field inputs.
class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.hint,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String hint;
  final T? value;
  final List<(T?, String)> options;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final selected = options
        .where((o) => o.$1 == value)
        .map((o) => o.$2)
        .firstOrNull;

    return PopupMenuButton<T?>(
      tooltip: hint,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final o in options)
          PopupMenuItem<T?>(
            value: o.$1,
            child: Row(
              children: [
                if (o.$1 == value)
                  Icon(Icons.check_rounded,
                      size: 16, color: scheme.primary)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Flexible(child: Text(o.$2)),
              ],
            ),
          ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                selected ?? hint,
                style: text.bodyMedium?.copyWith(
                  color: selected == null
                      ? scheme.onSurfaceVariant
                      : scheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 20, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
