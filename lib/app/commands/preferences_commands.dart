import 'package:any/any.dart';

import '../repositories/database_repository.dart';
import '../states/preferences_state.dart';
import 'ref_mutate.dart';

class ReloadPreferencesCommand extends Command {
  const ReloadPreferencesCommand();

  @override
  Future<void> call(Ref ref) async {
    ref.mutate<PreferencesState>((s) {
      if (s.keys.isEmpty) s.loading = true;
    });
    try {
      final prefs = ref.get<DatabaseRepository>().preferences;
      final keys = await prefs.keys();
      final values = await prefs.readAll();
      ref.mutate<PreferencesState>((s) {
        s.keys = keys;
        s.values = values;
        s.loading = false;
        s.error = null;
      });
    } catch (e) {
      ref.mutate<PreferencesState>((s) {
        s.error = e.toString();
        s.loading = false;
      });
    }
  }
}

class SetPreferenceCommand extends Command {
  const SetPreferenceCommand(this.key, this.value);

  final String key;
  final String value;

  @override
  Future<void> call(Ref ref) async {
    await ref.get<DatabaseRepository>().preferences.set(key, value);
    ref.mutate<PreferencesState>((s) {
      if (!s.keys.contains(key)) {
        s.keys = [...s.keys, key]..sort();
      }
      s.values[key] = value;
    });
  }
}

class RemovePreferenceCommand extends Command {
  const RemovePreferenceCommand(this.key);

  final String key;

  @override
  Future<void> call(Ref ref) async {
    await ref.get<DatabaseRepository>().preferences.remove(key);
    ref.mutate<PreferencesState>((s) {
      s.keys = s.keys.where((k) => k != key).toList();
      s.values.remove(key);
    });
  }
}