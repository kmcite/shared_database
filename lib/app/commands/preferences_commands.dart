import 'package:any/any.dart';

import '../repositories/database_repository.dart';
import '../states/preferences_state.dart';

class ReloadPreferencesCommand extends Command {
  const ReloadPreferencesCommand();

  @override
  Future<void> call(Ref ref) async {
    final current = ref.of<PreferencesState>();
    ref.call<PreferencesState>(
      (_) => current.copyWith(loading: current.keys.isEmpty),
    );
    try {
      final keys = await ref.get<DatabaseRepository>().preferenceKeys();
      ref.call<PreferencesState>(
        (_) => current.copyWith(
          keys: keys,
          loading: false,
          clearError: true,
        ),
      );
    } catch (e) {
      ref.call<PreferencesState>(
        (_) => current.copyWith(
          error: e.toString(),
          loading: false,
        ),
      );
    }
  }
}

class SetPreferenceCommand extends Command {
  const SetPreferenceCommand(this.key, this.value);

  final String key;
  final String value;

  @override
  Future<void> call(Ref ref) async {
    await ref.get<DatabaseRepository>().setPreference(key, value);
    final current = ref.of<PreferencesState>();
    if (!current.keys.contains(key)) {
      ref.call<PreferencesState>(
        (_) => current.copyWith(keys: [...current.keys, key]..sort()),
      );
    }
  }
}

class RemovePreferenceCommand extends Command {
  const RemovePreferenceCommand(this.key);

  final String key;

  @override
  Future<void> call(Ref ref) async {
    await ref.get<DatabaseRepository>().removePreference(key);
    final current = ref.of<PreferencesState>();
    ref.call<PreferencesState>(
      (_) => current.copyWith(
        keys: current.keys.where((k) => k != key).toList(),
      ),
    );
  }
}