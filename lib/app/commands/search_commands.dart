import 'package:any/any.dart';
import 'package:shared_database/shared_database.dart';

import '../repositories/database_repository.dart';
import '../models/json_format.dart';
import '../states/console_state.dart';
import '../states/search_state.dart';
import 'ref_mutate.dart';

class SearchRecordsCommand extends Command {
  const SearchRecordsCommand(this.query, this.runId);

  final String query;
  final int runId;

  @override
  Future<void> call(Ref ref) async {
    final q = query.trim().toLowerCase();

    if (q.isEmpty) {
      ref.mutate<SearchState>((s) {
        s.runId = runId;
        s.searching = false;
        s.progress = null;
        s.hits = [];
        s.perCollection = {};
      });
      return;
    }

    final collections = ref.of<ConsoleState>().collections;
    ref.mutate<SearchState>((s) {
      s.runId = runId;
      s.searching = true;
      s.hits = [];
      s.perCollection = {};
      s.progress = 'Searching 0/${collections.length} collections…';
    });

    final repo = ref.get<DatabaseRepository>();
    final hits = <SearchHit>[];
    final perCollection = <String, int>{};
    var done = 0;
    for (final c in collections) {
      if (ref.of<SearchState>().runId != runId) return;
      try {
        final rows = await repo.collections.getAllRecords(c.name);
        for (final r in rows) {
          if (_matches(r, q)) {
            hits.add(SearchHit(collection: c.name, record: r));
            perCollection[c.name] = (perCollection[c.name] ?? 0) + 1;
          }
        }
      } catch (_) {
        // Skip unreadable collections.
      }
      done++;
      if (ref.of<SearchState>().runId != runId) return;
      ref.mutate<SearchState>(
        (s) => s.progress = 'Searching $done/${collections.length}…',
      );
    }

    if (ref.of<SearchState>().runId != runId) return;
    ref.mutate<SearchState>((s) {
      s.searching = false;
      s.progress = null;
      s.hits = hits;
      s.perCollection = perCollection;
    });
  }
}

bool _matches(SharedRecord r, String q) {
  if (r.id.toLowerCase().contains(q)) return true;
  final buffer = StringBuffer();
  collectSearchableText(r.data, buffer.write);
  return buffer.toString().toLowerCase().contains(q);
}