package dev.loner.shared_database

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import java.util.UUID

class SharedDatabasePlugin :
    FlutterPlugin,
    SharedDatabaseApi {

    private lateinit var appContext: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        SharedDatabaseApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        SharedDatabaseApi.setUp(binding.binaryMessenger, null)
    }

    private fun callerPackage(): String = appContext.packageName

    private fun helper(): SharedDatabaseHelper = SharedDatabaseStore.open(appContext)

    override fun initialize() {
        helper()
    }

    override fun ensureCollection(name: String) {
        helper().ensureCollection(name, callerPackage())
    }

    override fun getCollections(): List<String> = helper().listCollectionNames()

    override fun renameCollection(from: String, to: String) {
        helper().renameCollection(from, to, callerPackage())
    }

    override fun removeCollection(name: String) {
        helper().deleteCollection(name, callerPackage())
    }

    override fun getCollectionsDetailed(): List<CollectionData> =
        helper().listCollectionsDetailed().map { it.toCollectionData() }

    override fun put(
        collection: String,
        id: String?,
        dataJson: String,
    ): String {
        val recordId = id ?: UUID.randomUUID().toString()
        helper().upsertRecord(collection, recordId, dataJson, callerPackage())
        return recordId
    }

    override fun putMany(
        collection: String,
        records: List<RecordPutRequest>,
    ): List<String> {
        val items = records.map {
            (it.id ?: UUID.randomUUID().toString()) to it.dataJson
        }
        return helper().putManyRecords(collection, items, callerPackage())
    }

    override fun patch(
        collection: String,
        id: String,
        dataJson: String,
    ): String = helper().patchRecord(collection, id, dataJson, callerPackage())

    override fun getById(collection: String, id: String): RecordData? =
        helper().getRecord(collection, id)?.let { row ->
            row.toRecordData(collection)
        }

    override fun getAll(
        collection: String,
        limit: Long?,
        offset: Long?,
    ): List<RecordData> =
        helper()
            .getRecords(collection, limit?.toInt(), offset?.toInt())
            .map { it.toRecordData(collection) }

    override fun removeById(collection: String, id: String) {
        helper().deleteRecord(collection, id, callerPackage())
    }

    override fun removeAll(collection: String) {
        helper().deleteAllRecords(collection, callerPackage())
    }

    override fun getPreferenceValue(key: String): String? = helper().getPreferenceValue(key)

    override fun setPreferenceValue(key: String, value: String) {
        helper().setPreferenceValue(key, value, callerPackage())
    }

    override fun removePreference(key: String) {
        helper().removePreference(key, callerPackage())
    }

    override fun getPreferences(): List<String> = helper().listPreferenceKeys()

    override fun getCollectionsWatchToken(): CollectionsWatchToken {
        val token = helper().getCollectionsWatchToken()
        return CollectionsWatchToken(
            count = token["count"]?.toLong() ?: 0L,
            fingerprint = token["fingerprint"]?.toLong() ?: 0L,
            forceRefresh = false,
        )
    }

    override fun getCollectionWatchToken(collection: String): CollectionWatchToken {
        val token = helper().getCollectionWatchToken(collection)
        return CollectionWatchToken(
            count = token["count"]?.toLong() ?: 0L,
            maxUpdatedAt = token["maxUpdatedAt"]?.toLong() ?: 0L,
            forceRefresh = false,
        )
    }

    override fun getRecordWatchToken(
        collection: String,
        id: String,
    ): RecordWatchToken {
        val token = helper().getRecordWatchToken(collection, id)
        val exists = token["exists"] as? Boolean ?: false
        return RecordWatchToken(
            exists = exists,
            updatedAt = (token["updatedAt"] as? Number)?.toLong(),
            forceRefresh = false,
        )
    }

    override fun getPreferenceWatchToken(key: String): PreferenceWatchToken {
        val token = helper().getPreferenceWatchToken(key)
        val exists = token["exists"] as? Boolean ?: false
        return PreferenceWatchToken(
            exists = exists,
            updatedAt = (token["updatedAt"] as? Number)?.toLong(),
            forceRefresh = false,
        )
    }

    private fun Map<String, String>.toRecordData(collection: String): RecordData = RecordData(
        id = this[SharedDatabaseContract.Columns.ID] ?: "",
        collection = collection,
        dataJson = this[SharedDatabaseContract.Columns.DATA] ?: "{}",
        createdAt = this[SharedDatabaseContract.Columns.CREATED_AT]?.toLongOrNull() ?: 0L,
        updatedAt = this[SharedDatabaseContract.Columns.UPDATED_AT]?.toLongOrNull() ?: 0L,
        createdBy = this[SharedDatabaseContract.Columns.CREATED_BY] ?: "",
        updatedBy = this[SharedDatabaseContract.Columns.UPDATED_BY] ?: "",
    )

    private fun Map<String, Any?>.toCollectionData(): CollectionData = CollectionData(
        name = this["name"] as? String ?: "",
        createdAt = (this["createdAt"] as? Number)?.toLong() ?: 0L,
        createdByPackage = this["createdByPackage"] as? String ?: "",
        recordCount = (this["recordCount"] as? Number)?.toLong() ?: 0L,
    )
}