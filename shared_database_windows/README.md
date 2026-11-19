# shared_database_windows

Windows backend for [`shared_database`](../README.md).

- **One file** — `%ProgramData%\dev.loner.shared_database\shared.db` (WAL).
- **Same Dart API** — Pigeon `SharedDatabaseApi`; `prepareStorageAccess()` is a no-op on Windows.
- Schema **v3**: `collections`, `records`, `preferences`.

## Host app checklist

1. Add `shared_database` to `pubspec.yaml` (this package is pulled in automatically).
2. `await SharedDatabase.open()` in `main()` before using `SharedDatabase.instance`.
3. Full rebuild after native plugin changes (`flutter clean` if needed).

No manifest or permission steps on Windows.

## Building (maintainers)

- Visual Studio with the C++ desktop workload and CMake ≥ 3.14.
- First CMake configure downloads the SQLite amalgamation and the nlohmann/json single header (network required once).

Regenerate the Pigeon bindings from the repo root with:

```bash
dart run pigeon --input pigeons/shared_database_api.dart
```
