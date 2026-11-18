/// Keys and values in the shared preferences store — mutated by commands.
class PreferencesState {
  List<String> keys = [];
  Map<String, String?> values = {};
  bool loading = true;
  String? error;
}