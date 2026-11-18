#include "database_store.h"

#include <ShlObj.h>
#include <windows.h>

#include <chrono>
#include <filesystem>
#include <map>
#include <sstream>
#include <stdexcept>

#include <nlohmann/json.hpp>

#include "sqlite3.h"

namespace shared_database_windows {
namespace {

constexpr int kDbVersion = 3;
constexpr const char* kDbFileName = "shared.db";
constexpr const char* kPreferencesTableSql =
    "CREATE TABLE IF NOT EXISTS preferences ("
    "key TEXT PRIMARY KEY NOT NULL,"
    "value TEXT NOT NULL,"
    "updated_at INTEGER NOT NULL,"
    "updated_by_package TEXT NOT NULL);";

int64_t NowMillis() {
  return std::chrono::duration_cast<std::chrono::milliseconds>(
             std::chrono::system_clock::now().time_since_epoch())
      .count();
}

std::string WideToUtf8(const std::wstring& wide) {
  if (wide.empty()) return {};
  const int size = WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), -1, nullptr, 0,
                                       nullptr, nullptr);
  std::string utf8(size - 1, '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), -1, utf8.data(), size, nullptr,
                      nullptr);
  return utf8;
}

std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) return {};
  const int size =
      MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
  std::wstring wide(size - 1, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, wide.data(), size);
  return wide;
}

std::wstring ProgramDataPath() {
  PWSTR path = nullptr;
  if (FAILED(SHGetKnownFolderPath(FOLDERID_ProgramData, 0, nullptr, &path))) {
    throw std::runtime_error("Cannot resolve ProgramData folder");
  }
  std::wstring result(path);
  CoTaskMemFree(path);
  return result;
}

std::string CallerExeBaseName() {
  wchar_t buffer[MAX_PATH];
  const DWORD len = GetModuleFileNameW(nullptr, buffer, MAX_PATH);
  if (len == 0 || len >= MAX_PATH) {
    return "unknown";
  }
  const std::filesystem::path path(buffer);
  std::wstring stem = path.stem().wstring();
  return WideToUtf8(stem);
}

void SqlCheck(int rc, sqlite3* db, const char* context) {
  if (rc == SQLITE_OK || rc == SQLITE_DONE || rc == SQLITE_ROW) return;
  const char* msg = db ? sqlite3_errmsg(db) : "sqlite error";
  std::ostringstream oss;
  oss << context << ": " << msg;
  throw std::runtime_error(oss.str());
}

}  // namespace

DatabaseStore& DatabaseStore::Instance() {
  static DatabaseStore instance;
  return instance;
}

void DatabaseStore::Initialize(const std::string& authority, bool is_host,
                               const std::string& caller_package) {
  std::lock_guard<std::mutex> lock(mutex_);
  if (initialized_ && authority_ == authority && is_host_ == is_host) {
    caller_package_ =
        caller_package.empty() ? CallerExeBaseName() : caller_package;
    return;
  }

  authority_ = authority;
  is_host_ = is_host;
  caller_package_ =
      caller_package.empty() ? CallerExeBaseName() : caller_package;

  const std::wstring root = ProgramDataPath();
  const std::wstring dir =
      root + L"\\" + Utf8ToWide(authority_);
  data_dir_ = WideToUtf8(dir);
  db_path_ = data_dir_ + "\\" + kDbFileName;

  std::error_code ec;
  std::filesystem::create_directories(dir, ec);
  if (ec) {
    throw std::runtime_error("Cannot create data directory");
  }

  const bool db_exists = std::filesystem::exists(db_path_);
  if (!is_host_ && !db_exists) {
    throw std::runtime_error(
        "Cannot reach the shared database host. Run the manager app first.");
  }

  if (is_host_) {
    host_package_ = caller_package_;
  } else if (host_package_.empty()) {
    host_package_ = authority_;
  }

  OpenDatabase();
  initialized_ = true;
}

