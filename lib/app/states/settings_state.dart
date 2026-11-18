import 'package:flutter/material.dart';
import 'package:shared_database/shared_database.dart';

/// Theme mode and poll interval — mutable for quick UI updates.
class SettingsState {
  SettingsState({
    this.themeMode = ThemeMode.system,
    this.watchInterval = SharedDatabase.defaultWatchInterval,
    this.loaded = false,
  });

  ThemeMode themeMode;
  Duration watchInterval;
  bool loaded;
}