/// Preference keys used by the Database app itself (dogfooding the API).
abstract final class AppPrefs {
  static const themeMode = 'dbui.theme_mode'; // system | light | dark
  static const watchIntervalMs = 'dbui.watch_interval_ms';

  static String pinsFor(String collection) => 'dbui.pins.$collection';
  static String tagsFor(String collection) => 'dbui.tags.$collection';
}