void DatabaseStore::OpenDatabase() {
  if (db_) {
    sqlite3_close(db_);
    db_ = nullptr;
  }
  SqlCheck(sqlite3_open(db_path_.c_str(), &db_), db_, "open database");
  SqlCheck(sqlite3_exec(db_, "PRAGMA foreign_keys=ON;", nullptr, nullptr, nullptr),
           db_, "foreign_keys");
  SqlCheck(sqlite3_exec(db_, "PRAGMA journal_mode=WAL;", nullptr, nullptr, nullptr),
           db_, "wal");
  EnsureSchema();
}

void DatabaseStore::EnsureSchema() {
  const int version = UserVersion();
  if (version == 0) {
    SqlCheck(sqlite3_exec(db_,
                          "CREATE TABLE collections ("
                          "name TEXT PRIMARY KEY NOT NULL,"
                          "created_at INTEGER NOT NULL,"
                          "created_by_package TEXT NOT NULL);",
                          nullptr, nullptr, nullptr),
             db_, "create collections");
    SqlCheck(sqlite3_exec(db_,
                          "CREATE TABLE records ("
                          "id TEXT NOT NULL,"
                          "collection TEXT NOT NULL,"
                          "data TEXT NOT NULL,"
                          "created_at INTEGER NOT NULL,"
                          "updated_at INTEGER NOT NULL,"
                          "created_by_package TEXT NOT NULL,"
                          "updated_by_package TEXT NOT NULL,"
                          "PRIMARY KEY (id, collection),"
                          "FOREIGN KEY (collection) REFERENCES collections(name)"
                          " ON DELETE CASCADE);",
                          nullptr, nullptr, nullptr),
             db_, "create records");
    SqlCheck(sqlite3_exec(db_,
                          "CREATE INDEX idx_records_collection ON records(collection);",
                          nullptr, nullptr, nullptr),
             db_, "idx records");
    SqlCheck(sqlite3_exec(db_, kPreferencesTableSql, nullptr, nullptr, nullptr),
             db_, "create preferences");
    SetUserVersion(kDbVersion);
  } else if (version < kDbVersion) {
    RunMigrations(version);
    SetUserVersion(kDbVersion);
  }
}

void DatabaseStore::RunMigrations(int old_version) {
  if (old_version < 2) {
    SqlCheck(sqlite3_exec(
                 db_,
                 "ALTER TABLE collections ADD COLUMN created_by_package "
                 "TEXT NOT NULL DEFAULT 'legacy';",
                 nullptr, nullptr, nullptr),
             db_, "migrate collections");
    SqlCheck(sqlite3_exec(
                 db_,
                 "ALTER TABLE records ADD COLUMN created_by_package "
                 "TEXT NOT NULL DEFAULT 'legacy';",
                 nullptr, nullptr, nullptr),
             db_, "migrate records created");
    SqlCheck(sqlite3_exec(
                 db_,
                 "ALTER TABLE records ADD COLUMN updated_by_package "
                 "TEXT NOT NULL DEFAULT 'legacy';",
                 nullptr, nullptr, nullptr),
             db_, "migrate records updated");
  }
  SqlCheck(sqlite3_exec(db_, kPreferencesTableSql, nullptr, nullptr, nullptr),
           db_, "migrate preferences");
}

int DatabaseStore::UserVersion() {
  sqlite3_stmt* stmt = nullptr;
  SqlCheck(sqlite3_prepare_v2(db_, "PRAGMA user_version;", -1, &stmt, nullptr), db_,
           "user_version prepare");
  int version = 0;
  if (sqlite3_step(stmt) == SQLITE_ROW) {
    version = sqlite3_column_int(stmt, 0);
  }
  sqlite3_finalize(stmt);
  return version;
}

void DatabaseStore::SetUserVersion(int version) {
  std::ostringstream sql;
  sql << "PRAGMA user_version = " << version << ";";
  SqlCheck(sqlite3_exec(db_, sql.str().c_str(), nullptr, nullptr, nullptr), db_,
           "set user_version");
}

