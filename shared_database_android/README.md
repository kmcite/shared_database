# shared_database_android

Android implementation for the `shared_database` plugin.

Speaks the Pigeon-generated `SharedDatabaseApi` contract (`SharedDatabaseApi.g.kt`) and exposes the shared SQLite database through a `ContentProvider` at `content://dev.loner.shared_database`.

- `SharedDatabaseHelper` — SQLiteOpenHelper (schema v3: `collections`, `records`, `preferences`, WAL).
- `SharedDatabaseProvider` — serves `collections`, `collections/*/records[/*]`, `preferences`, `preferences/*`, and `call()` for collection rename/delete.
- `SharedDatabasePlugin` — implements the generated Kotlin `SharedDatabaseApi`. Auto-detects the provider's app by package name: inside it uses the helper directly, everywhere else it goes through `ContentResolver`.
