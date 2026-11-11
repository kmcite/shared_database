#ifndef SHARED_DATABASE_DATABASE_STORE_H_
#define SHARED_DATABASE_DATABASE_STORE_H_

#include <cstdint>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <vector>

struct sqlite3;

namespace shared_database_windows {

struct RecordIdData {
  std::string id;
  std::string data;
};

struct CollectionDetail {
  std::string name;
  int64_t created_at = 0;
  std::string created_by_package;
  int record_count = 0;
};

struct AppDetail {
  std::string package_name;
  int collection_count = 0;
  int record_count = 0;
  std::vector<CollectionDetail> collections;
};

struct AccessLogRow {
  int64_t id = 0;
  int64_t occurred_at = 0;
  std::string caller_package;
  std::string action;
  std::optional<std::string> collection_name;
  std::optional<std::string> record_id;
};

struct ConnectedAppRow {
  std::string package_name;
  int64_t last_seen_at = 0;
  int access_count = 0;
};

struct DatabaseOverviewData {
  int collection_count = 0;
  int record_count = 0;
  std::string host_package;
  bool activity_logging_enabled = true;
  std::vector<ConnectedAppRow> connected_apps;
};

struct RecordWatchToken {
  bool exists = false;
  int64_t updated_at = 0;
};

class DatabaseStore {
 public:
  static DatabaseStore& Instance();

  void Initialize(const std::string& authority, bool is_host,
                  const std::string& caller_package);

  bool IsHost() const { return is_host_; }
  const std::string& CallerPackage() const { return caller_package_; }

  void EnsureCollection(const std::string& name);
  std::vector<std::string> ListCollectionNames();
  std::vector<CollectionDetail> ListCollectionsDetailed();
  std::vector<AppDetail> ListAppsDetailed();

  std::string InsertRecord(const std::string& collection,
                           const std::string& id, const std::string& data);
  std::string UpsertRecord(const std::string& collection, const std::string& id,
                           const std::string& data);
  std::map<std::string, int64_t> GetCollectionsWatchToken();
  std::map<std::string, int64_t> GetCollectionWatchToken(
      const std::string& collection);
  RecordWatchToken GetRecordWatchToken(const std::string& collection,
                                       const std::string& id);
  std::vector<RecordIdData> GetRecords(const std::string& collection);
  std::optional<RecordIdData> GetRecord(const std::string& collection,
                                        const std::string& id);
  void UpdateRecord(const std::string& collection, const std::string& id,
                    const std::string& data);
  void DeleteRecord(const std::string& collection, const std::string& id);

  void RenameCollection(const std::string& from, const std::string& to);
  void DeleteCollection(const std::string& name);

  bool IsActivityLoggingEnabled();
  void SetActivityLoggingEnabled(bool enabled);
  void ClearAccessLog();
  std::vector<AccessLogRow> GetAccessLog(int limit);
  DatabaseOverviewData GetOverview();

 private:
  DatabaseStore() = default;

  void OpenDatabase();
  void EnsureSchema();
  void RunMigrations(int version);
  int UserVersion();
  void SetUserVersion(int version);

  void LogAccess(const std::string& action,
                 const std::optional<std::string>& collection,
                 const std::optional<std::string>& record_id);

  void EnsureCollectionUnlocked(const std::string& name);

  bool LoadActivityLoggingPref();
  void SaveActivityLoggingPref(bool enabled);

  std::mutex mutex_;
  bool is_host_ = false;
  bool initialized_ = false;
  std::string authority_;
  std::string caller_package_;
  std::string host_package_;
  std::string data_dir_;
  std::string db_path_;
  std::string prefs_path_;
  bool activity_logging_enabled_ = true;
  sqlite3* db_ = nullptr;
};

}  // namespace shared_database_windows

#endif  // SHARED_DATABASE_DATABASE_STORE_H_
