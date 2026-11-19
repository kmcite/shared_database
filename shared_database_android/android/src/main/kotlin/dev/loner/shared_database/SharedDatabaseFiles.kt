package dev.loner.shared_database

import android.content.Context
import java.io.IOException

internal object SharedDatabaseFiles {

    fun ensureDatabaseFile(context: Context): java.io.File {
        val target = SharedDatabasePathIo.databaseFile(context)
        val parent = target.parentFile
            ?: throw IOException("Invalid database path: ${target.absolutePath}")

        if (target.exists() && SharedDatabasePathIo.canReadWrite(target)) {
            SharedDatabasePathIo.widenForOtherApps(target)
            return target
        }

        if (!parent.exists() && !parent.mkdirs() && !parent.exists()) {
            throw IOException("Cannot create directory: ${parent.absolutePath}")
        }
        if (!target.exists() && !target.createNewFile() && !target.exists()) {
            throw IOException("Cannot create database file: ${target.absolutePath}")
        }

        SharedDatabasePathIo.widenForOtherApps(target)

        if (!SharedDatabasePathIo.canReadWrite(target)) {
            throw IOException("Database file is not readable/writable: ${target.absolutePath}")
        }
        return target
    }
}