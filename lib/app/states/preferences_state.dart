/// Keys in the shared preferences store.
class PreferencesState {
  const PreferencesState({
    this.keys = const [],
    this.loading = true,
    this.error,
  });

  final List<String> keys;
  final bool loading;
  final String? error;

  PreferencesState copyWith({
    List<String>? keys,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return PreferencesState(
      keys: keys ?? this.keys,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}