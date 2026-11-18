package dev.loner.shared_database

import android.content.ContentProvider
import android.content.ContentValues
import android.content.UriMatcher
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import java.util.UUID

/**
 * Host-only: owns the single [SharedDatabaseContract.DB_NAME] file. Client apps talk to this
 * provider via [android.content.ContentResolver] using the fixed [SharedDatabaseContract.AUTHORITY].
 */
class SharedDatabaseProvider : ContentProvider() {

    private lateinit var db: SharedDatabaseHelper

    private val matcher =
        UriMatcher(UriMatcher.NO_MATCH).apply {
            addURI(SharedDatabaseContract.AUTHORITY, "collections", COLLECTIONS)
            addURI(
                SharedDatabaseContract.AUTHORITY,
                "collections/*",
                COLLECTION,
            )
            addURI(
                SharedDatabaseContract.AUTHORITY,
                "collections/*/records",
                RECORDS,
            )
            addURI(
                SharedDatabaseContract.AUTHORITY,
                "collections/*/records/*",
                RECORD,
            )
            addURI(
                SharedDatabaseContract.AUTHORITY,
                "preferences",
                PREFERENCES,
            )
            addURI(
                SharedDatabaseContract.AUTHORITY,
                "preferences/*",
                PREFERENCE,
            )
        }

    override fun onCreate(): Boolean {
        val ctx = context ?: return false
        db = SharedDatabaseHelper.getInstance(ctx)
        return true
    }

    private fun caller(): String {
        val ctx = context ?: return "unknown"
        return CallerIdentity.resolve(ctx)
    }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? {
        return when (matcher.match(uri)) {
            COLLECTIONS -> {
                val cursor = MatrixCursor(COLLECTIONS_COLUMNS)
                for (row in db.listCollectionsDetailed()) {
                    cursor.addRow(
                        arrayOf(
                            row["name"],
                            row["createdAt"],
                            row["createdByPackage"],
                            row["recordCount"],
                        ),
                    )
                }
                cursor
            }

            RECORDS -> {
                val collection = uri.pathSegments[1]
                val cursor = MatrixCursor(RECORD_COLUMNS)
                for (row in db.getRecords(collection)) {
                    cursor.addRow(
                        arrayOf(
                            row[SharedDatabaseContract.Columns.ID],
                            row[SharedDatabaseContract.Columns.DATA],
                            row[SharedDatabaseContract.Columns.CREATED_AT],
                            row[SharedDatabaseContract.Columns.UPDATED_AT],
                            row[SharedDatabaseContract.Columns.CREATED_BY],
                            row[SharedDatabaseContract.Columns.UPDATED_BY],
                        ),
                    )
                }
                cursor
            }

            RECORD -> {
                val collection = uri.pathSegments[1]
                val id = uri.pathSegments[3]
                val row = db.getRecord(collection, id) ?: return null
                val cursor = MatrixCursor(RECORD_COLUMNS)
                cursor.addRow(
                    arrayOf(
                        row[SharedDatabaseContract.Columns.ID],
                        row[SharedDatabaseContract.Columns.DATA],
                        row[SharedDatabaseContract.Columns.CREATED_AT],
                        row[SharedDatabaseContract.Columns.UPDATED_AT],
                        row[SharedDatabaseContract.Columns.CREATED_BY],
                        row[SharedDatabaseContract.Columns.UPDATED_BY],
                    ),
                )
                cursor
            }

            PREFERENCES -> {
                val cursor = MatrixCursor(
                    arrayOf(SharedDatabaseContract.Columns.KEY),
                )
                for (key in db.listPreferenceKeys()) {
                    cursor.addRow(arrayOf(key))
                }
                cursor
            }

            PREFERENCE -> {
                val key = uri.lastPathSegment ?: return null
                val value = db.getPreferenceValue(key) ?: return null
                val cursor = MatrixCursor(
                    arrayOf(SharedDatabaseContract.Columns.VALUE),
                )
                cursor.addRow(arrayOf(value))
                cursor
            }

            else -> null
        }
    }

