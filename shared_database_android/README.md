# shared_database_android

Android backend for [`shared_database`](../README.md). **Drop the parent package into any Flutter app** — Gradle merges this module’s manifest; you do not edit the host app for storage.

- **One file** — `Documents/dev.loner.shared_database/shared.db` on primary storage (same absolute path in every app).
- **No host election** — each app opens that file via `SharedDatabaseStore` + `SharedDatabaseHelper` (WAL, `busy_timeout`).
- **No ContentProvider** — nothing to install besides your own APKs.

## Permissions (library only)

Declared in this module’s `android/src/main/AndroidManifest.xml` (Gradle **merges** them into the host APK):

| Permission | Role |
|------------|------|
| `READ_EXTERNAL_STORAGE` (max SDK 32) | Runtime prompt on older APIs when needed |
| `WRITE_EXTERNAL_STORAGE` (max SDK 28) | Runtime prompt on older APIs when needed |
| `MANAGE_EXTERNAL_STORAGE` | Android 11+: opens **All files access** settings when the shared Documents path needs it |

Requested at runtime via `SharedDatabasePermissionCoordinator` when Dart calls `SharedDatabase.open()`.
File probes live in `SharedDatabasePathIo`; creation in `SharedDatabaseFiles`.

## Host app checklist

1. Add `shared_database` to `pubspec.yaml`.
2. `await SharedDatabase.open()` before using the API (e.g. in `main()` or first frame with an `Activity`).
3. Rebuild the APK after plugin updates (`flutter clean` if native code changed).

Nothing else on Android.