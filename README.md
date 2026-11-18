# shared_database

One SQLite database on the device, shared across your Flutter apps on **Android** and **Windows**.

Add the package → call `SharedDatabase.open()` → use the API. No companion app, no host election, no manifest edits.

---

## Add to any Flutter project

### Requirements

| Requirement | Value |
|-------------|--------|
| Flutter | **3.44+** |
| Dart | **^3.13.7** (or compatible) |
| Platforms | **Android**, **Windows** (full support) |

### 1. Dependency

```yaml
dependencies:
  shared_database:
    path: ../shared_database   # or git: url / ref
```

```bash
flutter pub get
```

### 2. Initialize

```dart
import 'package:flutter/material.dart';
import 'package:shared_database/shared_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedDatabase.open();
  runApp(const MyApp());
}
```

```dart
final db = SharedDatabase.instance;
```

### 3. Run

```bash
flutter run -d android
flutter run -d windows
```

Rebuild natively after plugin Kotlin/C++ changes (not hot reload only).

---

## Several apps, one database, concurrent access

Every app that should share data:

1. Depends on `shared_database`.
2. Calls `await SharedDatabase.open()` on startup.
3. Is installed on the **same device**.

There is **no** special host app and **no** “open app X first” rule. Uninstalling one app does **not** delete the database (it lives on shared storage / ProgramData, not inside a single app’s private data).

| Platform | Where the file lives | How apps share |
|----------|----------------------|----------------|
| **Android** | `…/Documents/dev.loner.shared_database/shared.db` on primary storage | Every app opens **the same path** with SQLite (WAL + `busy_timeout` for multi-process access). |
| **Windows** | `%ProgramData%\dev.loner.shared_database\shared.db` | Same file, all desktop processes. |

**Concurrency**

- SQLite **WAL** on Android and Windows.
- Android: `PRAGMA busy_timeout = 5000` so parallel writers wait instead of failing instantly.
- Dart: writes in a single app are serialized (`_invokeWrite`); reads can overlap.
- Across apps: multiple processes hit the same file — normal SQLite locking applies (many readers, writes serialized at the database).

**You do not add**

- ContentProvider entries in your manifest (none in this plugin).
- Storage permission flows or “all files access” (empty plugin manifest).
- A separate installer / companion APK.

---

## Data API (summary)

```dart
final db = SharedDatabase.instance;

await db.ensureCollection('orders');
final id = await db.put('orders', {'total': 99});
await db.patch('orders', id, {'status': 'paid'});
final rows = await db.getAll('orders', limit: 50);
await db.setPreference('theme', 'dark');

db.watchCollection('orders').listen((records) { ... });
```

See earlier sections in your codebase docs or `lib/src/shared_database.dart` for the full surface (preferences, `putMany`, admin `collectionsDetailed`, etc.).

---

## Windows notes

- Enable desktop: `flutter config --enable-windows-desktop` if needed.
- Visual Studio with **C++ desktop workload**.
- First CMake configure may download SQLite (network once).
- If native plugin is not linked: `flutter clean` → `flutter pub get` → full rebuild.

---

## Troubleshooting

| Symptom | Action |
|---------|--------|
| `STORAGE_UNAVAILABLE` (Android) | Device blocked creating `Documents/dev.loner.shared_database/shared.db`. Check path in error details; free space; retry after another app created the folder. |
| `Native plugin not linked` | `flutter pub get`, clean rebuild. |
| `Call SharedDatabase.open() first` | Await `open()` in `main()` before using `instance`. |

---

## Architecture

- **Dart** — Pigeon `SharedDatabaseApi` (`pigeons/shared_database_api.dart`).
- **Android** — `SharedDatabasePaths` / `SharedDatabaseFiles` / `SharedDatabaseStore` / `SharedDatabaseHelper`.
- **Windows** — `DatabaseStore` under ProgramData.

Schema **v3**: `collections`, `records`, `preferences`.