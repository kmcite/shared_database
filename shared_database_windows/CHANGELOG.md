# Changelog

## 0.2.0

### Changed

- Implements the `SharedDatabaseApi` Pigeon contract (schema v3): `putMany`, `patch`, paginated `getAll`, and the preferences store (`preferences` table, `PRAGMA user_version = 3`).
- `initialize()` no longer takes `isHost`/`authority` — the store always initializes for `dev.loner.shared_database` under `%ProgramData%`.
- All API methods are available to every app; the `HOST_ONLY` gate and `RequireHost()` were removed.
- `GetOverview`, `ListAppsDetailed`, access-log/activity-logging code, `InsertRecord`, and the `host_prefs.ini` file were removed as dead code.
- `PatchRecord` uses nlohmann/json (single header downloaded at CMake configure time) for shallow top-level JSON merges.
- Unused method-channel Dart boilerplate removed; this package is C++/Pigeon only.
