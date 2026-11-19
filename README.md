# shared_database

One SQLite database on the device, shared across your Flutter apps on **Android** and **Windows**.

Add the package → call `SharedDatabase.open()` → use the API. No companion app, no host election, **no storage code or manifest edits in your app** — Android permissions live in `shared_database_android` and merge into your APK automatically.

**Checklist**

1. `shared_database` in `pubspec.yaml` (path or [GitHub](#1-dependency)).
2. `WidgetsFlutterBinding.ensureInitialized()` then `await SharedDatabase.open()`.
3. `flutter run` — accept the Android storage prompt once if shown.

---

## Add to any Flutter project

### Requirements

| Requirement | Value |
|-------------|--------|
| Flutter | **3.44+** |
| Dart | **^3.13.7** (or compatible) |
| Platforms | **Android**, **Windows** (full support) |

### 1. Dependency

**Local path** (monorepo / sibling folder):

```yaml
dependencies:
  shared_database:
    path: ../shared_database
```

**GitHub** (any Flutter project with Git installed):

```yaml
dependencies:
  shared_database:
    git:
      url: https://github.com/kmcite/shared_database.git
```

```bash
flutter pub get
```

`pub get` pulls the repo and resolves embedded platform packages (`shared_database_android`, `shared_database_windows`) from that checkout — no extra steps.

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

**Host app: nothing extra**

| Skip in your app | Why |
|------------------|-----|
| Storage permissions in `AndroidManifest.xml` | Declared in **`shared_database_android`** and merged by Gradle |
| `permission_handler` / custom storage UI | Plugin runs `prepareStorageAccess()` before opening the DB |
| ContentProvider wiring | Not used — direct file on shared storage |
| Companion / host APK | Any app with this dependency shares the same file |

### Android storage (all in the library)

| What | Where |
|------|--------|
| Manifest permissions | `shared_database_android/android/src/main/AndroidManifest.xml` (merged into host app) |
| Runtime prompts | `SharedDatabaseStorageAccess` + `SharedDatabasePlugin` (`ActivityAware`) |
| Trigger | First `await SharedDatabase.open()` while the app has a foreground `Activity` |

**Flow when you call `SharedDatabase.open()`**

1. **Dart** — `prepareStorageAccess()` then `initialize()`.
2. **Android ≤ 10** — system dialog for **Read/Write storage** if still needed.
3. **Android 11+** — if the shared Documents path is not usable yet, the plugin opens system **All files access** for your app (`MANAGE_EXTERNAL_STORAGE`); grant it once per app that uses this package.
4. **Direct file** — `Documents/dev.loner.shared_database/shared.db` (same path in Shop, Companion, or any other dependent).

Install every app that should share data on the **same device**. Each app must pass the prompt once; after that they all read/write the same file (SQLite WAL + `busy_timeout`).

**Play Store note:** “All files access” is a restricted permission for public store listings; fine for sideloaded or internal apps on your own devices.

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
| `STORAGE_UNAVAILABLE` / `STORAGE_PERMISSION` (Android) | Run `open()` while the UI is visible (needs `Activity`). Accept storage / **All files access** when the plugin prompts — do not add permissions in the host app. Delete `Documents/dev.loner.shared_database` and retry if the file was left half-deleted. |
| `Native plugin not linked` | `flutter pub get`, clean rebuild. |
| `Call SharedDatabase.open() first` | Await `open()` in `main()` before using `instance`. |

---

## Architecture

- **Dart** — Pigeon `SharedDatabaseApi` (`pigeons/shared_database_api.dart`).
- **Android** — `SharedDatabasePathIo`, `SharedDatabaseStorageAccess`, `SharedDatabasePermissionCoordinator`, `SharedDatabasePaths` / `SharedDatabaseFiles` / `SharedDatabaseStore` / `SharedDatabaseHelper`.
- **Windows** — `DatabaseStore` under ProgramData.

Schema **v3**: `collections`, `records`, `preferences`.