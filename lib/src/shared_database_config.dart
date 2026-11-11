/// Configuration for connecting to the on-device shared database.
class SharedDatabaseConfig {
  const SharedDatabaseConfig({
    this.isHost = false,
    this.authority = defaultAuthority,
  });

  /// Authority / shared data namespace (Android ContentProvider, Windows folder).
  static const defaultAuthority = 'dev.loner.shared_database';

  /// Host app id — install the Database APK on Android or run Database on Windows first.
  static const hostApplicationId = 'dev.loner.shared_database';

  /// Use in every client app (`isHost` is false).
  factory SharedDatabaseConfig.client([String? authority]) {
    return SharedDatabaseConfig(
      isHost: false,
      authority: authority ?? defaultAuthority,
    );
  }

  /// Use only in this repository's host app.
  factory SharedDatabaseConfig.host() {
    return const SharedDatabaseConfig(isHost: true);
  }

  /// When true, this app owns the SQLite file and declares the
  /// `ContentProvider` in its own `AndroidManifest.xml`.
  final bool isHost;

  /// Authority clients use to reach the host (`ContentResolver` / plugin).
  final String authority;
}