void DatabaseStore::EnsureCollectionUnlocked(const std::string& name) {
  sqlite3_stmt* stmt = nullptr;
  SqlCheck(sqlite3_prepare_v2(db_,
                              "INSERT OR IGNORE INTO collections "
                              "(name, created_at, created_by_package) "
                              "VALUES (?, ?, ?);",
                              -1, &stmt, nullptr),
           db_, "ensure collection prepare");
  const int64_t now = NowMillis();
  sqlite3_bind_text(stmt, 1, name.c_str(), -1, SQLITE_TRANSIENT);
  sqlite3_bind_int64(stmt, 2, now);
  sqlite3_bind_text(stmt, 3, caller_package_.c_str(), -1, SQLITE_TRANSIENT);
  const int rc = sqlite3_step(stmt);
  sqlite3_finalize(stmt);
  SqlCheck(rc, db_, "ensure collection step");
}

void DatabaseStore::EnsureCollection(const std::string& name) {
  std::lock_guard<std::mutex> lock(mutex_);
  EnsureCollectionUnlocked(name);
}

std::vector<std::string> DatabaseStore::ListCollectionNames() {
  std::lock_guard<std::mutex> lock(mutex_);

  std::vector<std::string> names;
  sqlite3_stmt* stmt = nullptr;
  SqlCheck(sqlite3_prepare_v2(db_, "SELECT name FROM collections ORDER BY name;",
                              -1, &stmt, nullptr),
           db_, "list collections prepare");
  while (sqlite3_step(stmt) == SQLITE_ROW) {
    names.emplace_back(reinterpret_cast<const char*>(sqlite3_column_text(stmt, 0)));
  }
  sqlite3_finalize(stmt);
  return names;
}

std::vector<CollectionDetail> DatabaseStore::ListCollectionsDetailed() {
  std::lock_guard<std::mutex> lock(mutex_);
  std::vector<CollectionDetail> rows;
  sqlite3_stmt* stmt = nullptr;
  SqlCheck(sqlite3_prepare_v2(
               db_,
               "SELECT c.name, c.created_at, c.created_by_package,"
               " (SELECT COUNT(*) FROM records r WHERE r.collection = c.name)"
               " FROM collections c ORDER BY c.created_at DESC;",
               -1, &stmt, nullptr),
           db_, "collections detailed prepare");
  while (sqlite3_step(stmt) == SQLITE_ROW) {
    CollectionDetail c;
    c.name = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 0));
    c.created_at = sqlite3_column_int64(stmt, 1);
    c.created_by_package =
        reinterpret_cast<const char*>(sqlite3_column_text(stmt, 2));
    c.record_count = sqlite3_column_int(stmt, 3);
    rows.push_back(std::move(c));
  }
  sqlite3_finalize(stmt);
  return rows;
}

std::string DatabaseStore::UpsertRecord(const std::string& collection,
                                        const std::string& id,
                                        const std::string& data) {
  std::lock_guard<std::mutex> lock(mutex_);
  EnsureCollectionUnlocked(collection);
  sqlite3_stmt* stmt = nullptr;
  SqlCheck(sqlite3_prepare_v2(
               db_,
               "INSERT INTO records (id, collection, data, created_at, "
               "updated_at, created_by_package, updated_by_package) "
               "VALUES (?, ?, ?, ?, ?, ?, ?) "
               "ON CONFLICT(id, collection) DO UPDATE SET "
               "data = excluded.data, updated_at = excluded.updated_at, "
               "updated_by_package = excluded.updated_by_package;",
               -1, &stmt, nullptr),
           db_, "upsert prepare");
  const int64_t now = NowMillis();
  sqlite3_bind_text(stmt, 1, id.c_str(), -1, SQLITE_TRANSIENT);
  sqlite3_bind_text(stmt, 2, collection.c_str(), -1, SQLITE_TRANSIENT);
  sqlite3_bind_text(stmt, 3, data.c_str(), -1, SQLITE_TRANSIENT);
  sqlite3_bind_int64(stmt, 4, now);
  sqlite3_bind_int64(stmt, 5, now);
  sqlite3_bind_text(stmt, 6, caller_package_.c_str(), -1, SQLITE_TRANSIENT);
  sqlite3_bind_text(stmt, 7, caller_package_.c_str(), -1, SQLITE_TRANSIENT);
  SqlCheck(sqlite3_step(stmt), db_, "upsert step");
  sqlite3_finalize(stmt);

  return id;
}

