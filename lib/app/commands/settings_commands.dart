import 'package:any/any.dart';
import 'package:flutter/material.dart';

import '../repositories/database_repository.dart';
import '../states/settings_state.dart';
import '../models/app_prefs.dart';
import 'ref_mutate.dart';

class LoadSettingsCommand extends Command {
  const LoadSettingsCommand();

  @override
  Future<void> call(Ref ref) async {
    final prefs = ref.get<DatabaseRepository>().preferences;
    try {
      final modeRaw = await prefs.get(AppPrefs.themeMode);
      final intervalRaw = await prefs.get(AppPrefs.watchIntervalMs);
      ref.mutate<SettingsState>((s) {
        s.themeMode = switch (modeRaw) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        };
        final ms = int.tryParse(intervalRaw ?? '');
        if (ms != null && ms >= 500) {
          s.watchInterval = Duration(milliseconds: ms);
        }
        s.loaded = true;
      });
    } catch (_) {
      ref.mutate<SettingsState>((s) => s.loaded = true);
    }
  }
}

class SetThemeModeCommand extends Command {
  const SetThemeModeCommand(this.mode);

  final ThemeMode mode;

  @override
  Future<void> call(Ref ref) async {
    ref.mutate<SettingsState>((s) => s.themeMode = mode);
    final raw = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await ref.get<DatabaseRepository>().preferences.set(AppPrefs.themeMode, raw);
  }
}

class SetWatchIntervalCommand extends Command {
  const SetWatchIntervalCommand(this.interval);

  final Duration interval;

  @override
  Future<void> call(Ref ref) async {
    ref.mutate<SettingsState>((s) => s.watchInterval = interval);
    await ref.get<DatabaseRepository>().preferences.set(
      AppPrefs.watchIntervalMs,
      '${interval.inMilliseconds}',
    );
  }
}