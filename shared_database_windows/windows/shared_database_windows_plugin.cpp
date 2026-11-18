#include "shared_database_windows_plugin.h"

#include <any>
#include <chrono>
#include <random>
#include <string>
#include <utility>
#include <vector>

#include "database_store.h"

namespace shared_database_windows {
namespace {

using shared_database_windows_pigeon::CollectionData;
using shared_database_windows_pigeon::CollectionWatchToken;
using shared_database_windows_pigeon::CollectionsWatchToken;
using shared_database_windows_pigeon::ErrorOr;
using shared_database_windows_pigeon::FlutterError;
using shared_database_windows_pigeon::PreferenceWatchToken;
using shared_database_windows_pigeon::RecordData;
using shared_database_windows_pigeon::RecordPutRequest;

RecordData ToRecordData(const RecordRow& row) {
  return RecordData(row.id, row.collection, row.data, row.created_at,
                    row.updated_at, row.created_by_package,
                    row.updated_by_package);
}

flutter::EncodableList ToRecordDataList(
    const std::vector<RecordRow>& rows) {
  flutter::EncodableList list;
  for (const auto& row : rows) {
    list.push_back(flutter::EncodableValue(
        flutter::CustomEncodableValue(ToRecordData(row))));
  }
  return list;
}

CollectionData ToCollectionData(const CollectionDetail& c) {
  return CollectionData(c.name, c.created_at, c.created_by_package,
                        c.record_count);
}

std::string GenerateRecordId() {
  // The Dart layer always supplies an id; generate one defensively.
  static std::mt19937_64 rng(std::random_device{}());
  const auto nanos = std::chrono::duration_cast<std::chrono::nanoseconds>(
                         std::chrono::steady_clock::now().time_since_epoch())
                         .count();
  return "rec-" + std::to_string(nanos) + "-" + std::to_string(rng());
}

}  // namespace

void SharedDatabaseWindowsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto plugin = std::make_unique<SharedDatabaseWindowsPlugin>();
  shared_database_windows_pigeon::SharedDatabaseApi::SetUp(
      registrar->messenger(), plugin.get());
  registrar->AddPlugin(std::move(plugin));
}

SharedDatabaseWindowsPlugin::SharedDatabaseWindowsPlugin() {}

SharedDatabaseWindowsPlugin::~SharedDatabaseWindowsPlugin() {}

std::optional<FlutterError> SharedDatabaseWindowsPlugin::Initialize() {
  DatabaseStore::Instance().Initialize("dev.loner.shared_database",
                                       /*is_host=*/true, "");
  return std::nullopt;
}

std::optional<FlutterError> SharedDatabaseWindowsPlugin::EnsureCollection(
    const std::string &name) {
  DatabaseStore::Instance().EnsureCollection(name);
  return std::nullopt;
}

ErrorOr<flutter::EncodableList> SharedDatabaseWindowsPlugin::GetCollections() {
  flutter::EncodableList list;
  for (const auto &name : DatabaseStore::Instance().ListCollectionNames()) {
    list.push_back(flutter::EncodableValue(name));
  }
  return ErrorOr<flutter::EncodableList>(list);
}

std::optional<FlutterError> SharedDatabaseWindowsPlugin::RenameCollection(
    const std::string &from, const std::string &to) {
  DatabaseStore::Instance().RenameCollection(from, to);
  return std::nullopt;
}

std::optional<FlutterError> SharedDatabaseWindowsPlugin::RemoveCollection(
    const std::string &name) {
  DatabaseStore::Instance().DeleteCollection(name);
  return std::nullopt;
}

ErrorOr<flutter::EncodableList>
SharedDatabaseWindowsPlugin::GetCollectionsDetailed() {
  flutter::EncodableList list;
  for (const auto &c :
       DatabaseStore::Instance().ListCollectionsDetailed()) {
    list.push_back(flutter::EncodableValue(
        flutter::CustomEncodableValue(ToCollectionData(c))));
  }
  return ErrorOr<flutter::EncodableList>(list);
}

ErrorOr<std::string> SharedDatabaseWindowsPlugin::Put(
    const std::string &collection, const std::string *id,
    const std::string &data_json) {
  auto &store = DatabaseStore::Instance();
  const std::string record_id =
      (id == nullptr || id->empty()) ? GenerateRecordId() : *id;
  return ErrorOr<std::string>(
      store.UpsertRecord(collection, record_id, data_json));
}

ErrorOr<flutter::EncodableList> SharedDatabaseWindowsPlugin::PutMany(
    const std::string &collection, const flutter::EncodableList &records) {
  std::vector<std::pair<std::string, std::string>> items;
  items.reserve(records.size());
  for (const auto &item : records) {
    const auto *custom = std::get_if<flutter::CustomEncodableValue>(&item);
    if (custom == nullptr ||
        custom->type() != typeid(RecordPutRequest)) {
      return ErrorOr<flutter::EncodableList>(
          FlutterError("BAD_ARGS", "Invalid record entry in putMany"));
    }
    const auto &request =
        std::any_cast<const RecordPutRequest &>(*custom);
    const std::string *request_id = request.id();
    const std::string record_id =
        (request_id == nullptr || request_id->empty())
            ? GenerateRecordId()
            : *request_id;
    items.emplace_back(record_id, request.data_json());
  }
  flutter::EncodableList ids;
  for (const auto &id :
       DatabaseStore::Instance().UpsertRecords(collection, items)) {
    ids.push_back(flutter::EncodableValue(id));
  }
  return ErrorOr<flutter::EncodableList>(ids);
}

