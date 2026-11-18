import 'dart:convert';

import 'package:any/any.dart';
import '../models/records_view.dart';
import '../repositories/records_repository.dart';
import '../states/records_state.dart';
import '../models/app_prefs.dart';
import 'ref_mutate.dart';

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
        ref.touch<RecordsState>();
      },
      (error) {
        state.initialLoading = false;
        state.watchError = error.toString();
        ref.touch<RecordsState>();
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
  final prefs = repo.preferences;
  final pinKey = AppPrefs.pinsFor(state.collectionName);
  state.pinned
    ..clear()
    ..addAll(await prefs.readStringSet(pinKey));
  try {
    final raw = await prefs.get(AppPrefs.tagsFor(state.collectionName));
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
  ref.touch<RecordsState>();
}

class SetRecordsQueryCommand extends Command {
  const SetRecordsQueryCommand(this.query);

  final String query;

  @override
  void call(Ref ref) {
    ref.mutate<RecordsState>((s) => s.query = query);
  }
}

class SetRecordsSortCommand extends Command {
  const SetRecordsSortCommand(this.sort);

  final RecordsSort sort;

  @override
  void call(Ref ref) {
    ref.mutate<RecordsState>((s) => s.sort = sort);
  }
}

class SetRecordsViewModeCommand extends Command {
  const SetRecordsViewModeCommand(this.mode);

  final RecordsViewMode mode;

  @override
  void call(Ref ref) {
    ref.mutate<RecordsState>((s) => s.viewMode = mode);
  }
}

class ToggleRecordSelectionCommand extends Command {
  const ToggleRecordSelectionCommand(this.id);

  final String id;

  @override
  void call(Ref ref) {
    ref.mutate<RecordsState>((s) {
      s.selected.contains(id) ? s.selected.remove(id) : s.selected.add(id);
    });
  }
}

class ToggleSelectAllVisibleCommand extends Command {
  const ToggleSelectAllVisibleCommand();

  @override
  void call(Ref ref) {
    final s = ref.of<RecordsState>();
    if (s.allVisibleSelected) {
      ref.mutate<RecordsState>(
        (st) => st.selected.removeAll(st.visibleRecords.map((r) => r.id)),
      );
    } else {
      ref.mutate<RecordsState>(
        (st) => st.selected.addAll(st.visibleRecords.map((r) => r.id)),
      );
    }
  }
}

class ClearRecordSelectionCommand extends Command {
  const ClearRecordSelectionCommand();

  @override
  void call(Ref ref) {
    ref.mutate<RecordsState>((s) {
      s.selected.clear();
      s.selectMode = false;
    });
  }
}

class SetRecordSelectModeCommand extends Command {
  const SetRecordSelectModeCommand(this.enabled);

  final bool enabled;

  @override
  void call(Ref ref) {
    ref.mutate<RecordsState>((s) {
      s.selectMode = enabled;
      if (!enabled) s.selected.clear();
    });
  }
}

class TogglePinRecordCommand extends Command {
  const TogglePinRecordCommand(this.id);

  final String id;

  @override
  Future<void> call(Ref ref) async {
    final s = ref.of<RecordsState>();
    ref.mutate<RecordsState>((st) {
      st.pinned.contains(id) ? st.pinned.remove(id) : st.pinned.add(id);
    });
    final repo = ref.get<RecordsRepository>();
    await repo.preferences.writeStringSet(
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
    ref.mutate<RecordsState>((s) {
      if (values.isEmpty) {
        s.tags.remove(id);
      } else {
        s.tags[id] = {...values};
      }
    });
    final s = ref.of<RecordsState>();
    final encoded = <String, List<String>>{};
    for (final e in s.tags.entries) {
      encoded[e.key] = e.value.toList()..sort();
    }
    await ref.get<RecordsRepository>().preferences.set(
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
    if (name == ref.of<RecordsState>().collectionName) return;
    ref.mutate<RecordsState>((s) {
      s.collectionName = name;
      s.records = [];
      s.selected.clear();
      s.pinned.clear();
      s.tags.clear();
      s.initialLoading = true;
    });
    const StopRecordsWatchCommand().call(ref);
    await const StartRecordsWatchCommand().call(ref);
  }
}

class SaveRecordCommand extends Command {
  const SaveRecordCommand(this.data, {this.id, this.recordId});

  final Map<String, dynamic> data;
  final String? id;
  final String? recordId;

  @override
  Future<void> call(Ref ref) async {
    final explicitId = recordId ?? (id == null || id!.isEmpty ? null : id);
    final newId =
        await ref.get<RecordsRepository>().put(data, id: explicitId);
    ref.mutate<RecordsState>((s) => s.lastPutId = newId);
  }
}

class DeleteRecordCommand extends Command {
  const DeleteRecordCommand(this.id);

  final String id;

  @override
  Future<void> call(Ref ref) async {
    await ref.get<RecordsRepository>().removeById(id);
  }
}

class DuplicateRecordCommand extends Command {
  const DuplicateRecordCommand(this.data);

  final Map<String, dynamic> data;

  @override
  Future<void> call(Ref ref) async {
    final newId = await ref
        .get<RecordsRepository>()
        .put(Map<String, dynamic>.from(data));
    ref.mutate<RecordsState>((s) => s.lastPutId = newId);
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
    ref.mutate<RecordsState>((st) {
      st.selected.clear();
      st.selectMode = false;
    });
  }
}