std::vector<std::string> DatabaseStore::UpsertRecords(
    const std::string& collection,
    const std::vector<std::pair<std::string, std::string>>& items) {
  std::lock_guard<std::mutex> lock(mutex_);
  EnsureCollectionUnlocked(collection);
  SqlCheck(sqlite3_exec(db_, "BEGIN IMMEDIATE;", nullptr, nullptr, nullptr), db_,
           "put many begin");
  std::vector<std::string> ids;
  try {
    sqlite3_stmt* stmt = nullptr;
    SqlCheck(sqlite3_prepare_v2(
                 db_,
                 "INSERT INTO records (id, collection, data, created_at, "
                 "updated_at, created_by_package, updated_by_package) "
                 "VALUES (?, ?, ?, ?, ?, ?, ?) "
                 "ON CONFLICT(id, collection) DO UPDATE SET "
                 "data = excluded.data, updated_at = excluded.updated_at, "
                 "updated_by_package = excluded.updated_by_package;",
                 -1, &stmt, nullptr),
             db_, "put many prepare");
    const int64_t now = NowMillis();
    for (const auto& [id, data] : items) {
      sqlite3_reset(stmt);
      sqlite3_bind_text(stmt, 1, id.c_str(), -1, SQLITE_TRANSIENT);
      sqlite3_bind_text(stmt, 2, collection.c_str(), -1, SQLITE_TRANSIENT);
      sqlite3_bind_text(stmt, 3, data.c_str(), -1, SQLITE_TRANSIENT);
      sqlite3_bind_int64(stmt, 4, now);
      sqlite3_bind_int64(stmt, 5, now);
      sqlite3_bind_text(stmt, 6, caller_package_.c_str(), -1, SQLITE_TRANSIENT);
      sqlite3_bind_text(stmt, 7, caller_package_.c_str(), -1, SQLITE_TRANSIENT);
      SqlCheck(sqlite3_step(stmt), db_, "put many step");
    
      ids.push_back(id);
    }
    sqlite3_finalize(stmt);
    SqlCheck(sqlite3_exec(db_, "COMMIT;", nullptr, nullptr, nullptr), db_,
             "put many commit");
  } catch (...) {
    sqlite3_exec(db_, "ROLLBACK;", nullptr, nullptr, nullptr);
    throw;
  }
  return ids;
}

std::string DatabaseStore::PatchRecord(const std::string& collection,
                                       const std::string& id,
                                       const std::string& patch_json) {
  // GetRecord/UpdateRecord take the mutex themselves; the read-modify-write
  // is not atomic, matching the serialized write path used by callers.
  const auto row = GetRecord(collection, id);
  if (!row.has_value()) {
    throw std::runtime_error("Record \"" + id + "\" not found in \"" +
                             collection + "\"");
  }
  nlohmann::json merged;
  nlohmann::json patch;
  try {
    merged = nlohmann::json::parse(row->data);
    patch = nlohmann::json::parse(patch_json);
  } catch (const nlohmann::json::exception&) {
    throw std::runtime_error("patch dataJson and stored data must be JSON "
                             "objects");
  }
  if (!merged.is_object() || !patch.is_object()) {
    throw std::runtime_error("patch dataJson and stored data must be JSON "
                             "objects");
  }
  for (auto it = patch.begin(); it != patch.end(); ++it) {
    merged[it.key()] = it.value();
  }
  UpdateRecord(collection, id, merged.dump());
  return id;
}

