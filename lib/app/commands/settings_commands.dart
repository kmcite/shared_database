import 'package:any/any.dart';
import 'package:flutter/material.dart';

import '../repositories/database_repository.dart';
import '../states/settings_state.dart';
import '../theme/app_theme.dart';
import '../utils/app_prefs.dart';
class LoadSettingsCommand extends Command {
  const LoadSettingsCommand();

  @override
  Future<void> call(Ref ref) async {
    final db = ref.get<DatabaseRepository>();
    final state = ref.of<SettingsState>();
    try {
      final modeRaw = await db.getPreference(AppPrefs.themeMode);
      state.themeMode = switch (modeRaw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      final seedRaw = await db.getPreference(AppPrefs.accentSeed);
      if (seedRaw != null) {
        final value = int.tryParse(seedRaw.replaceFirst('#', '0xFF'));
        if (value != null) {
          state.accent = AppAccent.fromSeed(Color(value));
        }
      }
      final intervalRaw = await db.getPreference(AppPrefs.watchIntervalMs);
      final ms = int.tryParse(intervalRaw ?? '');
      if (ms != null && ms >= 500) {
        state.watchInterval = Duration(milliseconds: ms);
      }
    } catch (_) {}
    state.loaded = true;
    ref.call<SettingsState>((s) => s);
  }
}

class SetThemeModeCommand extends Command {
  const SetThemeModeCommand(this.mode);

  final ThemeMode mode;

  @override
  Future<void> call(Ref ref) async {
    final state = ref.of<SettingsState>();
    state.themeMode = mode;
    ref.call<SettingsState>((s) => s);
    final raw = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await ref.get<DatabaseRepository>().setPreference(AppPrefs.themeMode, raw);
  }
}

class SetAccentCommand extends Command {
  const SetAccentCommand(this.accent);

  final AppAccent accent;

  @override
  Future<void> call(Ref ref) async {
    final state = ref.of<SettingsState>();
    state.accent = accent;
    ref.call<SettingsState>((s) => s);
    await ref.get<DatabaseRepository>().setPreference(
      AppPrefs.accentSeed,
      '#${accent.seed.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
    );
  }
}

class SetWatchIntervalCommand extends Command {
  const SetWatchIntervalCommand(this.interval);

  final Duration interval;

  @override
  Future<void> call(Ref ref) async {
    final state = ref.of<SettingsState>();
    state.watchInterval = interval;
    ref.call<SettingsState>((s) => s);
    await ref.get<DatabaseRepository>().setPreference(
      AppPrefs.watchIntervalMs,
      '${interval.inMilliseconds}',
    );
  }
}