    override fun getType(uri: Uri): String? = null

    override fun call(
        method: String,
        arg: String?,
        extras: android.os.Bundle?,
    ): android.os.Bundle? {
        val pkg = caller()
        return when (method) {
            "renameCollection" -> {
                val from = extras?.getString("from") ?: return null
                val to = extras.getString("to") ?: return null
                db.renameCollection(from, to, pkg)
                android.os.Bundle()
            }

            "deleteCollection" -> {
                val name = extras?.getString("name") ?: return null
                db.deleteCollection(name, pkg)
                android.os.Bundle()
            }

            else -> super.call(method, arg, extras)
        }
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? {
        values ?: return null
        val pkg = caller()
        return when (matcher.match(uri)) {
            COLLECTION -> {
                val name = uri.lastPathSegment ?: return null
                db.ensureCollection(name, pkg)
                uri
            }

            RECORDS -> {
                val collection = uri.pathSegments[1]
                val id = values.getAsString(SharedDatabaseContract.Columns.ID)
                    ?: UUID.randomUUID().toString()
                val data = values.getAsString(SharedDatabaseContract.Columns.DATA) ?: "{}"
                db.upsertRecord(collection, id, data, pkg)
                Uri.parse(
                    "content://${SharedDatabaseContract.AUTHORITY}/collections/$collection/records/$id",
                )
            }

            PREFERENCE -> {
                val key = uri.lastPathSegment ?: return null
                val value = values.getAsString(SharedDatabaseContract.Columns.VALUE)
                    ?: return null
                db.setPreferenceValue(key, value, pkg)
                uri
            }

            else -> null
        }
    }

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int {
        return when (matcher.match(uri)) {
            RECORD -> {
                val collection = uri.pathSegments[1]
                val id = uri.pathSegments[3]
                db.deleteRecord(collection, id, caller())
            }

            RECORDS -> {
                val collection = uri.pathSegments[1]
                db.deleteAllRecords(collection, caller())
            }

            PREFERENCE -> {
                val key = uri.lastPathSegment ?: return 0
                db.removePreference(key, caller())
                1
            }

            else -> 0
        }
    }

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int {
        values ?: return 0
        val pkg = caller()
        return when (matcher.match(uri)) {
            RECORD -> {
                val collection = uri.pathSegments[1]
                val id = uri.pathSegments[3]
                val data = values.getAsString(SharedDatabaseContract.Columns.DATA) ?: return 0
                db.updateRecord(collection, id, data, pkg)
            }

            COLLECTION -> {
                val name = uri.lastPathSegment ?: return 0
                db.ensureCollection(name, pkg)
                1
            }

            PREFERENCE -> {
                val key = uri.lastPathSegment ?: return 0
                val value = values.getAsString(SharedDatabaseContract.Columns.VALUE)
                    ?: return 0
                db.setPreferenceValue(key, value, pkg)
                1
            }

            else -> 0
        }
    }

    companion object {
        private const val COLLECTIONS = 1
        private const val COLLECTION = 2
        private const val RECORDS = 3
        private const val RECORD = 4
        private const val PREFERENCES = 5
        private const val PREFERENCE = 6

        private val COLLECTIONS_COLUMNS = arrayOf(
            SharedDatabaseContract.Columns.COLLECTION,
            SharedDatabaseContract.Columns.CREATED_AT,
            SharedDatabaseContract.Columns.CREATED_BY,
            SharedDatabaseContract.Columns.RECORD_COUNT,
        )

        private val RECORD_COLUMNS = arrayOf(
            SharedDatabaseContract.Columns.ID,
            SharedDatabaseContract.Columns.DATA,
            SharedDatabaseContract.Columns.CREATED_AT,
            SharedDatabaseContract.Columns.UPDATED_AT,
            SharedDatabaseContract.Columns.CREATED_BY,
            SharedDatabaseContract.Columns.UPDATED_BY,
        )
    }
}
