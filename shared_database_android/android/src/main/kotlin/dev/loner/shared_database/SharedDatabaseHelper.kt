package dev.loner.shared_database

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

class SharedDatabaseHelper(context: Context) :
    SQLiteOpenHelper(context, SharedDatabaseContract.DB_NAME, null, DB_VERSION) {

    private val appContext = context.applicationContext

    override fun onCreate(db: SQLiteDatabase) {
        createSchema(db)
    }

    override fun onConfigure(db: SQLiteDatabase) {
        super.onConfigure(db)
        db.setForeignKeyConstraintsEnabled(true)
        db.enableWriteAheadLogging()
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) {
            migrateToV2(db)
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
        db.execSQL(
            """
            CREATE TABLE access_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                occurred_at INTEGER NOT NULL,
                caller_package TEXT NOT NULL,
                action TEXT NOT NULL,
                collection_name TEXT,
                record_id TEXT
            )
            """.trimIndent(),
        )
        db.execSQL(
            "CREATE INDEX idx_access_log_occurred_at ON access_log(occurred_at DESC)",
        )
        db.execSQL(
            "CREATE INDEX idx_access_log_caller ON access_log(caller_package)",
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
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS access_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                occurred_at INTEGER NOT NULL,
                caller_package TEXT NOT NULL,
                action TEXT NOT NULL,
                collection_name TEXT,
                record_id TEXT
            )
            """.trimIndent(),
        )
        db.execSQL(
            "CREATE INDEX IF NOT EXISTS idx_access_log_occurred_at ON access_log(occurred_at DESC)",
        )
        db.execSQL(
            "CREATE INDEX IF NOT EXISTS idx_access_log_caller ON access_log(caller_package)",
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
            logAccess(callerPackage, ACTION_ENSURE_COLLECTION, name, null)
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

    fun listAppsDetailed(): List<Map<String, Any?>> {
        val collections = listCollectionsDetailed()
        val byName = collections.associateBy { it["name"] as String }
        val byApp = linkedMapOf<String, LinkedHashMap<String, Map<String, Any?>>>()
        val recordCounts = mutableMapOf<String, Int>()

        fun collectionsFor(pkg: String) =
            byApp.getOrPut(pkg) { linkedMapOf() }

        for (c in collections) {
            val pkg = c["createdByPackage"] as String
            collectionsFor(pkg)[c["name"] as String] = c
        }

        readableDatabase.rawQuery(
            """
            SELECT collection, created_by_package, COUNT(*)
            FROM records
            GROUP BY collection, created_by_package
            """.trimIndent(),
            null,
        ).use { cursor ->
            while (cursor.moveToNext()) {
                val collection = cursor.getString(0)
                val pkg = cursor.getString(1)
                val count = cursor.getInt(2)
                recordCounts[pkg] = (recordCounts[pkg] ?: 0) + count
                val info = byName[collection] ?: continue
                collectionsFor(pkg)[collection] = info
            }
        }

        return byApp.entries.map { (pkg, cols) ->
            mapOf(
                "packageName" to pkg,
                "collectionCount" to cols.size,
                "recordCount" to (recordCounts[pkg] ?: 0),
                "collections" to cols.values.toList(),
            )
        }.sortedBy { it["packageName"] as String }
    }

    fun insertRecord(
        collection: String,
        id: String,
        data: String,
        callerPackage: String,
    ): String {
        ensureCollection(collection, callerPackage)
        val now = System.currentTimeMillis()
        writableDatabase.execSQL(
            """
            INSERT INTO records (
                id, collection, data, created_at, updated_at,
                created_by_package, updated_by_package
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """.trimIndent(),
            arrayOf<Any>(id, collection, data, now, now, callerPackage, callerPackage),
        )
        logAccess(callerPackage, ACTION_INSERT, collection, id)
        return id
    }

    fun upsertRecord(
        collection: String,
        id: String,
        data: String,
        callerPackage: String,
    ): String {
        ensureCollection(collection, callerPackage)
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
        logAccess(callerPackage, ACTION_UPDATE, collection, id)
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

    fun getRecords(collection: String): List<Map<String, String>> {
        val db = readableDatabase
        val rows = mutableListOf<Map<String, String>>()
        db.rawQuery(
            """
            SELECT id, data, created_at, updated_at,
                   created_by_package, updated_by_package
            FROM records
            WHERE collection = ?
            ORDER BY updated_at DESC
            """.trimIndent(),
            arrayOf(collection),
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
        logAccess(callerPackage, ACTION_UPDATE, collection, id)
        return 1
    }

    fun deleteRecord(collection: String, id: String, callerPackage: String): Int {
        writableDatabase.execSQL(
            "DELETE FROM records WHERE collection = ? AND id = ?",
            arrayOf(collection, id),
        )
        logAccess(callerPackage, ACTION_DELETE, collection, id)
        return 1
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
        logAccess(callerPackage, ACTION_RENAME_COLLECTION, from, to)
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
        logAccess(callerPackage, ACTION_DELETE_COLLECTION, name, null)
    }

    fun logAccess(
        callerPackage: String,
        action: String,
        collection: String?,
        recordId: String?,
    ) {
        // Activity log is unused by the manager UI.
    }

    fun getOverview(): Map<String, Any?> {
        val db = readableDatabase
        var collections = 0
        var records = 0
        db.rawQuery("SELECT COUNT(*) FROM collections", null).use { c ->
            if (c.moveToFirst()) collections = c.getInt(0)
        }
        db.rawQuery("SELECT COUNT(*) FROM records", null).use { c ->
            if (c.moveToFirst()) records = c.getInt(0)
        }
        return mapOf(
            "collectionCount" to collections,
            "recordCount" to records,
            "hostPackage" to appContext.packageName,
        )
    }

    companion object {
        const val DB_VERSION = 2

        const val ACTION_ENSURE_COLLECTION = "ensure_collection"
        const val ACTION_INSERT = "insert"
        const val ACTION_UPDATE = "update"
        const val ACTION_DELETE = "delete"
        const val ACTION_QUERY_COLLECTIONS = "query_collections"
        const val ACTION_QUERY_RECORDS = "query_records"
        const val ACTION_QUERY_RECORD = "query_record"
        const val ACTION_ADMIN_VIEW = "admin_view"
        const val ACTION_RENAME_COLLECTION = "rename_collection"
        const val ACTION_DELETE_COLLECTION = "delete_collection"

        @Volatile
        private var instance: SharedDatabaseHelper? = null

        fun getInstance(context: Context): SharedDatabaseHelper {
            return instance ?: synchronized(this) {
                instance ?: SharedDatabaseHelper(
                    context.applicationContext,
                ).also { instance = it }
            }
        }
    }
}
