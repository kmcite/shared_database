# shared_database

One SQLite database on the device, shared across your Flutter apps on **Android** and **Windows**.

| Piece | Role |
|--------|------|
| **Database app** (`dev.loner.shared_database`) | Ships the provider/plugin and the admin console UI. |
| **`shared_database` package** | The API every app uses — same `SharedDatabase` surface everywhere. |

Every app calls the same `SharedDatabase.open()` and gets the full API — there is no host/client split. On Android the plugin auto-detects whether it runs inside the provider's app and routes through `ContentResolver` otherwise; on Windows all apps share one SQLite file under `%ProgramData%`.

---

## Client app

### Dependency

```yaml
dependencies:
  shared_database:
    path: ../shared_database
```

### Supported platforms

| Platform | Implementation | Sharing model |
|----------|----------------|----------------|
| **Android** | `shared_database_android` | Host `ContentProvider`; clients use `ContentResolver`. |
| **Windows** | `shared_database_windows` | Shared file under `%ProgramData%\<authority>\shared.db` (WAL). |
| iOS / macOS / Linux / Web | — | Not implemented (compile-only). |

### Android build

Consumer apps need a normal **Flutter 3.44+** Android project (`settings.gradle.kts` with `dev.flutter.flutter-plugin-loader` and `dev.flutter.flutter-gradle-plugin` on **:app** only). No extra Gradle steps.

The federated plugin `shared_database_android` is wired from this package’s `pubspec.yaml`. Its `android/build.gradle.kts` is an Android **library** — it must **not** apply `dev.flutter.flutter-gradle-plugin` on the plugin module.

### Windows build

Enable Windows on the app (`flutter config --enable-windows-desktop` if needed), depend on `shared_database`, run `flutter pub get`.

**This Database repo** is both the library package and the host app. Flutter does not auto-register federated plugins for that layout (same on Android — see `MainActivity`). The Windows runner links and registers `shared_database_windows` explicitly. **Other apps** that only depend on `shared_database` get the plugin via normal `flutter pub get` / build.

If you see `Native plugin not linked` / `Could not start database` on Windows after a clean clone, run `flutter clean`, then `flutter pub get`, then `flutter run -d windows` (not hot restart only).

The Windows plugin downloads the SQLite amalgamation on first CMake configure (network required once). Visual Studio with C++ desktop workload is required.

Default database path:

`%ProgramData%\dev.loner.shared_database\shared.db`

### Bootstrap

```dart
import 'package:shared_database/shared_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedDatabase.open();
  runApp(const MyApp());
}
```

### Data API

The Dart ↔ native boundary is a strictly-typed [Pigeon](https://pub.dev/packages/pigeon) contract (`pigeons/shared_database_api.dart`), generated into Dart, Kotlin, and C++.

```dart
final db = SharedDatabase.instance;

await db.ensureCollection('orders');
final id = await db.put('orders', {'total': 99});          // upsert (id auto-generated)
final same = await db.put('orders', {'total': 100}, id: id); // upsert

// Batch upsert — single native transaction on the host path
final ids = await db.putMany('orders', [
  (id: null, data: {'total': 1}),
  (id: existingId, data: {'total': 2}),
]);

// Partial update — top-level keys of `patch` merge into the stored JSON
await db.patch('orders', id, {'status': 'paid'});

// Async reads (optional pagination)
final rows = await db.getAll('orders', limit: 50, offset: 0);
final one = await db.getById('orders', id);
final names = await db.listCollections();

// Remove
await db.removeById('orders', id);   // one record
await db.removeAll('orders');        // all records in the collection

// Watch (polls native tokens; emits on change)
db.watchCollection('orders').listen((records) { ... });
db.watchRecord('orders', id).listen((record) { ... });
db.watchCollections().listen((names) { ... });

// Preferences (shared key/value store)
await db.setPreference('theme', 'dark');
final theme = await db.getPreference('theme');
await db.removePreference('theme');
final keys = await db.getPreferenceKeys();
db.watchPreference('theme').listen((value) { ... });
```

All reads are async — there is no synchronous cache API. Subscribe to the `watch*` streams for reactive updates.

---

## Database app (host)

This repo **is** the Database host. Entry point: `lib/main.dart` → `SharedDatabaseHostApp`.

```bash
flutter pub get
flutter run -d windows   # or -d android
flutter build windows
flutter build apk
```

Host initialization in code:

```dart
await SharedDatabase.open();
```

### In-app console

The Database UI (`lib/app/`) is a full admin suite — sidebar navigation on wide screens, bottom bar on phones:

- **Overview** — live stats (apps, collections, records, preferences), per-app record distribution, recent collections.
- **Collections** — every collection in one searchable, filterable, sortable grid; per-app drill-down.
- **Records** — per-collection browser with live watch, full-text filter, six sort orders, card/table views, multi-select bulk delete/copy, pins and tags (stored in shared preferences), and a visual JSON tree editor (plus raw JSON mode).
- **Search** — global search across all record ids and JSON content.
- **Prefs** — browse/edit the shared key/value store.
- **Backup** — export/import the entire database (collections + preferences) as JSON; wipe-all danger zone.
- **Settings** — theme mode, accent color and watch interval, persisted in the database preferences themselves.

Data refreshes automatically via the watch streams and a short poll interval (configurable in Settings).

After changing Kotlin or C++ in the platform plugins, rebuild the native app — hot reload is not enough.

### Console & admin API

Every app can call these — there is no host-only restriction:

```dart
final db = SharedDatabase.instance;

// Collection metadata (name, createdAt, createdByPackage, recordCount)
await db.collectionsDetailed();   // List<CollectionInfo>

// Collections
await db.ensureCollection('notes');
await db.renameCollection('old', 'new');
await db.removeCollection('notes');

// Records use the same put / putMany / patch / removeById / removeAll API
await db.put('notes', {'title': 'Hello'});
await db.put('notes', {'title': 'Updated'}, id: id); // upsert
await db.removeById('notes', id);
```

Admin types live in `shared_database_admin.dart` (`DatabaseOverview`, `CollectionInfo`, `AppDataInfo`).

---

## Architecture (short)

- **Dart** — generated Pigeon `SharedDatabaseApi` client in `lib/src/pigeon/` (schema: `pigeons/shared_database_api.dart`). Regenerate with `dart run pigeon --input pigeons/shared_database_api.dart` after changing the schema.
- **Android** — `SharedDatabaseHelper` + `SharedDatabaseProvider` (`content://dev.loner.shared_database/...`, including `collections`, `records`, `preferences`, and `call()` for collection rename/delete); `SharedDatabasePlugin` implements the generated Kotlin `SharedDatabaseApi`. The plugin auto-detects the provider's app by package name — inside it talks to SQLite directly, everywhere else through `ContentResolver`.
- **Windows** — `DatabaseStore` in `shared_database_windows` opens the same SQLite file under `%ProgramData%\dev.loner.shared_database\`; `SharedDatabaseWindowsPlugin` implements the generated C++ `SharedDatabaseApi`.

DB schema version **3** (collections, records, preferences) — aligned across Android and Windows.

---

## Versioning

Package version: `pubspec.yaml` (`shared_database`). Android DB version: `SharedDatabaseHelper.DB_VERSION`. Windows uses `PRAGMA user_version` with the same migrations.