ErrorOr<std::string> SharedDatabaseWindowsPlugin::Patch(
    const std::string &collection, const std::string &id,
    const std::string &data_json) {
  try {
    return ErrorOr<std::string>(
        DatabaseStore::Instance().PatchRecord(collection, id, data_json));
  } catch (const std::exception &e) {
    return ErrorOr<std::string>(FlutterError("PATCH_FAILED", e.what()));
  }
}

ErrorOr<std::optional<RecordData>> SharedDatabaseWindowsPlugin::GetById(
    const std::string &collection, const std::string &id) {
  const auto row = DatabaseStore::Instance().GetRecord(collection, id);
  if (!row.has_value()) {
    return ErrorOr<std::optional<RecordData>>(std::nullopt);
  }
  return ErrorOr<std::optional<RecordData>>(ToRecordData(*row));
}

ErrorOr<flutter::EncodableList> SharedDatabaseWindowsPlugin::GetAll(
    const std::string &collection, const int64_t *limit,
    const int64_t *offset) {
  return ErrorOr<flutter::EncodableList>(ToRecordDataList(
      DatabaseStore::Instance().GetRecords(
          collection, limit != nullptr ? std::optional<int64_t>(*limit)
                                       : std::nullopt,
          offset != nullptr ? std::optional<int64_t>(*offset)
                            : std::nullopt)));
}

std::optional<FlutterError> SharedDatabaseWindowsPlugin::RemoveById(
    const std::string &collection, const std::string &id) {
  DatabaseStore::Instance().DeleteRecord(collection, id);
  return std::nullopt;
}

std::optional<FlutterError> SharedDatabaseWindowsPlugin::RemoveAll(
    const std::string &collection) {
  DatabaseStore::Instance().DeleteAllRecords(collection);
  return std::nullopt;
}

ErrorOr<std::optional<std::string>>
SharedDatabaseWindowsPlugin::GetPreferenceValue(const std::string &key) {
  return ErrorOr<std::optional<std::string>>(
      DatabaseStore::Instance().GetPreferenceValue(key));
}

std::optional<FlutterError> SharedDatabaseWindowsPlugin::SetPreferenceValue(
    const std::string &key, const std::string &value) {
  DatabaseStore::Instance().SetPreferenceValue(key, value);
  return std::nullopt;
}

std::optional<FlutterError> SharedDatabaseWindowsPlugin::RemovePreference(
    const std::string &key) {
  DatabaseStore::Instance().RemovePreference(key);
  return std::nullopt;
}

ErrorOr<flutter::EncodableList> SharedDatabaseWindowsPlugin::GetPreferences() {
  flutter::EncodableList list;
  for (const auto &key : DatabaseStore::Instance().ListPreferenceKeys()) {
    list.push_back(flutter::EncodableValue(key));
  }
  return ErrorOr<flutter::EncodableList>(list);
}

ErrorOr<CollectionsWatchToken>
SharedDatabaseWindowsPlugin::GetCollectionsWatchToken() {
  const auto token = DatabaseStore::Instance().GetCollectionsWatchToken();
  return ErrorOr<CollectionsWatchToken>(CollectionsWatchToken(
      token.at("count"), token.at("fingerprint"), false));
}

ErrorOr<CollectionWatchToken>
SharedDatabaseWindowsPlugin::GetCollectionWatchToken(
    const std::string &collection) {
  const auto token =
      DatabaseStore::Instance().GetCollectionWatchToken(collection);
  return ErrorOr<CollectionWatchToken>(CollectionWatchToken(
      token.at("count"), token.at("maxUpdatedAt"), false));
}

ErrorOr<shared_database_windows_pigeon::RecordWatchToken>
SharedDatabaseWindowsPlugin::GetRecordWatchToken(
    const std::string &collection, const std::string &id) {
  const auto token =
      DatabaseStore::Instance().GetRecordWatchToken(collection, id);
  if (!token.exists) {
    return ErrorOr<shared_database_windows_pigeon::RecordWatchToken>(
        shared_database_windows_pigeon::RecordWatchToken(false, false));
  }
  const int64_t updated_at = token.updated_at;
  return ErrorOr<shared_database_windows_pigeon::RecordWatchToken>(
      shared_database_windows_pigeon::RecordWatchToken(true, &updated_at,
                                                       false));
}

ErrorOr<PreferenceWatchToken>
SharedDatabaseWindowsPlugin::GetPreferenceWatchToken(const std::string &key) {
  const auto token =
      DatabaseStore::Instance().GetPreferenceWatchToken(key);
  if (!token.exists) {
    return ErrorOr<PreferenceWatchToken>(PreferenceWatchToken(false, false));
  }
  const int64_t updated_at = token.updated_at;
  return ErrorOr<PreferenceWatchToken>(
      PreferenceWatchToken(true, &updated_at, false));
}

}  // namespace shared_database_windows
