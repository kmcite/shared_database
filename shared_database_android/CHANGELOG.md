# Changelog

## 0.2.0

### Changed

- Implements the `SharedDatabaseApi` Pigeon contract (schema v3): `putMany` (single transaction), `patch` (shallow `org.json` merge), paginated `getAll`, and the preferences store (new `preferences` table, DB v3).
- `initialize()` no longer takes `isHost`/`authority` — host detection is derived from the app package name and the authority is the `SharedDatabaseContract.AUTHORITY` constant.
- All API methods work for every app: `getCollectionsDetailed` is served through the provider's `collections` URI (now returns name/created_at/created_by_package/record_count), and collection rename/delete route through `ContentResolver.call()`.
- Record inserts through the provider now upsert, matching the `put` contract.
- Removed dead code: `access_log` table/indexes, no-op `logAccess` and `ACTION_*` constants, `insertRecord`, `listAppsDetailed`, `getOverview`.
