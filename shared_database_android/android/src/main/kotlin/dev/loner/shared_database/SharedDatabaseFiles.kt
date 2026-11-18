package dev.loner.shared_database

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File
import java.io.IOException

internal object SharedDatabaseFiles {

    private val mediaStoreRelativePath: String
        get() = "${Environment.DIRECTORY_DOCUMENTS}/${SharedDatabaseContract.STORAGE_DIR}/"

    fun ensureDatabaseFile(context: Context): File {
        val target = SharedDatabasePaths.databaseFile(context)
        val parent = target.parentFile
            ?: throw IOException("Invalid database path: ${target.absolutePath}")
        if (!parent.exists() && !parent.mkdirs() && !parent.exists()) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                registerInMediaStoreIfNeeded(context)
            }
        }
        if (!parent.exists() && !parent.mkdirs() && !parent.exists()) {
            throw IOException("Cannot create directory: ${parent.absolutePath}")
        }
        if (!target.exists() && !target.createNewFile() && !target.exists()) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                registerInMediaStoreIfNeeded(context)
            }
        }
        if (!target.exists() && !target.createNewFile() && !target.exists()) {
            throw IOException("Cannot create database file: ${target.absolutePath}")
        }
        if (!target.canRead() || !target.canWrite()) {
            throw IOException("Database file is not readable/writable: ${target.absolutePath}")
        }
        return target
    }

    private fun registerInMediaStoreIfNeeded(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        if (findMediaStoreId(context) != null) return
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, SharedDatabaseContract.DB_NAME)
            put(MediaStore.MediaColumns.MIME_TYPE, "application/vnd.sqlite3")
            put(MediaStore.Files.FileColumns.RELATIVE_PATH, mediaStoreRelativePath)
        }
        context.contentResolver.insert(
            MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY),
            values,
        )
    }

    private fun findMediaStoreId(context: Context): Long? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        val resolver = context.contentResolver
        val collection = MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val selection =
            "${MediaStore.Files.FileColumns.RELATIVE_PATH}=? AND " +
                "${MediaStore.MediaColumns.DISPLAY_NAME}=?"
        val args = arrayOf(mediaStoreRelativePath, SharedDatabaseContract.DB_NAME)
        resolver.query(
            collection,
            arrayOf(MediaStore.Files.FileColumns._ID),
            selection,
            args,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) return cursor.getLong(0)
        }
        return null
    }
}