std::vector<RecordRow> DatabaseStore::GetRecords(
    const std::string& collection, std::optional<int64_t> limit,
    std::optional<int64_t> offset) {
  std::lock_guard<std::mutex> lock(mutex_);
  std::ostringstream sql;
  sql << "SELECT id, collection, data, created_at, "
         "updated_at, created_by_package, "
         "updated_by_package FROM records "
         "WHERE collection = ? "
         "ORDER BY updated_at DESC";
  if (limit.has_value()) {
    sql << " LIMIT " << *limit;
    if (offset.has_value()) {
      sql << " OFFSET " << *offset;
    }
  } else if (offset.has_value()) {
    sql << " LIMIT -1 OFFSET " << *offset;
  }
  sql << ";";
  std::vector<RecordRow> rows;
  sqlite3_stmt* stmt = nullptr;
  SqlCheck(sqlite3_prepare_v2(db_, sql.str().c_str(), -1, &stmt, nullptr), db_,
           "get all prepare");
  sqlite3_bind_text(stmt, 1, collection.c_str(), -1, SQLITE_TRANSIENT);
  while (sqlite3_step(stmt) == SQLITE_ROW) {
    RecordRow row;
    row.id = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 0));
    row.collection = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 1));
    row.data = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 2));
    row.created_at = sqlite3_column_int64(stmt, 3);
    row.updated_at = sqlite3_column_int64(stmt, 4);
    row.created_by_package =
        reinterpret_cast<const char*>(sqlite3_column_text(stmt, 5));
    row.updated_by_package =
        reinterpret_cast<const char*>(sqlite3_column_text(stmt, 6));
    rows.push_back(std::move(row));
  }
  sqlite3_finalize(stmt);
  return rows;
}

std::optional<RecordRow> DatabaseStore::GetRecord(
    const std::string& collection, const std::string& id) {
  std::lock_guard<std::mutex> lock(mutex_);
  sqlite3_stmt* stmt = nullptr;
  SqlCheck(sqlite3_prepare_v2(db_,
                              "SELECT id, collection, data, created_at, "
                              "updated_at, created_by_package, "
                              "updated_by_package FROM records "
                              "WHERE collection = ? AND id = ?;",
                              -1, &stmt, nullptr),
           db_, "get one prepare");
  sqlite3_bind_text(stmt, 1, collection.c_str(), -1, SQLITE_TRANSIENT);
  sqlite3_bind_text(stmt, 2, id.c_str(), -1, SQLITE_TRANSIENT);
  std::optional<RecordRow> row;
  if (sqlite3_step(stmt) == SQLITE_ROW) {
    RecordRow value;
    value.id = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 0));
    value.collection = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 1));
    value.data = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 2));
    value.created_at = sqlite3_column_int64(stmt, 3);
    value.updated_at = sqlite3_column_int64(stmt, 4);
    value.created_by_package =
        reinterpret_cast<const char*>(sqlite3_column_text(stmt, 5));
    value.updated_by_package =
        reinterpret_cast<const char*>(sqlite3_column_text(stmt, 6));
    row = std::move(value);
  }
  sqlite3_finalize(stmt);
  return row;
}

void DatabaseStore::UpdateRecord(const std::string& collection,
                                 const std::string& id, const std::string& data) {
  std::lock_guard<std::mutex> lock(mutex_);
  sqlite3_stmt* stmt = nullptr;
  SqlCheck(sqlite3_prepare_v2(db_,
                              "UPDATE records SET data = ?, updated_at = ?, "
                              "updated_by_package = ? WHERE collection = ? AND id = ?;",
                              -1, &stmt, nullptr),
           db_, "update prepare");
  const int64_t now = NowMillis();
  sqlite3_bind_text(stmt, 1, data.c_str(), -1, SQLITE_TRANSIENT);
  sqlite3_bind_int64(stmt, 2, now);
  sqlite3_bind_text(stmt, 3, caller_package_.c_str(), -1, SQLITE_TRANSIENT);
  sqlite3_bind_text(stmt, 4, collection.c_str(), -1, SQLITE_TRANSIENT);
  sqlite3_bind_text(stmt, 5, id.c_str(), -1, SQLITE_TRANSIENT);
  SqlCheck(sqlite3_step(stmt), db_, "update step");
  sqlite3_finalize(stmt);

}

