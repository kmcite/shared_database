# Changelog

## 1.7.0+8

### Changed
- **Windows** � aligned architecture and class naming: renamed DatabaseStore to SharedDatabaseHelper (shared_database_helper.h / shared_database_helper.cpp), matching Android's SharedDatabaseHelper.
- **Peer-to-peer Windows** � removed host-dependency initialization requirement; any app can start first and bootstrap %ProgramData%\dev.loner.shared_database\shared.db.
- **Performance & Concurrency** � configured PRAGMA synchronous = NORMAL across Android and Windows in SQLite WAL mode; added 5000ms busy timeout on Windows.
- **Indexing (Schema v4)** � added compound index idx_records_collection_updated ON records(collection, updated_at DESC) for high-performance sorting and O(log N) watch token polling.

## 1.6.0+7

### Changed
- **Storage** � library-owned storage access and zero-configuration permission handling on Android.

## 1.5.0+6

### Changed

- **Android** — single shared file under `Documents/dev.loner.shared_database/shared.db`; removed host election, registry, and ContentProvider. All apps open the same path (WAL + `busy_timeout`).
- **Repo** — library-only layout; nested `companion/` removed (use the standalone `companion` app in the monorepo).
- **Docs** — README oriented around adding the package to any Flutter project.

## 1.4.0+5

### Changed

- **Repo layout** — root package is library-only (`lib/src/`, platform federated plugins); installable host console and platform runners moved to `companion/` (package `companion`, app id `dev.loner.companion`).

## 1.4.0

### Changed

- **Host console layout** — `features/`, `commands/`, `states/`, and `repositories/` only; removed legacy `pages/`, `widgets/`, `utils/`, Provider shell, and duplicate `*_page` stubs.
- **Repositories** — split into `CollectionsRepository`, `PreferencesRepository`, and `BackupRepository` behind a slim `DatabaseRepository` facade; `RecordsRepository` scopes watch/CRUD per collection.
- **Navigation** — `AppRouter` under `features/router/` drives `MaterialApp`, stack sync from `NavigationState`, overlays (confirm/prompt/shell “More”), and snackbars from `FeedbackState`.
- **Screens** — feature entrypoints renamed `*_screen.dart`; shared UI lives in `features/widgets/`.

## 1.3.0

### Added

- **Host console (`any` state management)** — commands, repositories, models, and feature folders replace Provider; unified `AppHost` for scope, navigation, lifecycle, and shell UI.
- **Overview UX** — mosaic apps treemap, recent-collections timeline, and shell tab markers to jump to Collections.
- **Pigeon-generated bindings** — committed generated Dart/Kotlin/C++ API stubs under `lib/src/pigeon/` and platform packages.

### Changed

- **Navigation** — drawer / rail / bottom bar with shell tab commands instead of Provider-scoped shell widgets.
- **Branding** — refreshed launcher icons and splash assets.

## 1.2.0

### Added

- **`putMany`** — batch upserts in a single native transaction; accepts `({String? id, Map data})` records and returns ids in order.
- **`patch`** — partial update that shallow-merges top-level JSON keys into an existing record (both platforms; Android uses `org.json`, Windows uses nlohmann/json).
- **`getAll` pagination** — optional `limit`/`offset`.
- **Preferences store** — `getPreference`, `setPreference`, `removePreference`, `getPreferenceKeys`, `watchPreference` backed by a new `preferences` table (DB schema v3 on both platforms; new `content://<authority>/preferences` provider paths on Android).

### Changed

- **`put` is always an upsert** — the `upsert` flag was removed from the Pigeon contract.
- **No host/client split** — `SharedDatabase.open()` takes no arguments; `isHost`/`authority` were removed from `initialize()`. The authority is now the fixed contract constant `dev.loner.shared_database`. `openHost()` remains as a deprecated alias. Every method works for every app: Android auto-detects the provider's app by package name, routes privileged collection operations through `ContentResolver.call()`, and exposes detailed collections via the provider; Windows initializes the shared store for any caller.
- **`getCollectionsDetailed` is available to all apps** — the `collections` provider URI now returns name/created_at/created_by_package/record_count.
- **`RecordDto`/`CollectionDto` renamed** to `RecordData`/`CollectionData`; `listCollections`/`listCollectionsDetailed` renamed to `getCollections`/`getCollectionsDetailed`.

### Removed

- **Sync cache API** — `getAllSync`, `getByIdSync`, `listCollectionsSync`, `getPreferenceSync` and the entire in-memory record/collection/preference cache were removed; all reads are async (use `watch*` streams for updates).
- **`overview()`/`appsDetailed()`** — removed from `SharedDatabase`; the console controller derives `DatabaseOverview`/`AppDataInfo` from `collectionsDetailed()` instead.
- Dead code: unused `access_log` table/indexes, no-op `logAccess`, activity-logging preferences (`host_prefs.ini` on Windows), `InsertRecord`/`insertRecord` (everything upserts), `ListAppsDetailed`/`listAppsDetailed`, `GetOverview`/`getOverview`, and the unused method-channel boilerplate in `shared_database_windows/lib/`.

## 1.1.0

### Changed

- **Typed native interop.** The untyped `MethodChannel('shared_database')` layer is replaced by a strictly-typed [Pigeon](https://pub.dev/packages/pigeon) contract defined in `pigeons/shared_database_api.dart` and generated for Dart, Kotlin (`shared_database_android`), and C++ (`shared_database_windows`). Regenerate with `dart run pigeon --input pigeons/shared_database_api.dart`.
- **API rename.** Client data operations are now `put`, `getById`, `getAll`, `removeById`, `removeAll`, `ensureCollection`; host admin operations are `renameCollection` and `removeCollection`. `patch`/`drop`/`all`/`get`/`ensure`/`deleteCollection` and the `allSync`/`getSync` sync reads were renamed to `getAllSync`/`getByIdSync`. Edits use `put(..., id: existingId)` (upsert).
- **`removeAll(collection)`** deletes every record in a collection while keeping the collection itself (new `DELETE FROM records WHERE collection = ?` on both platforms; Android `ContentProvider` now supports bulk delete via the `collections/*/records` URI).
- **Windows payload parity.** `getById`/`getAll` now return full record metadata (`createdAt`, `updatedAt`, `createdBy`, `updatedBy`) on Windows, matching Android. The Android `ContentProvider` cursor projection was extended with the same columns for client apps.
- `SharedRecord` gained optional `createdAt`/`updatedAt`/`createdBy`/`updatedBy` fields populated from `RecordDto`.

### Notes

- Watch tokens are now typed Pigeon classes (`CollectionsWatchToken`, `CollectionWatchToken`, `RecordWatchToken`) with an explicit `forceRefresh` flag instead of raw maps.
- The host console app (`lib/app/`) was updated to the new client API.
