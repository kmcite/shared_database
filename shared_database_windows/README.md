# shared_database_windows

Windows implementation for the `shared_database` plugin.

Speaks the Pigeon-generated `SharedDatabaseApi` contract (`shared_database_api.g.{h,cpp}`) and stores data in a shared SQLite database (WAL mode) at:

`%ProgramData%\dev.loner.shared_database\shared.db`

Schema version 3: `collections`, `records`, `preferences`.

## Building

- Visual Studio with the C++ desktop workload and CMake ≥ 3.14.
- First CMake configure downloads the SQLite amalgamation and the nlohmann/json single header (network required once).

Regenerate the Pigeon bindings from the repo root with:

```bash
dart run pigeon --input pigeons/shared_database_api.dart
```