void DatabaseStore::DeleteRecord(const std::string& collection,
                                 const std::string& id) {
  std::lock_guard<std::mutex> lock(mutex_);
  sqlite3_stmt* stmt = nullptr;
  SqlCheck(sqlite3_prepare_v2(db_,
                              "DELETE FROM records WHERE collection = ? AND id = ?;",
                              -1, &stmt, nullptr),
           db_, "delete prepare");
  sqlite3_bind_text(stmt, 1, collection.c_str(), -1, SQLITE_TRANSIENT);
  sqlite3_bind_text(stmt, 2, id.c_str(), -1, SQLITE_TRANSIENT);
  SqlCheck(sqlite3_step(stmt), db_, "delete step");
  sqlite3_finalize(stmt);
}

int DatabaseStore::DeleteAllRecords(const std::string& collection) {
  std::lock_guard<std::mutex> lock(mutex_);
  sqlite3_stmt* stmt = nullptr;
  SqlCheck(sqlite3_prepare_v2(db_,
                              "DELETE FROM records WHERE collection = ?;",
                              -1, &stmt, nullptr),
           db_, "delete all records prepare");
  sqlite3_bind_text(stmt, 1, collection.c_str(), -1, SQLITE_TRANSIENT);
  SqlCheck(sqlite3_step(stmt), db_, "delete all records step");
  const int deleted = sqlite3_changes(db_);
  sqlite3_finalize(stmt);
  return deleted;
}

