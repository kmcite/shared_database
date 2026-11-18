# shared_database_android

Android backend for `shared_database`.

- **One file** — `Documents/dev.loner.shared_database/shared.db` on primary storage (same absolute path in every app).
- **No host election** — each app opens that file via `SharedDatabaseStore` + `SharedDatabaseHelper` (WAL, `busy_timeout`).
- **No ContentProvider** — nothing to install besides your own APKs.

Add the Flutter dependency and call `SharedDatabase.open()`.