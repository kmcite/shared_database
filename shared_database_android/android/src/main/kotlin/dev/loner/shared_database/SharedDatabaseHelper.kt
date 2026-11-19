package dev.loner.shared_database

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import org.json.JSONException
import org.json.JSONObject

class SharedDatabaseHelper(
    context: Context,
    databasePath: String,
) : SQLiteOpenHelper(context, databasePath, null, DB_VERSION) {

    private val appContext = context.applicationContext

    override fun onCreate(db: SQLiteDatabase) {
        createSchema(db)
    }

    override fun onConfigure(db: SQLiteDatabase) {
        super.onConfigure(db)
        db.setForeignKeyConstraintsEnabled(true)
        db.enableWriteAheadLogging()
        // PRAGMA busy_timeout returns a row; execSQL rejects those on Android.
        db.rawQuery("PRAGMA busy_timeout = 5000", null).use { cursor ->
            cursor.moveToFirst()
        }
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) {
            migrateToV2(db)
        }
        if (oldVersion < 3) {
            createPreferencesTable(db)
        }
    }

    private fun createSchema(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE collections (
                name TEXT PRIMARY KEY NOT NULL,
                created_at INTEGER NOT NULL,
                created_by_package TEXT NOT NULL
            )
            """.trimIndent(),
        )
        db.execSQL(
            """
            CREATE TABLE records (
                id TEXT NOT NULL,
                collection TEXT NOT NULL,
                data TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                created_by_package TEXT NOT NULL,
                updated_by_package TEXT NOT NULL,
                PRIMARY KEY (id, collection),
                FOREIGN KEY (collection) REFERENCES collections(name) ON DELETE CASCADE
            )
            """.trimIndent(),
        )
        db.execSQL(
            "CREATE INDEX idx_records_collection ON records(collection)",
        )
        createPreferencesTable(db)
    }

    private fun createPreferencesTable(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS preferences (
                key TEXT PRIMARY KEY NOT NULL,
                value TEXT NOT NULL,
                updated_at INTEGER NOT NULL,
                updated_by_package TEXT NOT NULL
            )
            """.trimIndent(),
        )
    }

    private fun migrateToV2(db: SQLiteDatabase) {
        db.execSQL(
            "ALTER TABLE collections ADD COLUMN created_by_package TEXT NOT NULL DEFAULT 'legacy'",
        )
        db.execSQL(
            "ALTER TABLE records ADD COLUMN created_by_package TEXT NOT NULL DEFAULT 'legacy'",
        )
        db.execSQL(
            "ALTER TABLE records ADD COLUMN updated_by_package TEXT NOT NULL DEFAULT 'legacy'",
        )
    }

    fun ensureCollection(name: String, callerPackage: String) {
        val now = System.currentTimeMillis()
        val rowId = writableDatabase.compileStatement(
            """
            INSERT OR IGNORE INTO collections (name, created_at, created_by_package)
            VALUES (?, ?, ?)
            """.trimIndent(),
        ).apply {
            bindString(1, name)
            bindLong(2, now)
            bindString(3, callerPackage)
        }.executeInsert()
        if (rowId != -1L) {
        }
    }

    fun listCollectionNames(): List<String> {
        val db = readableDatabase
        val names = mutableListOf<String>()
        db.rawQuery(
            "SELECT name FROM collections ORDER BY name",
            null,
        ).use { cursor ->
            while (cursor.moveToNext()) {
                names.add(cursor.getString(0))
            }
        }
        return names
    }

    fun listCollectionsDetailed(): List<Map<String, Any?>> {
        val db = readableDatabase
        val rows = mutableListOf<Map<String, Any?>>()
        db.rawQuery(
            """
            SELECT c.name, c.created_at, c.created_by_package,
                   (SELECT COUNT(*) FROM records r WHERE r.collection = c.name)
            FROM collections c
            ORDER BY c.created_at DESC
            """.trimIndent(),
            null,
        ).use { cursor ->
            while (cursor.moveToNext()) {
                rows.add(
                    mapOf(
                        "name" to cursor.getString(0),
                        "createdAt" to cursor.getLong(1),
                        "createdByPackage" to cursor.getString(2),
                        "recordCount" to cursor.getInt(3),
                    ),
                )
            }
        }
        return rows
    }

    fun upsertRecord(
        collection: String,
        id: String,
        data: String,
        callerPackage: String,
    ): String {
        ensureCollection(collection, callerPackage)
        upsertRecordInternal(collection, id, data, callerPackage)
        return id
    }

    /// Batch upserts in a single transaction. Each pair is (id, dataJson).
    fun putManyRecords(
        collection: String,
        items: List<Pair<String, String>>,
        callerPackage: String,
    ): List<String> {
        ensureCollection(collection, callerPackage)
        val db = writableDatabase
        val ids = ArrayList<String>(items.size)
        db.beginTransaction()
        try {
            for ((id, data) in items) {
                upsertRecordInternal(collection, id, data, callerPackage)
                ids.add(id)
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
        return ids
    }

    private fun upsertRecordInternal(
        collection: String,
        id: String,
        data: String,
        callerPackage: String,
    ) {
        val now = System.currentTimeMillis()
        writableDatabase.execSQL(
            """
            INSERT INTO records (
                id, collection, data, created_at, updated_at,
                created_by_package, updated_by_package
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id, collection) DO UPDATE SET
                data = excluded.data,
                updated_at = excluded.updated_at,
                updated_by_package = excluded.updated_by_package
            """.trimIndent(),
            arrayOf<Any>(id, collection, data, now, now, callerPackage, callerPackage),
        )
    }

    /// Shallow-merges [patchJson] top-level keys into the stored record data.
    fun patchRecord(
        collection: String,
        id: String,
        patchJson: String,
        callerPackage: String,
    ): String {
        val existing = getRecord(collection, id)
            ?: throw IllegalArgumentException(
                "Record \"$id\" not found in \"$collection\"",
            )
        val base = try {
            JSONObject(existing[SharedDatabaseContract.Columns.DATA] ?: "{}")
        } catch (e: JSONException) {
            throw IllegalArgumentException(
                "Stored data of record \"$id\" is not a JSON object",
            )
        }
        val patch = try {
            JSONObject(patchJson)
        } catch (e: JSONException) {
            throw IllegalArgumentException("patch dataJson must be a JSON object")
        }
        val keys = patch.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            base.put(key, patch.get(key))
        }
        updateRecord(collection, id, base.toString(), callerPackage)
        return id
    }

    fun getCollectionsWatchToken(): Map<String, Long> {
        val db = readableDatabase
        var count = 0
        var fingerprint = 1
        db.rawQuery(
            "SELECT name FROM collections ORDER BY name COLLATE NOCASE",
            null,
        ).use { cursor ->
            while (cursor.moveToNext()) {
                count++
                fingerprint = 31 * fingerprint + cursor.getString(0).hashCode()
            }
        }
        return mapOf(
            "count" to count.toLong(),
            "fingerprint" to fingerprint.toLong(),
        )
    }

    fun getCollectionWatchToken(collection: String): Map<String, Long> {
        val db = readableDatabase
        db.rawQuery(
            """
            SELECT COUNT(*), IFNULL(MAX(updated_at), 0)
            FROM records WHERE collection = ?
            """.trimIndent(),
            arrayOf(collection),
        ).use { cursor ->
            check(cursor.moveToFirst())
            return mapOf(
                "count" to cursor.getLong(0),
                "maxUpdatedAt" to cursor.getLong(1),
            )
        }
    }

    fun getRecordWatchToken(collection: String, id: String): Map<String, Any?> {
        val db = readableDatabase
        db.rawQuery(
            """
            SELECT updated_at FROM records WHERE collection = ? AND id = ?
            """.trimIndent(),
            arrayOf(collection, id),
        ).use { cursor ->
            if (!cursor.moveToFirst()) {
                return mapOf("exists" to false)
            }
            return mapOf(
                "exists" to true,
                "updatedAt" to cursor.getLong(0),
            )
        }
    }

    fun getRecords(
        collection: String,
        limit: Int? = null,
        offset: Int? = null,
    ): List<Map<String, String>> {
        val db = readableDatabase
        val pagination = when {
            limit != null -> " LIMIT ?" + if (offset != null) " OFFSET ?" else ""
            offset != null -> " LIMIT -1 OFFSET ?"
            else -> ""
        }
        val rows = mutableListOf<Map<String, String>>()
        db.rawQuery(
            """
            SELECT id, data, created_at, updated_at,
                   created_by_package, updated_by_package
            FROM records
            WHERE collection = ?
            ORDER BY updated_at DESC
            $pagination
            """.trimIndent(),
            buildList {
                add(collection)
                if (limit != null) add(limit.toString())
                if (offset != null) add(offset.toString())
            }.toTypedArray(),
        ).use { cursor ->
            while (cursor.moveToNext()) {
                rows.add(
                    mapOf(
                        SharedDatabaseContract.Columns.ID to cursor.getString(0),
                        SharedDatabaseContract.Columns.DATA to cursor.getString(1),
                        SharedDatabaseContract.Columns.CREATED_AT to cursor.getLong(2).toString(),
                        SharedDatabaseContract.Columns.UPDATED_AT to cursor.getLong(3).toString(),
                        SharedDatabaseContract.Columns.CREATED_BY to cursor.getString(4),
                        SharedDatabaseContract.Columns.UPDATED_BY to cursor.getString(5),
                    ),
                )
            }
        }
        return rows
    }

    // — Preferences —

    fun getPreferenceValue(key: String): String? {
        readableDatabase.rawQuery(
            "SELECT value FROM preferences WHERE key = ?",
            arrayOf(key),
        ).use { cursor ->
            return if (cursor.moveToFirst()) cursor.getString(0) else null
        }
    }

    fun setPreferenceValue(key: String, value: String, callerPackage: String) {
        writableDatabase.execSQL(
            """
            INSERT INTO preferences (key, value, updated_at, updated_by_package)
            VALUES (?, ?, ?, ?)
            ON CONFLICT(key) DO UPDATE SET
                value = excluded.value,
                updated_at = excluded.updated_at,
                updated_by_package = excluded.updated_by_package
            """.trimIndent(),
            arrayOf<Any>(key, value, System.currentTimeMillis(), callerPackage),
        )
    }

    fun removePreference(key: String, callerPackage: String) {
        writableDatabase.execSQL(
            "DELETE FROM preferences WHERE key = ?",
            arrayOf(key),
        )
    }

    fun listPreferenceKeys(): List<String> {
        val keys = mutableListOf<String>()
        readableDatabase.rawQuery(
            "SELECT key FROM preferences ORDER BY key",
            null,
        ).use { cursor ->
            while (cursor.moveToNext()) {
                keys.add(cursor.getString(0))
            }
        }
        return keys
    }

    fun getPreferenceWatchToken(key: String): Map<String, Any?> {
        readableDatabase.rawQuery(
            "SELECT updated_at FROM preferences WHERE key = ?",
            arrayOf(key),
        ).use { cursor ->
            if (!cursor.moveToFirst()) {
                return mapOf("exists" to false)
            }
            return mapOf(
                "exists" to true,
                "updatedAt" to cursor.getLong(0),
            )
        }
    }

    fun getRecord(collection: String, id: String): Map<String, String>? {
        val db = readableDatabase
        db.rawQuery(
            """
            SELECT id, data, created_at, updated_at,
                   created_by_package, updated_by_package
            FROM records
            WHERE collection = ? AND id = ?
            """.trimIndent(),
            arrayOf(collection, id),
        ).use { cursor ->
            if (!cursor.moveToFirst()) return null
            return mapOf(
                SharedDatabaseContract.Columns.ID to cursor.getString(0),
                SharedDatabaseContract.Columns.DATA to cursor.getString(1),
                SharedDatabaseContract.Columns.CREATED_AT to cursor.getLong(2).toString(),
                SharedDatabaseContract.Columns.UPDATED_AT to cursor.getLong(3).toString(),
                SharedDatabaseContract.Columns.CREATED_BY to cursor.getString(4),
                SharedDatabaseContract.Columns.UPDATED_BY to cursor.getString(5),
            )
        }
    }

    fun updateRecord(
        collection: String,
        id: String,
        data: String,
        callerPackage: String,
    ): Int {
        writableDatabase.execSQL(
            """
            UPDATE records
            SET data = ?, updated_at = ?, updated_by_package = ?
            WHERE collection = ? AND id = ?
            """.trimIndent(),
            arrayOf<Any>(
                data,
                System.currentTimeMillis(),
                callerPackage,
                collection,
                id,
            ),
        )
        return 1
    }

    fun deleteRecord(collection: String, id: String, callerPackage: String): Int {
        writableDatabase.execSQL(
            "DELETE FROM records WHERE collection = ? AND id = ?",
            arrayOf(collection, id),
        )
        return 1
    }

    fun deleteAllRecords(collection: String, callerPackage: String): Int {
        val deleted = writableDatabase.compileStatement(
            "DELETE FROM records WHERE collection = ?",
        ).apply {
            bindString(1, collection)
        }.executeUpdateDelete()
        return deleted
    }

    fun renameCollection(
        from: String,
        to: String,
        callerPackage: String,
    ) {
        if (from == to) return
        val db = writableDatabase
        db.compileStatement(
            "SELECT COUNT(*) FROM collections WHERE name = ?",
        ).apply {
            bindString(1, to)
        }.simpleQueryForLong().let { count ->
            if (count > 0) {
                throw IllegalArgumentException("Collection \"$to\" already exists")
            }
        }
        db.beginTransaction()
        try {
            db.execSQL(
                """
                INSERT INTO collections (name, created_at, created_by_package)
                SELECT ?, created_at, created_by_package FROM collections WHERE name = ?
                """.trimIndent(),
                arrayOf(to, from),
            )
            db.execSQL(
                "UPDATE records SET collection = ? WHERE collection = ?",
                arrayOf(to, from),
            )
            val deleted = db.compileStatement(
                "DELETE FROM collections WHERE name = ?",
            ).apply {
                bindString(1, from)
            }.executeUpdateDelete()
            if (deleted == 0) {
                throw IllegalArgumentException("Collection \"$from\" not found")
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    fun deleteCollection(name: String, callerPackage: String) {
        val deleted = writableDatabase.compileStatement(
            "DELETE FROM collections WHERE name = ?",
        ).apply {
            bindString(1, name)
        }.executeUpdateDelete()
        if (deleted == 0) {
            throw IllegalArgumentException("Collection \"$name\" not found")
        }
    }

    companion object {
        const val DB_VERSION = 3

        fun getInstance(context: Context): SharedDatabaseHelper =
            SharedDatabaseStore.open(context)
    }
}
