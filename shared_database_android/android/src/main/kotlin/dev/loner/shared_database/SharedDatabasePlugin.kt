package dev.loner.shared_database

import android.content.ContentResolver
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.net.Uri
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler

class SharedDatabasePlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var appContext: Context

    private var isHost = false
    private var authority: String = SharedDatabaseContract.AUTHORITY

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "shared_database")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    private fun hostPackage(): String = appContext.packageName

    private fun requireHost(result: MethodChannel.Result): Boolean {
        if (!isHost) {
            result.error("HOST_ONLY", "Only the database host app can call this method", null)
            return false
        }
        return true
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "initialize" -> {
                    isHost = call.argument<Boolean>("isHost") ?: false
                    authority =
                        call.argument<String>("authority")
                            ?: SharedDatabaseContract.AUTHORITY
                    result.success(null)
                }

                "ensureCollection" -> {
                    val name = call.argument<String>("name") ?: return result.error(
                        "ARG",
                        "name required",
                        null,
                    )
                    if (isHost) {
                        SharedDatabaseHelper.getInstance(appContext).ensureCollection(
                            name,
                            hostPackage(),
                        )
                    } else {
                        resolver().insert(collectionUri(name), ContentValues())?.let { }
                            ?: ensureCollectionViaProvider(name)
                    }
                    result.success(null)
                }

                "listCollections" -> {
                    result.success(listCollections())
                }

                "getCollectionsWatchToken" -> {
                    result.success(getCollectionsWatchToken())
                }

                "getCollectionWatchToken" -> {
                    val collection = call.argument<String>("collection")
                        ?: return result.error("ARG", "collection required", null)
                    result.success(getCollectionWatchToken(collection))
                }

                "getRecordWatchToken" -> {
                    val collection = call.argument<String>("collection")
                        ?: return result.error("ARG", "collection required", null)
                    val id = call.argument<String>("id")
                        ?: return result.error("ARG", "id required", null)
                    result.success(getRecordWatchToken(collection, id))
                }

                "getOverview" -> {
                    if (!requireHost(result)) return
                    result.success(
                        SharedDatabaseHelper.getInstance(appContext).getOverview(),
                    )
                }

                "listCollectionsDetailed" -> {
                    if (!requireHost(result)) return
                    result.success(
                        SharedDatabaseHelper.getInstance(appContext).listCollectionsDetailed(),
                    )
                }

                "listAppsDetailed" -> {
                    if (!requireHost(result)) return
                    result.success(
                        SharedDatabaseHelper.getInstance(appContext).listAppsDetailed(),
                    )
                }

                "insert" -> {
                    val collection = call.argument<String>("collection")
                        ?: return result.error("ARG", "collection required", null)
                    val id = call.argument<String>("id")
                    val data = call.argument<String>("data")
                        ?: return result.error("ARG", "data required", null)
                    val upsert = call.argument<Boolean>("upsert") ?: false
                    result.success(insert(collection, id, data, upsert))
                }

                "getAll" -> {
                    val collection = call.argument<String>("collection")
                        ?: return result.error("ARG", "collection required", null)
                    result.success(getAll(collection))
                }

                "getById" -> {
                    val collection = call.argument<String>("collection")
                        ?: return result.error("ARG", "collection required", null)
                    val id = call.argument<String>("id")
                        ?: return result.error("ARG", "id required", null)
                    result.success(getById(collection, id))
                }

                "update" -> {
                    val collection = call.argument<String>("collection")
                        ?: return result.error("ARG", "collection required", null)
                    val id = call.argument<String>("id")
                        ?: return result.error("ARG", "id required", null)
                    val data = call.argument<String>("data")
                        ?: return result.error("ARG", "data required", null)
                    update(collection, id, data)
                    result.success(null)
                }

                "delete" -> {
                    val collection = call.argument<String>("collection")
                        ?: return result.error("ARG", "collection required", null)
                    val id = call.argument<String>("id")
                        ?: return result.error("ARG", "id required", null)
                    delete(collection, id)
                    result.success(null)
                }

                "renameCollection" -> {
                    if (!requireHost(result)) return
                    val from = call.argument<String>("from")
                        ?: return result.error("ARG", "from required", null)
                    val to = call.argument<String>("to")
                        ?: return result.error("ARG", "to required", null)
                    SharedDatabaseHelper.getInstance(appContext).renameCollection(
                        from,
                        to,
                        hostPackage(),
                    )
                    result.success(null)
                }

                "deleteCollection" -> {
                    if (!requireHost(result)) return
                    val name = call.argument<String>("name")
                        ?: return result.error("ARG", "name required", null)
                    SharedDatabaseHelper.getInstance(appContext).deleteCollection(
                        name,
                        hostPackage(),
                    )
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("SHARED_DB", e.message, null)
        }
    }

    private fun resolver(): ContentResolver = appContext.contentResolver

    private fun baseUri(): Uri = Uri.parse("content://$authority")

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

    private fun ensureCollectionViaProvider(name: String) {
        val values = ContentValues()
        resolver().update(collectionUri(name), values, null, null)
    }

    private fun listCollections(): List<String> {
        if (isHost) {
            return SharedDatabaseHelper.getInstance(appContext).listCollectionNames()
        }
        val names = mutableListOf<String>()
        resolver().query(
            baseUri().buildUpon().appendPath("collections").build(),
            null,
            null,
            null,
            null,
        )?.use { cursor -> readCollectionNames(cursor, names) }
        return names
    }

    private fun readCollectionNames(cursor: Cursor, names: MutableList<String>) {
        while (cursor.moveToNext()) {
            names.add(cursor.getString(0))
        }
    }

    private fun insert(
        collection: String,
        id: String?,
        data: String,
        upsert: Boolean,
    ): String {
        val recordId = id ?: java.util.UUID.randomUUID().toString()
        if (isHost) {
            val helper = SharedDatabaseHelper.getInstance(appContext)
            if (upsert) {
                helper.upsertRecord(collection, recordId, data, hostPackage())
            } else {
                helper.insertRecord(collection, recordId, data, hostPackage())
            }
            return recordId
        }
        val values = ContentValues().apply {
            put(SharedDatabaseContract.Columns.ID, recordId)
            put(SharedDatabaseContract.Columns.DATA, data)
        }
        resolver().insert(recordsUri(collection), values)
        return recordId
    }

    private fun getAll(collection: String): List<Map<String, String>> {
        if (isHost) {
            return SharedDatabaseHelper.getInstance(appContext).getRecords(collection)
        }
        val rows = mutableListOf<Map<String, String>>()
        resolver().query(recordsUri(collection), null, null, null, null)
            ?.use { cursor -> readRecordRows(cursor, rows) }
        return rows
    }

    private fun getById(collection: String, id: String): Map<String, String>? {
        if (isHost) {
            return SharedDatabaseHelper.getInstance(appContext).getRecord(collection, id)
        }
        resolver().query(recordUri(collection, id), null, null, null, null)?.use { cursor ->
            if (!cursor.moveToFirst()) return null
            return mapOf(
                SharedDatabaseContract.Columns.ID to cursor.getString(0),
                SharedDatabaseContract.Columns.DATA to cursor.getString(1),
            )
        }
        return null
    }

    private fun readRecordRows(cursor: Cursor, rows: MutableList<Map<String, String>>) {
        while (cursor.moveToNext()) {
            rows.add(
                mapOf(
                    SharedDatabaseContract.Columns.ID to cursor.getString(0),
                    SharedDatabaseContract.Columns.DATA to cursor.getString(1),
                ),
            )
        }
    }

    private fun update(collection: String, id: String, data: String) {
        if (isHost) {
            SharedDatabaseHelper.getInstance(appContext).updateRecord(
                collection,
                id,
                data,
                hostPackage(),
            )
            return
        }
        val values = ContentValues().apply {
            put(SharedDatabaseContract.Columns.DATA, data)
        }
        resolver().update(recordUri(collection, id), values, null, null)
    }

    private fun delete(collection: String, id: String) {
        if (isHost) {
            SharedDatabaseHelper.getInstance(appContext).deleteRecord(
                collection,
                id,
                hostPackage(),
            )
            return
        }
        resolver().delete(recordUri(collection, id), null, null)
    }

    private fun getCollectionsWatchToken(): Map<String, Long> {
        if (isHost) {
            return SharedDatabaseHelper.getInstance(appContext).getCollectionsWatchToken()
        }
        val names = listCollections()
        var fingerprint = 1
        for (name in names) {
            fingerprint = 31 * fingerprint + name.hashCode()
        }
        return mapOf(
            "count" to names.size.toLong(),
            "fingerprint" to fingerprint.toLong(),
        )
    }

    private fun getCollectionWatchToken(collection: String): Map<String, Any> {
        if (isHost) {
            return SharedDatabaseHelper.getInstance(appContext).getCollectionWatchToken(collection)
        }
        return mapOf("forceRefresh" to true)
    }

    private fun getRecordWatchToken(collection: String, id: String): Map<String, Any?> {
        if (isHost) {
            return SharedDatabaseHelper.getInstance(appContext).getRecordWatchToken(collection, id)
        }
        return mapOf("forceRefresh" to true)
    }
}
