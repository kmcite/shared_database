package dev.loner.shared_database

import android.content.Context

/** Opens the on-device shared SQLite file (same path in every app). */
object SharedDatabaseStore {

    @Volatile
    private var helper: SharedDatabaseHelper? = null

    @Synchronized
    fun open(context: Context): SharedDatabaseHelper {
        helper?.let { return it }
        val appContext = context.applicationContext
        val dbFile = try {
            SharedDatabaseFiles.ensureDatabaseFile(appContext)
        } catch (e: Exception) {
            throw FlutterError(
                code = "STORAGE_UNAVAILABLE",
                message = e.message,
                details = mapOf(
                    "path" to SharedDatabasePaths.databaseFile(appContext).absolutePath,
                ),
            )
        }
        return SharedDatabaseHelper(appContext, dbFile.absolutePath).also { helper = it }
    }
}