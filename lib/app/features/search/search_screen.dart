import 'dart:async';

import 'package:flutter/material.dart';
import 'package:any/any.dart';

import '../../commands/search_commands.dart';
import '../../states/console_state.dart';
import '../../states/search_state.dart';
import '../shell/app_theme.dart';
import '../../models/package_label.dart';
import '../widgets/widgets.dart';
import '../../commands/navigation_commands.dart';

/// Global search across every collection's record ids and JSON content.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  int _runId = 0;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQuery(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() => _query = value.trim());
      _runSearch();
    });
  }

  Future<void> _runSearch() async {
    final runId = ++_runId;
    await context.call(SearchRecordsCommand(_query, runId));
  }

  void _openHit(SearchHit hit) {
    final info = context
        .read<ConsoleState>()
        .collectionByName(hit.collection);
    if (info != null) {
      context.call(
        PushCollectionRouteCommand(
          info,
          focusRecordId: hit.record.id,
        ),
      );
    } else {
      context.call(
        PushCollectionByNameRouteCommand(
          name: hit.collection,
          focusRecordId: hit.record.id,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final search = context.of<SearchState>();
    final hits = search.hits;
    final searching = search.searching;
    final progress = search.progress;
    final perCollection = search.perCollection;
    return Column(
      children: [
        const ScreenHeader(
          title: 'Search',
          subtitle: 'Find records across every collection',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search all records…',
              prefixIcon: const Icon(Icons.search_rounded, size: 22),
              suffixIcon: searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _controller.clear();
                            _onQuery('');
                          },
                        ),
            ),
            onChanged: _onQuery,
            onSubmitted: (v) {
              _debounce?.cancel();
              setState(() => _query = v.trim());
              _runSearch();
            },
          ),
        ),
        if (progress != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              progress,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
        if (_query.isNotEmpty && !searching)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '${hits.length} result(s) in '
                  '${perCollection.length} collection(s)',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
          ),
        Expanded(
          child: hits.isEmpty && _query.isNotEmpty && !searching
              ? const EmptyState(
                  icon: Icons.travel_explore_outlined,
                  message: 'Nothing matched.\nTry a different term.',
                )
              : _query.isEmpty
                  ? const EmptyState(
                      icon: Icons.manage_search_rounded,
                      message: 'Type to search record ids and JSON content\n'
                          'across every collection.',
                    )
                  : ListView.builder(
                      padding: AppLayout.pagePadding,
                      itemCount: hits.length,
                      itemBuilder: (context, i) {
                        final hit = hits[i];
                        return LiquidCard(
                          padding: EdgeInsets.zero,
                          accent: scheme.primary,
                          onTap: () => _openHit(hit),
                          child: ListTile(
                            leading: Icon(Icons.description_outlined,
                                color: scheme.primary),
                            title: Text(
                              hit.record.id,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${hit.collection} · '
                              '${packageLabel(_ownerOf(hit.collection))}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing:
                                const Icon(Icons.chevron_right_rounded),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  String _ownerOf(String collection) {
    return context
            .read<ConsoleState>()
            .collectionByName(collection)
            ?.createdByPackage ??
        '';
  }
}