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
        val pkg = caller()
        return when (matcher.match(uri)) {
            COLLECTIONS -> {
                db.logAccess(
                    pkg,
                    SharedDatabaseHelper.ACTION_QUERY_COLLECTIONS,
                    null,
                    null,
                )
                val cursor = MatrixCursor(
                    arrayOf(SharedDatabaseContract.Columns.COLLECTION),
                )
                for (name in db.listCollectionNames()) {
                    cursor.addRow(arrayOf(name))
                }
                cursor
            }

            RECORDS -> {
                val collection = uri.pathSegments[1]
                db.logAccess(
                    pkg,
                    SharedDatabaseHelper.ACTION_QUERY_RECORDS,
                    collection,
                    null,
                )
                val cursor = MatrixCursor(
                    arrayOf(
                        SharedDatabaseContract.Columns.ID,
                        SharedDatabaseContract.Columns.DATA,
                    ),
                )
                for (row in db.getRecords(collection)) {
                    cursor.addRow(
                        arrayOf(
                            row[SharedDatabaseContract.Columns.ID],
                            row[SharedDatabaseContract.Columns.DATA],
                        ),
                    )
                }
                cursor
            }

            RECORD -> {
                val collection = uri.pathSegments[1]
                val id = uri.pathSegments[3]
                db.logAccess(
                    pkg,
                    SharedDatabaseHelper.ACTION_QUERY_RECORD,
                    collection,
                    id,
                )
                val row = db.getRecord(collection, id) ?: return null
                val cursor = MatrixCursor(
                    arrayOf(
                        SharedDatabaseContract.Columns.ID,
                        SharedDatabaseContract.Columns.DATA,
                    ),
                )
                cursor.addRow(
                    arrayOf(
                        row[SharedDatabaseContract.Columns.ID],
                        row[SharedDatabaseContract.Columns.DATA],
                    ),
                )
                cursor
            }

            else -> null
        }
    }

    override fun getType(uri: Uri): String? = null

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
                db.insertRecord(collection, id, data, pkg)
                Uri.parse(
                    "content://${SharedDatabaseContract.AUTHORITY}/collections/$collection/records/$id",
                )
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

            else -> 0
        }
    }

    companion object {
        private const val COLLECTIONS = 1
        private const val COLLECTION = 2
        private const val RECORDS = 3
        private const val RECORD = 4
    }
}
