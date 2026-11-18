package dev.loner.shared_database

import android.content.Context
import android.os.Build
import android.os.Environment
import android.os.storage.StorageManager
import java.io.File
import java.io.IOException

/** Same absolute path for every app on the device. */
object SharedDatabasePaths {

    fun databaseFile(context: Context): File {
        val dir = File(documentsRoot(context), SharedDatabaseContract.STORAGE_DIR)
        return File(dir, SharedDatabaseContract.DB_NAME)
    }

    private fun documentsRoot(context: Context): File {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val storageManager =
                context.getSystemService(StorageManager::class.java)
                    ?: throw IOException("StorageManager unavailable")
            val root = storageManager.primaryStorageVolume.directory
                ?: throw IOException("Primary storage unavailable")
            return File(root, Environment.DIRECTORY_DOCUMENTS)
        }
        @Suppress("DEPRECATION")
        return Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS)
    }
}