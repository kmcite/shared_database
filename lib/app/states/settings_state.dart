import 'package:flutter/material.dart';
import 'package:shared_database/shared_database.dart';

import '../theme/app_theme.dart';

/// Theme mode, accent, and poll interval — mutable for quick UI updates.
class SettingsState {
  SettingsState({
    this.themeMode = ThemeMode.system,
    this.accent = AppAccent.teal,
    this.watchInterval = SharedDatabase.defaultWatchInterval,
    this.loaded = false,
  });

  ThemeMode themeMode;
  AppAccent accent;
  Duration watchInterval;
  bool loaded;
}