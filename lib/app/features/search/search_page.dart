import 'dart:async';

import 'package:flutter/material.dart';
import 'package:any/any.dart';
import 'package:shared_database/shared_database.dart';

import '../../states/console_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/json_format.dart';
import '../../utils/package_label.dart';
import '../../widgets/common.dart';
import '../../widgets/page_header.dart';
import '../collection/collection_page.dart';

class _SearchHit {
  const _SearchHit({required this.collection, required this.record});

  final String collection;
  final SharedRecord record;
}

/// Global search across every collection's record ids and JSON content.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  int _runId = 0;

  String _query = '';
  bool _searching = false;
  String? _progress;
  List<_SearchHit> _hits = const [];
  Map<String, int> _perCollection = const {};

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQuery(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _query = value.trim();
      _runSearch();
    });
  }

  Future<void> _runSearch() async {
    final runId = ++_runId;
    final q = _query.toLowerCase();
    if (q.isEmpty) {
      setState(() {
        _hits = const [];
        _perCollection = const {};
        _searching = false;
        _progress = null;
      });
      return;
    }
    final db = SharedDatabase.instance;
    final collections =
        context.read<ConsoleState>().collections;
    setState(() {
      _searching = true;
      _hits = const [];
      _perCollection = const {};
      _progress = 'Searching 0/${collections.length} collections…';
    });

    final hits = <_SearchHit>[];
    final perCollection = <String, int>{};
    var done = 0;
    for (final c in collections) {
      if (runId != _runId || !mounted) return;
      try {
        final rows = await db.getAll(c.name);
        for (final r in rows) {
          if (_matches(r, q)) {
            hits.add(_SearchHit(collection: c.name, record: r));
            perCollection[c.name] = (perCollection[c.name] ?? 0) + 1;
          }
        }
      } catch (_) {
        // Skip unreadable collections.
      }
      done++;
      if (mounted && runId == _runId) {
        setState(() => _progress = 'Searching $done/${collections.length}…');
      }
    }
    if (!mounted || runId != _runId) return;
    setState(() {
      _hits = hits;
      _perCollection = perCollection;
      _searching = false;
      _progress = null;
    });
  }

  bool _matches(SharedRecord r, String q) {
    if (r.id.toLowerCase().contains(q)) return true;
    final buffer = StringBuffer();
    collectSearchableText(r.data, buffer.write);
    return buffer.toString().toLowerCase().contains(q);
  }

  void _openHit(_SearchHit hit) {
    final info = context
        .read<ConsoleState>()
        .collectionByName(hit.collection);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CollectionPage(
          collection: info ??
              CollectionInfo(
                name: hit.collection,
                createdAt: 0,
                createdByPackage: '',
                recordCount: 0,
              ),
          focusRecordId: hit.record.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        const PageHeader(
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
              suffixIcon: _searching
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
              _query = v.trim();
              _runSearch();
            },
          ),
        ),
        if (_progress != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _progress!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
        if (_query.isNotEmpty && !_searching)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '${_hits.length} result(s) in '
                  '${_perCollection.length} collection(s)',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
          ),
        Expanded(
          child: _hits.isEmpty && _query.isNotEmpty && !_searching
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
                      itemCount: _hits.length,
                      itemBuilder: (context, i) {
                        final hit = _hits[i];
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          margin: const EdgeInsets.only(bottom: 8),
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
                            onTap: () => _openHit(hit),
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
