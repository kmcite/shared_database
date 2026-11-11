#include "shared_database_windows_plugin.h"

#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

#include "database_store.h"

namespace shared_database_windows {
namespace {

flutter::EncodableMap RecordMap(const RecordIdData& row) {
  return flutter::EncodableMap{
      {flutter::EncodableValue("id"), flutter::EncodableValue(row.id)},
      {flutter::EncodableValue("data"), flutter::EncodableValue(row.data)},
  };
}

std::string GetStringArg(const flutter::EncodableMap& map, const char* key) {
  const auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end() || !std::holds_alternative<std::string>(it->second)) {
    return {};
  }
  return std::get<std::string>(it->second);
}

bool GetBoolArg(const flutter::EncodableMap& map, const char* key,
                bool default_value) {
  const auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end() || !std::holds_alternative<bool>(it->second)) {
    return default_value;
  }
  return std::get<bool>(it->second);
}

int GetIntArg(const flutter::EncodableMap& map, const char* key,
              int default_value) {
  const auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) return default_value;
  if (std::holds_alternative<int32_t>(it->second)) {
    return std::get<int32_t>(it->second);
  }
  if (std::holds_alternative<int64_t>(it->second)) {
    return static_cast<int>(std::get<int64_t>(it->second));
  }
  return default_value;
}

bool RequireHost(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result,
    bool is_host) {
  if (!is_host) {
    result->Error("HOST_ONLY",
                  "Only the database host app can call this method");
    return false;
  }
  return true;
}

}  // namespace

void SharedDatabaseWindowsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "shared_database",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<SharedDatabaseWindowsPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

SharedDatabaseWindowsPlugin::SharedDatabaseWindowsPlugin() {}

SharedDatabaseWindowsPlugin::~SharedDatabaseWindowsPlugin() {}

void SharedDatabaseWindowsPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto& store = DatabaseStore::Instance();

  try {
    const std::string& method = method_call.method_name();
    const auto* args =
        std::get_if<flutter::EncodableMap>(method_call.arguments());

    if (method == "initialize") {
      if (!args) {
        result->Error("ARG", "arguments required");
        return;
      }
      const bool is_host = GetBoolArg(*args, "isHost", false);
      const std::string authority = GetStringArg(*args, "authority");
      is_host_ = is_host;
      store.Initialize(
          authority.empty() ? "dev.loner.shared_database" : authority, is_host,
          "");
      result->Success();
      return;
    }

    if (method == "ensureCollection") {
      if (!args) {
        result->Error("ARG", "name required");
        return;
      }
      const std::string name = GetStringArg(*args, "name");
      if (name.empty()) {
        result->Error("ARG", "name required");
        return;
      }
      store.EnsureCollection(name);
      result->Success();
      return;
    }

    if (method == "listCollections") {
      flutter::EncodableList list;
      for (const auto& name : store.ListCollectionNames()) {
        list.push_back(flutter::EncodableValue(name));
      }
      result->Success(flutter::EncodableValue(list));
      return;
    }

    if (method == "getCollectionsWatchToken") {
      const auto token = store.GetCollectionsWatchToken();
      result->Success(flutter::EncodableMap{
          {flutter::EncodableValue("count"),
           flutter::EncodableValue(static_cast<int64_t>(token.at("count")))},
          {flutter::EncodableValue("fingerprint"),
           flutter::EncodableValue(static_cast<int64_t>(token.at("fingerprint")))},
      });
      return;
    }

    if (method == "getCollectionWatchToken") {
      if (!args) {
        result->Error("ARG", "collection required");
        return;
      }
      const std::string collection = GetStringArg(*args, "collection");
      const auto token = store.GetCollectionWatchToken(collection);
      result->Success(flutter::EncodableMap{
          {flutter::EncodableValue("count"),
           flutter::EncodableValue(static_cast<int32_t>(token.at("count")))},
          {flutter::EncodableValue("maxUpdatedAt"),
           flutter::EncodableValue(static_cast<int64_t>(token.at("maxUpdatedAt")))},
      });
      return;
    }

    if (method == "getRecordWatchToken") {
      if (!args) {
        result->Error("ARG", "collection and id required");
        return;
      }
      const std::string collection = GetStringArg(*args, "collection");
      const std::string id = GetStringArg(*args, "id");
      const auto token = store.GetRecordWatchToken(collection, id);
      if (!token.exists) {
        result->Success(flutter::EncodableMap{
            {flutter::EncodableValue("exists"), flutter::EncodableValue(false)},
        });
        return;
      }
      result->Success(flutter::EncodableMap{
          {flutter::EncodableValue("exists"), flutter::EncodableValue(true)},
          {flutter::EncodableValue("updatedAt"),
           flutter::EncodableValue(token.updated_at)},
      });
      return;
    }

    if (method == "getOverview") {
      if (!RequireHost(result, is_host_)) return;
      const auto overview = store.GetOverview();
      result->Success(flutter::EncodableMap{
          {flutter::EncodableValue("collectionCount"),
           flutter::EncodableValue(overview.collection_count)},
          {flutter::EncodableValue("recordCount"),
           flutter::EncodableValue(overview.record_count)},
          {flutter::EncodableValue("hostPackage"),
           flutter::EncodableValue(overview.host_package)},
      });
      return;
    }

    if (method == "listCollectionsDetailed") {
      if (!RequireHost(result, is_host_)) return;
      flutter::EncodableList list;
      for (const auto& c : store.ListCollectionsDetailed()) {
        list.push_back(flutter::EncodableMap{
            {flutter::EncodableValue("name"), flutter::EncodableValue(c.name)},
            {flutter::EncodableValue("createdAt"),
             flutter::EncodableValue(c.created_at)},
            {flutter::EncodableValue("createdByPackage"),
             flutter::EncodableValue(c.created_by_package)},
            {flutter::EncodableValue("recordCount"),
             flutter::EncodableValue(c.record_count)},
        });
      }
      result->Success(flutter::EncodableValue(list));
      return;
    }

    if (method == "listAppsDetailed") {
      if (!RequireHost(result, is_host_)) return;
      flutter::EncodableList apps;
      for (const auto& app : store.ListAppsDetailed()) {
        flutter::EncodableList cols;
        for (const auto& c : app.collections) {
          cols.push_back(flutter::EncodableMap{
              {flutter::EncodableValue("name"), flutter::EncodableValue(c.name)},
              {flutter::EncodableValue("createdAt"),
               flutter::EncodableValue(c.created_at)},
              {flutter::EncodableValue("createdByPackage"),
               flutter::EncodableValue(c.created_by_package)},
              {flutter::EncodableValue("recordCount"),
               flutter::EncodableValue(c.record_count)},
          });
        }
        apps.push_back(flutter::EncodableMap{
            {flutter::EncodableValue("packageName"),
             flutter::EncodableValue(app.package_name)},
            {flutter::EncodableValue("collectionCount"),
             flutter::EncodableValue(app.collection_count)},
            {flutter::EncodableValue("recordCount"),
             flutter::EncodableValue(app.record_count)},
            {flutter::EncodableValue("collections"),
             flutter::EncodableValue(cols)},
        });
      }
      result->Success(flutter::EncodableValue(apps));
      return;
    }

    if (method == "insert") {
      if (!args) {
        result->Error("ARG", "collection required");
        return;
      }
      const std::string collection = GetStringArg(*args, "collection");
      const std::string id = GetStringArg(*args, "id");
      const std::string data = GetStringArg(*args, "data");
      if (collection.empty() || data.empty()) {
        result->Error("ARG", "collection and data required");
        return;
      }
      if (id.empty()) {
        result->Error("ARG", "id required");
        return;
      }
      const bool upsert = args ? GetBoolArg(*args, "upsert", false) : false;
      const std::string record_id =
          upsert ? store.UpsertRecord(collection, id, data)
                 : store.InsertRecord(collection, id, data);
      result->Success(flutter::EncodableValue(record_id));
      return;
    }

    if (method == "getAll") {
      if (!args) {
        result->Error("ARG", "collection required");
        return;
      }
      const std::string collection = GetStringArg(*args, "collection");
      flutter::EncodableList list;
      for (const auto& row : store.GetRecords(collection)) {
        list.push_back(flutter::EncodableValue(RecordMap(row)));
      }
      result->Success(flutter::EncodableValue(list));
      return;
    }

    if (method == "getById") {
      if (!args) {
        result->Error("ARG", "collection and id required");
        return;
      }
      const std::string collection = GetStringArg(*args, "collection");
      const std::string id = GetStringArg(*args, "id");
      const auto row = store.GetRecord(collection, id);
      if (!row.has_value()) {
        result->Success();
        return;
      }
      result->Success(flutter::EncodableValue(RecordMap(*row)));
      return;
    }

    if (method == "update") {
      if (!args) {
        result->Error("ARG", "arguments required");
        return;
      }
      const std::string collection = GetStringArg(*args, "collection");
      const std::string id = GetStringArg(*args, "id");
      const std::string data = GetStringArg(*args, "data");
      if (collection.empty() || id.empty() || data.empty()) {
        result->Error("ARG", "collection, id, and data required");
        return;
      }
      store.UpdateRecord(collection, id, data);
      result->Success();
      return;
    }

    if (method == "delete") {
      if (!args) {
        result->Error("ARG", "collection and id required");
        return;
      }
      const std::string collection = GetStringArg(*args, "collection");
      const std::string id = GetStringArg(*args, "id");
      store.DeleteRecord(collection, id);
      result->Success();
      return;
    }

    if (method == "renameCollection") {
      if (!RequireHost(result, is_host_)) return;
      if (!args) {
        result->Error("ARG", "from and to required");
        return;
      }
      store.RenameCollection(GetStringArg(*args, "from"),
                             GetStringArg(*args, "to"));
      result->Success();
      return;
    }

    if (method == "deleteCollection") {
      if (!RequireHost(result, is_host_)) return;
      if (!args) {
        result->Error("ARG", "name required");
        return;
      }
      store.DeleteCollection(GetStringArg(*args, "name"));
      result->Success();
      return;
    }

    result->NotImplemented();
  } catch (const std::exception& e) {
    result->Error("SHARED_DB", e.what());
  }
}

}  // namespace shared_database_windows
