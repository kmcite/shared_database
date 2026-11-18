import 'package:flutter/material.dart';

import '../features/backup/backup_page.dart';
import '../features/collections/collections_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/preferences/preferences_page.dart';
import '../features/search/search_page.dart';
import '../features/settings/settings_page.dart';

/// Main shell tabs — [index] matches [PageView] order.
enum ShellTab {
  overview(
    0,
    'Overview',
    Icons.dashboard_outlined,
    Icons.dashboard_rounded,
  ),
  collections(
    1,
    'Collections',
    Icons.folder_outlined,
    Icons.folder_rounded,
  ),
  search(2, 'Search', Icons.search_rounded, Icons.search_rounded),
  preferences(
    3,
    'Preferences',
    Icons.tune_outlined,
    Icons.tune_rounded,
  ),
  backup(4, 'Backup', Icons.backup_outlined, Icons.backup_rounded),
  settings(
    5,
    'Settings',
    Icons.settings_outlined,
    Icons.settings_rounded,
  );

  const ShellTab(
    this.tabIndex,
    this.label,
    this.icon,
    this.selectedIcon,
  );

  final int tabIndex;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  static ShellTab? at(int index) {
    for (final t in values) {
      if (t.tabIndex == index) return t;
    }
    return null;
  }

  static const List<Widget> pages = [
    DashboardPage(),
    CollectionsPage(),
    SearchPage(),
    PreferencesPage(),
    BackupPage(),
    SettingsPage(),
  ];
}