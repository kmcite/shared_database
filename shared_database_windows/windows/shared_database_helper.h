#ifndef SHARED_DATABASE_SHARED_DATABASE_HELPER_H_
#define SHARED_DATABASE_SHARED_DATABASE_HELPER_H_

#include <cstdint>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <vector>

struct sqlite3;

namespace shared_database_windows {

struct RecordRow {
  std::string id;
  std::string collection;
  std::string data;
  int64_t created_at = 0;
  int64_t updated_at = 0;
  std::string created_by_package;
  std::string updated_by_package;
};

struct CollectionDetail {
  std::string name;
  int64_t created_at = 0;
  std::string created_by_package;
  int record_count = 0;
};

struct RecordWatchToken {
  bool exists = false;
  int64_t updated_at = 0;
};

class SharedDatabaseHelper {
 public:
  static SharedDatabaseHelper& Instance();

  void Initialize(const std::string& authority, bool is_host,
                  const std::string& caller_package);

  bool IsHost() const { return is_host_; }
  const std::string& CallerPackage() const { return caller_package_; }

  void EnsureCollection(const std::string& name);
  std::vector<std::string> ListCollectionNames();
  std::vector<CollectionDetail> ListCollectionsDetailed();

  std::string UpsertRecord(const std::string& collection, const std::string& id,
                           const std::string& data);
  /// Batch upserts (id, dataJson pairs) in a single transaction.
  std::vector<std::string> UpsertRecords(
      const std::string& collection,
      const std::vector<std::pair<std::string, std::string>>& items);
  /// Shallow-merges patch_json top-level keys into the stored record data.
  std::string PatchRecord(const std::string& collection, const std::string& id,
                          const std::string& patch_json);
  std::map<std::string, int64_t> GetCollectionsWatchToken();
  std::map<std::string, int64_t> GetCollectionWatchToken(
      const std::string& collection);
  RecordWatchToken GetRecordWatchToken(const std::string& collection,
                                       const std::string& id);
  std::vector<RecordRow> GetRecords(const std::string& collection,
                                    std::optional<int64_t> limit = std::nullopt,
                                    std::optional<int64_t> offset = std::nullopt);
  std::optional<RecordRow> GetRecord(const std::string& collection,
                                     const std::string& id);
  void UpdateRecord(const std::string& collection, const std::string& id,
                    const std::string& data);
  void DeleteRecord(const std::string& collection, const std::string& id);
  int DeleteAllRecords(const std::string& collection);

  // — Preferences —

  std::optional<std::string> GetPreferenceValue(const std::string& key);
  void SetPreferenceValue(const std::string& key, const std::string& value);
  void RemovePreference(const std::string& key);
  std::vector<std::string> ListPreferenceKeys();
  RecordWatchToken GetPreferenceWatchToken(const std::string& key);

  void RenameCollection(const std::string& from, const std::string& to);
  void DeleteCollection(const std::string& name);

 private:
  SharedDatabaseHelper() = default;

  void OpenDatabase();
  void EnsureSchema();
  void RunMigrations(int version);
  int UserVersion();
  void SetUserVersion(int version);


  void EnsureCollectionUnlocked(const std::string& name);

  std::mutex mutex_;
  bool is_host_ = false;
  bool initialized_ = false;
  std::string authority_;
  std::string caller_package_;
  std::string host_package_;
  std::string data_dir_;
  std::string db_path_;
  sqlite3* db_ = nullptr;
};

}  // namespace shared_database_windows

#endif  // SHARED_DATABASE_SHARED_DATABASE_HELPER_H_
