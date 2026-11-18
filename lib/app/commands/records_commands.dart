import 'dart:convert';

import 'package:any/any.dart';
import '../models/records_view.dart';
import '../repositories/records_repository.dart';
import '../states/records_state.dart';
import '../utils/app_prefs.dart';

class StartRecordsWatchCommand extends Command {
  const StartRecordsWatchCommand();

  @override
  Future<void> call(Ref ref) async {
    final repo = ref.get<RecordsRepository>();
    final state = ref.of<RecordsState>();

    await pinnedClearAndLoad(ref, state, repo);

    repo.watch(
      (rows) {
        state.records = rows;
        state.initialLoading = false;
        state.watchError = null;
        final ids = rows.map((r) => r.id).toSet();
        state.selected.removeWhere((id) => !ids.contains(id));
        ref.call<RecordsState>((s) => s);
      },
      (error) {
        state.initialLoading = false;
        state.watchError = error.toString();
        ref.call<RecordsState>((s) => s);
      },
    );
  }
}

class StopRecordsWatchCommand extends Command {
  const StopRecordsWatchCommand();

  @override
  void call(Ref ref) {
    ref.get<RecordsRepository>().cancelWatch();
  }
}

Future<void> pinnedClearAndLoad(
  Ref ref,
  RecordsState state,
  RecordsRepository repo,
) async {
  final db = repo.database;
  state.pinned
    ..clear()
    ..addAll(await readStringSetPref(db.db, AppPrefs.pinsFor(state.collectionName)));
  try {
    final raw = await db.getPreference(AppPrefs.tagsFor(state.collectionName));
    if (raw != null) {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        state.tags.clear();
        decoded.forEach((key, value) {
          if (key is String && value is List) {
            state.tags[key] = value.whereType<String>().toSet();
          }
        });
      }
    }
  } catch (_) {}
  ref.call<RecordsState>((s) => s);
}

class SetRecordsQueryCommand extends Command {
  const SetRecordsQueryCommand(this.query);

  final String query;

  @override
  void call(Ref ref) {
    ref.call<RecordsState>((s) => s..query = query);
  }
}

class SetRecordsSortCommand extends Command {
  const SetRecordsSortCommand(this.sort);

  final RecordsSort sort;

  @override
  void call(Ref ref) {
    ref.call<RecordsState>((s) => s..sort = sort);
  }
}

class SetRecordsViewModeCommand extends Command {
  const SetRecordsViewModeCommand(this.mode);

  final RecordsViewMode mode;

  @override
  void call(Ref ref) {
    ref.call<RecordsState>((s) => s..viewMode = mode);
  }
}

class ToggleRecordSelectionCommand extends Command {
  const ToggleRecordSelectionCommand(this.id);

  final String id;

  @override
  void call(Ref ref) {
    ref.call<RecordsState>((s) {
      s.selected.contains(id) ? s.selected.remove(id) : s.selected.add(id);
      return s;
    });
  }
}

class ToggleSelectAllVisibleCommand extends Command {
  const ToggleSelectAllVisibleCommand();

  @override
  void call(Ref ref) {
    final s = ref.of<RecordsState>();
    if (s.allVisibleSelected) {
      ref.call<RecordsState>((st) {
        st.selected.removeAll(st.visibleRecords.map((r) => r.id));
        return st;
      });
    } else {
      ref.call<RecordsState>((st) {
        st.selected.addAll(st.visibleRecords.map((r) => r.id));
        return st;
      });
    }
  }
}

class ClearRecordSelectionCommand extends Command {
  const ClearRecordSelectionCommand();

  @override
  void call(Ref ref) {
    ref.call<RecordsState>((s) {
      s.selected.clear();
      s.selectMode = false;
      return s;
    });
  }
}

class SetRecordSelectModeCommand extends Command {
  const SetRecordSelectModeCommand(this.enabled);

  final bool enabled;

  @override
  void call(Ref ref) {
    ref.call<RecordsState>((s) {
      s.selectMode = enabled;
      if (!enabled) s.selected.clear();
      return s;
    });
  }
}

class TogglePinRecordCommand extends Command {
  const TogglePinRecordCommand(this.id);

  final String id;

  @override
  Future<void> call(Ref ref) async {
    final s = ref.of<RecordsState>();
    s.pinned.contains(id) ? s.pinned.remove(id) : s.pinned.add(id);
    ref.call<RecordsState>((st) => st);
    await writeStringSetPref(
      ref.get<RecordsRepository>().database.db,
      AppPrefs.pinsFor(s.collectionName),
      s.pinned,
    );
  }
}

class SetRecordTagsCommand extends Command {
  const SetRecordTagsCommand(this.id, this.values);

  final String id;
  final Set<String> values;

  @override
  Future<void> call(Ref ref) async {
    ref.call<RecordsState>((s) {
      if (values.isEmpty) {
        s.tags.remove(id);
      } else {
        s.tags[id] = {...values};
      }
      return s;
    });
    final s = ref.of<RecordsState>();
    final encoded = <String, List<String>>{};
    for (final e in s.tags.entries) {
      encoded[e.key] = e.value.toList()..sort();
    }
    await ref.get<RecordsRepository>().database.setPreference(
      AppPrefs.tagsFor(s.collectionName),
      jsonEncode(encoded),
    );
  }
}

class RenameRecordsCollectionCommand extends Command {
  const RenameRecordsCollectionCommand(this.name);

  final String name;

  @override
  Future<void> call(Ref ref) async {
    final s = ref.of<RecordsState>();
    if (name == s.collectionName) return;
    s.collectionName = name;
    s.records = [];
    s.selected.clear();
    s.pinned.clear();
    s.tags.clear();
    s.initialLoading = true;
    ref.call<RecordsState>((st) => st);
    const StopRecordsWatchCommand().call(ref);
    await const StartRecordsWatchCommand().call(ref);
  }
}

class DeleteSelectedRecordsCommand extends Command {
  const DeleteSelectedRecordsCommand();

  @override
  Future<void> call(Ref ref) async {
    final s = ref.of<RecordsState>();
    final repo = ref.get<RecordsRepository>();
    final ids = s.selected.toList();
    for (final id in ids) {
      await repo.removeById(id);
    }
    ref.call<RecordsState>((st) {
      st.selected.clear();
      st.selectMode = false;
      return st;
    });
  }
}