void DatabaseStore::RenameCollection(const std::string& from,
                                     const std::string& to) {
  if (from == to) return;
  std::lock_guard<std::mutex> lock(mutex_);
  sqlite3_stmt* check = nullptr;
  SqlCheck(sqlite3_prepare_v2(db_, "SELECT COUNT(*) FROM collections WHERE name = ?;",
                              -1, &check, nullptr),
           db_, "rename check prepare");
  sqlite3_bind_text(check, 1, to.c_str(), -1, SQLITE_TRANSIENT);
  if (sqlite3_step(check) == SQLITE_ROW &&
      sqlite3_column_int(check, 0) > 0) {
    sqlite3_finalize(check);
    throw std::runtime_error("Collection \"" + to + "\" already exists");
  }
  sqlite3_finalize(check);

  SqlCheck(sqlite3_exec(db_, "BEGIN IMMEDIATE;", nullptr, nullptr, nullptr), db_,
           "rename begin");
  try {
    sqlite3_stmt* ins = nullptr;
    SqlCheck(sqlite3_prepare_v2(db_,
                                "INSERT INTO collections (name, created_at, "
                                "created_by_package) "
                                "SELECT ?, created_at, created_by_package "
                                "FROM collections WHERE name = ?;",
                                -1, &ins, nullptr),
             db_, "rename insert prepare");
    sqlite3_bind_text(ins, 1, to.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(ins, 2, from.c_str(), -1, SQLITE_TRANSIENT);
    SqlCheck(sqlite3_step(ins), db_, "rename insert step");
    sqlite3_finalize(ins);

    sqlite3_stmt* upd = nullptr;
    SqlCheck(sqlite3_prepare_v2(db_,
                                "UPDATE records SET collection = ? WHERE collection = ?;",
                                -1, &upd, nullptr),
             db_, "rename update records prepare");
    sqlite3_bind_text(upd, 1, to.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(upd, 2, from.c_str(), -1, SQLITE_TRANSIENT);
    SqlCheck(sqlite3_step(upd), db_, "rename update records step");
    sqlite3_finalize(upd);

    sqlite3_stmt* del = nullptr;
    SqlCheck(sqlite3_prepare_v2(db_, "DELETE FROM collections WHERE name = ?;", -1,
                                &del, nullptr),
             db_, "rename delete prepare");
    sqlite3_bind_text(del, 1, from.c_str(), -1, SQLITE_TRANSIENT);
    SqlCheck(sqlite3_step(del), db_, "rename delete step");
    if (sqlite3_changes(db_) == 0) {
      sqlite3_finalize(del);
      throw std::runtime_error("Collection \"" + from + "\" not found");
    }
    sqlite3_finalize(del);

    SqlCheck(sqlite3_exec(db_, "COMMIT;", nullptr, nullptr, nullptr), db_,
             "rename commit");
  } catch (...) {
    sqlite3_exec(db_, "ROLLBACK;", nullptr, nullptr, nullptr);
    throw;
  }
}

void DatabaseStore::DeleteCollection(const std::string& name) {
  std::lock_guard<std::mutex> lock(mutex_);
  sqlite3_stmt* stmt = nullptr;
  SqlCheck(sqlite3_prepare_v2(db_, "DELETE FROM collections WHERE name = ?;", -1,
                              &stmt, nullptr),
           db_, "delete collection prepare");
  sqlite3_bind_text(stmt, 1, name.c_str(), -1, SQLITE_TRANSIENT);
  SqlCheck(sqlite3_step(stmt), db_, "delete collection step");
  if (sqlite3_changes(db_) == 0) {
    sqlite3_finalize(stmt);
    throw std::runtime_error("Collection \"" + name + "\" not found");
  }
  sqlite3_finalize(stmt);
}

std::map<std::string, int64_t> DatabaseStore::GetCollectionsWatchToken() {
  std::lock_guard<std::mutex> lock(mutex_);
  std::map<std::string, int64_t> token;
  int64_t count = 0;
  int64_t fingerprint = 1;
  sqlite3_stmt* stmt = nullptr;
  SqlCheck(sqlite3_prepare_v2(db_,
                              "SELECT name FROM collections ORDER BY name COLLATE "
                              "NOCASE;",
                              -1, &stmt, nullptr),
           db_, "collections watch token");
  while (sqlite3_step(stmt) == SQLITE_ROW) {
    count++;
    const unsigned char* name = sqlite3_column_text(stmt, 0);
    const std::string text = name ? reinterpret_cast<const char*>(name) : "";
    fingerprint = 31 * fingerprint + static_cast<int64_t>(std::hash<std::string>{}(text));
  }
  sqlite3_finalize(stmt);
  token["count"] = count;
  token["fingerprint"] = fingerprint;
  return token;
}

std::map<std::string, int64_t> DatabaseStore::GetCollectionWatchToken(
    const std::string& collection) {
  std::lock_guard<std::mutex> lock(mutex_);
  std::map<std::string, int64_t> token;
  sqlite3_stmt* stmt = nullptr;
  SqlCheck(sqlite3_prepare_v2(
               db_,
               "SELECT COUNT(*), IFNULL(MAX(updated_at), 0) FROM records "
               "WHERE collection = ?;",
               -1, &stmt, nullptr),
           db_, "collection watch token");
  sqlite3_bind_text(stmt, 1, collection.c_str(), -1, SQLITE_TRANSIENT);
  if (sqlite3_step(stmt) == SQLITE_ROW) {
    token["count"] = sqlite3_column_int64(stmt, 0);
    token["maxUpdatedAt"] = sqlite3_column_int64(stmt, 1);
  }
  sqlite3_finalize(stmt);
  return token;
}

RecordWatchToken DatabaseStore::GetRecordWatchToken(const std::string& collection,
                                                    const std::string& id) {
  std::lock_guard<std::mutex> lock(mutex_);
  RecordWatchToken token;
  sqlite3_stmt* stmt = nullptr;
  SqlCheck(sqlite3_prepare_v2(
               db_,
               "SELECT updated_at FROM records WHERE collection = ? AND id = ?;",
               -1, &stmt, nullptr),
           db_, "record watch token");
  sqlite3_bind_text(stmt, 1, collection.c_str(), -1, SQLITE_TRANSIENT);
  sqlite3_bind_text(stmt, 2, id.c_str(), -1, SQLITE_TRANSIENT);
  if (sqlite3_step(stmt) == SQLITE_ROW) {
    token.exists = true;
    token.updated_at = sqlite3_column_int64(stmt, 0);
  }
  sqlite3_finalize(stmt);
  return token;
}

std::optional<std::string> DatabaseStore::GetPreferenceValue(
    const std::string& key) {
  std::lock_guard<std::mutex> lock(mutex_);
  sqlite3_stmt* stmt = nullptr;
  SqlCheck(sqlite3_prepare_v2(db_,
                              "SELECT value FROM preferences WHERE key = ?;",
                              -1, &stmt, nullptr),
           db_, "get preference prepare");
  sqlite3_bind_text(stmt, 1, key.c_str(), -1, SQLITE_TRANSIENT);
  std::optional<std::string> value;
  if (sqlite3_step(stmt) == SQLITE_ROW) {
    const auto* text = sqlite3_column_text(stmt, 0);
    value = text ? std::string(reinterpret_cast<const char*>(text)) : "";
  }
  sqlite3_finalize(stmt);
  return value;
}

void DatabaseStore::SetPreferenceValue(const std::string& key,
                                       const std::string& value) {
  std::lock_guard<std::mutex> lock(mutex_);
  sqlite3_stmt* stmt = nullptr;
  SqlCheck(sqlite3_prepare_v2(
               db_,
               "INSERT INTO preferences (key, value, updated_at, "
               "updated_by_package) VALUES (?, ?, ?, ?) "
               "ON CONFLICT(key) DO UPDATE SET "
               "value = excluded.value, updated_at = excluded.updated_at, "
               "updated_by_package = excluded.updated_by_package;",
               -1, &stmt, nullptr),
           db_, "set preference prepare");
  sqlite3_bind_text(stmt, 1, key.c_str(), -1, SQLITE_TRANSIENT);
  sqlite3_bind_text(stmt, 2, value.c_str(), -1, SQLITE_TRANSIENT);
  sqlite3_bind_int64(stmt, 3, NowMillis());
  sqlite3_bind_text(stmt, 4, caller_package_.c_str(), -1, SQLITE_TRANSIENT);
  SqlCheck(sqlite3_step(stmt), db_, "set preference step");
  sqlite3_finalize(stmt);
}

void DatabaseStore::RemovePreference(const std::string& key) {
  std::lock_guard<std::mutex> lock(mutex_);
  sqlite3_stmt* stmt = nullptr;
  SqlCheck(sqlite3_prepare_v2(db_, "DELETE FROM preferences WHERE key = ?;",
                              -1, &stmt, nullptr),
           db_, "remove preference prepare");
  sqlite3_bind_text(stmt, 1, key.c_str(), -1, SQLITE_TRANSIENT);
  SqlCheck(sqlite3_step(stmt), db_, "remove preference step");
  sqlite3_finalize(stmt);
}

std::vector<std::string> DatabaseStore::ListPreferenceKeys() {
  std::lock_guard<std::mutex> lock(mutex_);
  std::vector<std::string> keys;
  sqlite3_stmt* stmt = nullptr;
  SqlCheck(sqlite3_prepare_v2(db_, "SELECT key FROM preferences ORDER BY key;",
                              -1, &stmt, nullptr),
           db_, "list preferences prepare");
  while (sqlite3_step(stmt) == SQLITE_ROW) {
    keys.emplace_back(
        reinterpret_cast<const char*>(sqlite3_column_text(stmt, 0)));
  }
  sqlite3_finalize(stmt);
  return keys;
}

RecordWatchToken DatabaseStore::GetPreferenceWatchToken(
    const std::string& key) {
  std::lock_guard<std::mutex> lock(mutex_);
  RecordWatchToken token;
  sqlite3_stmt* stmt = nullptr;
  SqlCheck(sqlite3_prepare_v2(
               db_, "SELECT updated_at FROM preferences WHERE key = ?;", -1,
               &stmt, nullptr),
           db_, "preference watch token");
  sqlite3_bind_text(stmt, 1, key.c_str(), -1, SQLITE_TRANSIENT);
  if (sqlite3_step(stmt) == SQLITE_ROW) {
    token.exists = true;
    token.updated_at = sqlite3_column_int64(stmt, 0);
  }
  sqlite3_finalize(stmt);
  return token;
}

}  // namespace shared_database_windows
