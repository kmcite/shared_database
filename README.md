# shared_database

One SQLite database on the device, shared across your Flutter apps on **Android** and **Windows**.

| Piece | Role |
|--------|------|
| **Database app** (`dev.loner.shared_database`) | Host — owns the database and admin APIs. |
| **`shared_database` package** | Client library — same `SharedDatabase` API everywhere. |

Run or install the Database host **before** client apps call `SharedDatabase.open()`.

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

(host prefs: `host_prefs.ini` in the same folder).

### Bootstrap

```dart
import 'package:shared_database/shared_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedDatabase.open();
  // optional: await SharedDatabase.attachAndVerify();
  runApp(const MyApp());
}
```

### Data API

```dart
final db = SharedDatabase.instance;

await db.ensure('orders');
final id = await db.put('orders', {'total': 99});

// Async reads
final rows = await db.all('orders');
final one = await db.get('orders', id);
final names = await db.listCollections();

// Sync reads (in-memory cache — see below)
final cached = db.allSync('orders');
final item = db.getSync('orders', id);

// Watch (polls host; updates cache)
db.watchCollection('orders').listen((records) { ... });
db.watchRecord('orders', id).listen((record) { ... });
db.watchCollections().listen((names) { ... });
```

### Sync reads

Platform I/O is always async. **Sync** methods read a **local cache** updated when you:

- call `all` / `get` / `listCollections`, or
- subscribe to `watchCollection` / `watchRecord` / `watchCollections`, or
- call `put` / `patch` / `drop`.

If nothing is cached yet, `allSync` / `getSync` throw with a clear message.

### Write / read aliases

| Preferred | Alias |
|-----------|--------|
| `put` | `create` |
| `patch` | `update` |
| `drop` | `delete` |
| `all` | `getAll` |
| `get` | `getById` |
| `ensure` | `ensureCollection` |

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
await SharedDatabase.openHost();
```

### In-app console

The Database UI (`lib/app/`) includes:

- **Apps** — packages that have collections or records in the database.
- **Collections** — per app; create, rename, delete; open records.
- **Records** — view, add, edit JSON, delete (per collection).

The console refreshes automatically on a short interval and after edits (no pull-to-refresh).

After changing Kotlin or C++ in the platform plugins, rebuild the native app — hot reload is not enough.

### Host-only Dart API

These require `openHost()` (or `SharedDatabaseConfig.host()`); clients get `HOST_ONLY` from the channel if they call them:

```dart
final db = SharedDatabase.instance;

// Dashboard
await db.overview();              // DatabaseOverview
await db.collectionsDetailed();   // List<CollectionInfo>
await db.appsDetailed();          // List<AppDataInfo>

// Collections
await db.ensureCollection('notes');
await db.renameCollection('old', 'new');
await db.deleteCollection('notes');

// Records use the same put / patch / drop API as clients
await db.put('notes', {'title': 'Hello'});
await db.patch('notes', id, {'title': 'Updated'});
await db.drop('notes', id);
```

Admin types live in `shared_database_admin.dart` (`DatabaseOverview`, `CollectionInfo`, `AppDataInfo`).

---

## Architecture (short)

- **Dart** — single `MethodChannel('shared_database')` in `lib/src/shared_database.dart`.
- **Android host** — `SharedDatabaseHelper` + `SharedDatabaseProvider` (`content://dev.loner.shared_database/...`).
- **Android client** — `ContentResolver` in `shared_database_android` (`isHost: false`).
- **Windows (host & client)** — `DatabaseStore` in `shared_database_windows` opens the same SQLite file; `isHost` gates admin channel methods only.

DB schema version **2** (collections, records, access_log) — aligned across Android and Windows.

---

## Versioning

Package version: `pubspec.yaml` (`shared_database`). Android DB version: `SharedDatabaseHelper.DB_VERSION`. Windows uses `PRAGMA user_version` with the same migrations.
