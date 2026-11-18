package dev.loner.shared_database

import android.content.ContentResolver
import android.content.ContentValues
import android.content.Context
import android.os.Bundle
import android.database.Cursor
import android.net.Uri
import io.flutter.embedding.engine.plugins.FlutterPlugin
import org.json.JSONException
import org.json.JSONObject
import java.util.UUID

class SharedDatabasePlugin :
    FlutterPlugin,
    SharedDatabaseApi {

    private lateinit var appContext: Context

    /// True when this plugin instance runs inside the app that owns the
    /// provider (package == authority). Clients go through ContentResolver.
    private val isHost: Boolean
        get() = appContext.packageName == SharedDatabaseContract.AUTHORITY

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        SharedDatabaseApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        SharedDatabaseApi.setUp(binding.binaryMessenger, null)
    }

    private fun hostPackage(): String = appContext.packageName

    private fun helper(): SharedDatabaseHelper =
        SharedDatabaseHelper.getInstance(appContext)

    // — SharedDatabaseApi —

    override fun initialize() {
        // Stateless: host detection is derived from the package name and the
        // authority is a fixed contract constant.
    }

    override fun ensureCollection(name: String) {
        if (isHost) {
            helper().ensureCollection(name, hostPackage())
        } else {
            resolver().insert(collectionUri(name), ContentValues())
                ?: ensureCollectionViaProvider(name)
        }
    }

    override fun getCollections(): List<String> {
        if (isHost) {
            return helper().listCollectionNames()
        }
        val names = mutableListOf<String>()
        resolver().query(
            baseUri().buildUpon().appendPath("collections").build(),
            null,
            null,
            null,
            null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                names.add(cursor.getString(0))
            }
        }
        return names
    }

    override fun renameCollection(from: String, to: String) {
        if (isHost) {
            helper().renameCollection(from, to, hostPackage())
        } else {
            resolver().call(
                baseUri(),
                CALL_RENAME_COLLECTION,
                null,
                Bundle().apply {
                    putString(EXTRA_FROM, from)
                    putString(EXTRA_TO, to)
                },
            )
        }
    }

    override fun removeCollection(name: String) {
        if (isHost) {
            helper().deleteCollection(name, hostPackage())
        } else {
            resolver().call(
                baseUri(),
                CALL_DELETE_COLLECTION,
                null,
                Bundle().apply { putString(EXTRA_NAME, name) },
            )
        }
    }

    override fun getCollectionsDetailed(): List<CollectionData> {
        if (isHost) {
            return helper().listCollectionsDetailed().map { it.toCollectionData() }
        }
        val rows = mutableListOf<CollectionData>()
        resolver().query(
            baseUri().buildUpon()
                .appendPath(SharedDatabaseContract.Paths.COLLECTIONS)
                .build(),
            COLLECTIONS_DETAILED_PROJECTION,
            null,
            null,
            null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                rows.add(
                    CollectionData(
                        name = cursor.getString(
                            cursor.getColumnIndexOrThrow(SharedDatabaseContract.Columns.COLLECTION),
                        ),
                        createdAt = cursor.getLong(
                            cursor.getColumnIndexOrThrow(SharedDatabaseContract.Columns.CREATED_AT),
                        ),
                        createdByPackage = cursor.getString(
                            cursor.getColumnIndexOrThrow(SharedDatabaseContract.Columns.CREATED_BY),
                        ),
                        recordCount = cursor.getLong(
                            cursor.getColumnIndexOrThrow(SharedDatabaseContract.Columns.RECORD_COUNT),
                        ),
                    ),
                )
            }
        }
        return rows
    }

    override fun put(
        collection: String,
        id: String?,
        dataJson: String,
    ): String {
        val recordId = id ?: UUID.randomUUID().toString()
        if (isHost) {
            helper().upsertRecord(collection, recordId, dataJson, hostPackage())
        } else {
            val values = ContentValues().apply {
                put(SharedDatabaseContract.Columns.ID, recordId)
                put(SharedDatabaseContract.Columns.DATA, dataJson)
            }
            resolver().insert(recordsUri(collection), values)
        }
        return recordId
    }

    override fun putMany(
        collection: String,
        records: List<RecordPutRequest>,
    ): List<String> {
        val items = records.map {
            (it.id ?: UUID.randomUUID().toString()) to it.dataJson
        }
        if (isHost) {
            return helper().putManyRecords(collection, items, hostPackage())
        }
        return items.map { (recordId, dataJson) ->
            val values = ContentValues().apply {
                put(SharedDatabaseContract.Columns.ID, recordId)
                put(SharedDatabaseContract.Columns.DATA, dataJson)
            }
            resolver().insert(recordsUri(collection), values)
            recordId
        }
    }

    override fun patch(
        collection: String,
        id: String,
        dataJson: String,
    ): String {
        if (isHost) {
            return helper().patchRecord(collection, id, dataJson, hostPackage())
        }
        val existing = getById(collection, id)
            ?: throw FlutterError(
                "NOT_FOUND",
                "Record \"$id\" not found in \"$collection\"",
            )
        val merged = mergeJsonPatch(existing.dataJson, dataJson)
        val values = ContentValues().apply {
            put(SharedDatabaseContract.Columns.DATA, merged)
        }
        resolver().update(recordUri(collection, id), values, null, null)
        return id
    }

    override fun getById(collection: String, id: String): RecordData? {
        if (isHost) {
            return helper().getRecord(collection, id)?.let { row ->
                row.toRecordData(collection)
            }
        }
        resolver().query(recordUri(collection, id), RECORD_PROJECTION, null, null, null)
            ?.use { cursor ->
                if (!cursor.moveToFirst()) return null
                return cursorToRecordData(cursor, collection)
            }
        return null
    }

    override fun getAll(
        collection: String,
        limit: Long?,
        offset: Long?,
    ): List<RecordData> {
        if (isHost) {
            return helper()
                .getRecords(collection, limit?.toInt(), offset?.toInt())
                .map { it.toRecordData(collection) }
        }
        val rows = mutableListOf<RecordData>()
        resolver().query(recordsUri(collection), RECORD_PROJECTION, null, null, null)
            ?.use { cursor ->
                while (cursor.moveToNext()) {
                    rows.add(cursorToRecordData(cursor, collection))
                }
            }
        var result: List<RecordData> = rows
        offset?.toInt()?.takeIf { it > 0 }?.let { result = result.drop(it) }
        limit?.toInt()?.let { result = result.take(it) }
        return result
    }

    override fun removeById(collection: String, id: String) {
        if (isHost) {
            helper().deleteRecord(collection, id, hostPackage())
        } else {
            resolver().delete(recordUri(collection, id), null, null)
        }
    }

    override fun removeAll(collection: String) {
        if (isHost) {
            helper().deleteAllRecords(collection, hostPackage())
        } else {
            resolver().delete(recordsUri(collection), null, null)
        }
    }

    // — Preferences —

    override fun getPreferenceValue(key: String): String? {
        if (isHost) {
            return helper().getPreferenceValue(key)
        }
        resolver().query(
            preferenceUri(key),
            arrayOf(SharedDatabaseContract.Columns.VALUE),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) return cursor.getString(0)
        }
        return null
    }

    override fun setPreferenceValue(key: String, value: String) {
        if (isHost) {
            helper().setPreferenceValue(key, value, hostPackage())
            return
        }
        val values = ContentValues().apply {
            put(SharedDatabaseContract.Columns.VALUE, value)
        }
        val updated = resolver().update(preferenceUri(key), values, null, null)
        if (updated == 0) {
            resolver().insert(preferenceUri(key), values)
        }
    }

    override fun removePreference(key: String) {
        if (isHost) {
            helper().removePreference(key, hostPackage())
        } else {
            resolver().delete(preferenceUri(key), null, null)
        }
    }

    override fun getPreferences(): List<String> {
        if (isHost) {
            return helper().listPreferenceKeys()
        }
        val keys = mutableListOf<String>()
        resolver().query(
            preferencesUri(),
            arrayOf(SharedDatabaseContract.Columns.KEY),
            null,
            null,
            null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                keys.add(cursor.getString(0))
            }
        }
        return keys
    }

    // — Watch tokens —

    override fun getCollectionsWatchToken(): CollectionsWatchToken {
        if (isHost) {
            val token = helper().getCollectionsWatchToken()
            return CollectionsWatchToken(
                count = token["count"]?.toLong() ?: 0L,
                fingerprint = token["fingerprint"]?.toLong() ?: 0L,
                forceRefresh = false,
            )
        }
        val names = getCollections()
        var fingerprint = 1L
        for (name in names) {
            fingerprint = 31 * fingerprint + name.hashCode()
        }
        return CollectionsWatchToken(
            count = names.size.toLong(),
            fingerprint = fingerprint,
            forceRefresh = false,
        )
    }

    override fun getCollectionWatchToken(collection: String): CollectionWatchToken {
        if (isHost) {
            val token = helper().getCollectionWatchToken(collection)
            return CollectionWatchToken(
                count = token["count"]?.toLong() ?: 0L,
                maxUpdatedAt = token["maxUpdatedAt"]?.toLong() ?: 0L,
                forceRefresh = false,
            )
        }
        return CollectionWatchToken(count = 0, maxUpdatedAt = 0, forceRefresh = true)
    }

    override fun getRecordWatchToken(
        collection: String,
        id: String,
    ): RecordWatchToken {
        if (isHost) {
            val token = helper().getRecordWatchToken(collection, id)
            val exists = token["exists"] as? Boolean ?: false
            return RecordWatchToken(
                exists = exists,
                updatedAt = (token["updatedAt"] as? Number)?.toLong(),
                forceRefresh = false,
            )
        }
        return RecordWatchToken(exists = false, updatedAt = null, forceRefresh = true)
    }

    override fun getPreferenceWatchToken(key: String): PreferenceWatchToken {
        if (isHost) {
            val token = helper().getPreferenceWatchToken(key)
            val exists = token["exists"] as? Boolean ?: false
            return PreferenceWatchToken(
                exists = exists,
                updatedAt = (token["updatedAt"] as? Number)?.toLong(),
                forceRefresh = false,
            )
        }
        return PreferenceWatchToken(exists = false, updatedAt = null, forceRefresh = true)
    }

    // — ContentResolver plumbing (client apps) —

    private fun resolver(): ContentResolver = appContext.contentResolver

    private fun baseUri(): Uri =
        Uri.parse("content://${SharedDatabaseContract.AUTHORITY}")

    private fun collectionUri(name: String): Uri =
        baseUri().buildUpon()
            .appendPath("collections")
            .appendPath(name)
            .build()

    private fun recordsUri(collection: String): Uri =
        collectionUri(collection).buildUpon()
            .appendPath("records")
            .build()

    private fun recordUri(collection: String, id: String): Uri =
        recordsUri(collection).buildUpon()
            .appendPath(id)
            .build()

    private fun preferencesUri(): Uri =
        baseUri().buildUpon()
            .appendPath(SharedDatabaseContract.Paths.PREFERENCES)
            .build()

    private fun preferenceUri(key: String): Uri =
        preferencesUri().buildUpon()
            .appendPath(key)
            .build()

    private fun ensureCollectionViaProvider(name: String) {
        val values = ContentValues()
        resolver().update(collectionUri(name), values, null, null)
    }

    /// Shallow-merges [patch] top-level keys into [base]; both must be JSON objects.
    private fun mergeJsonPatch(base: String, patch: String): String {
        return try {
            val baseObj = JSONObject(base)
            val patchObj = JSONObject(patch)
            val keys = patchObj.keys()
            while (keys.hasNext()) {
                val key = keys.next()
                baseObj.put(key, patchObj.get(key))
            }
            baseObj.toString()
        } catch (e: JSONException) {
            throw FlutterError(
                "INVALID_JSON",
                "patch dataJson and stored data must be JSON objects",
            )
        }
    }

    private fun cursorToRecordData(cursor: Cursor, collection: String): RecordData {
        fun col(name: String): String? {
            val idx = cursor.getColumnIndex(name)
            return if (idx >= 0 && !cursor.isNull(idx)) cursor.getString(idx) else null
        }
        return RecordData(
            id = col(SharedDatabaseContract.Columns.ID) ?: "",
            collection = collection,
            dataJson = col(SharedDatabaseContract.Columns.DATA) ?: "{}",
            createdAt = col(SharedDatabaseContract.Columns.CREATED_AT)?.toLongOrNull() ?: 0L,
            updatedAt = col(SharedDatabaseContract.Columns.UPDATED_AT)?.toLongOrNull() ?: 0L,
            createdBy = col(SharedDatabaseContract.Columns.CREATED_BY) ?: "",
            updatedBy = col(SharedDatabaseContract.Columns.UPDATED_BY) ?: "",
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

    companion object {
        private const val CALL_RENAME_COLLECTION = "renameCollection"
        private const val CALL_DELETE_COLLECTION = "deleteCollection"
        private const val EXTRA_FROM = "from"
        private const val EXTRA_TO = "to"
        private const val EXTRA_NAME = "name"

        private val COLLECTIONS_DETAILED_PROJECTION = arrayOf(
            SharedDatabaseContract.Columns.COLLECTION,
            SharedDatabaseContract.Columns.CREATED_AT,
            SharedDatabaseContract.Columns.CREATED_BY,
            SharedDatabaseContract.Columns.RECORD_COUNT,
        )

        private val RECORD_PROJECTION = arrayOf(
            SharedDatabaseContract.Columns.ID,
            SharedDatabaseContract.Columns.DATA,
            SharedDatabaseContract.Columns.CREATED_AT,
            SharedDatabaseContract.Columns.UPDATED_AT,
            SharedDatabaseContract.Columns.CREATED_BY,
            SharedDatabaseContract.Columns.UPDATED_BY,
        )
    }
}
