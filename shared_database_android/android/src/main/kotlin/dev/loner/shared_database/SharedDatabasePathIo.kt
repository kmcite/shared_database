package dev.loner.shared_database

import android.content.Context
import java.io.File
import java.io.RandomAccessFile

/** Direct file probes and mode fixes for the shared Documents path. */
internal object SharedDatabasePathIo {

    const val PROBE_FILE_NAME = ".shared_db_probe"

    fun databaseFile(context: Context): File = SharedDatabasePaths.databaseFile(context)

    fun canReadWrite(file: File): Boolean {
        if (!file.exists()) {
            return false
        }
        if (file.canRead() && file.canWrite()) {
            return true
        }
        return try {
            RandomAccessFile(file, "rw").use { it.length() }
            true
        } catch (_: Exception) {
            false
        }
    }

    /**
     * True when an existing DB is usable or the parent dir accepts a ephemeral probe file.
     */
    fun canUseSharedLocation(context: Context): Boolean {
        val target = databaseFile(context)
        val parent = target.parentFile ?: return false
        return try {
            if (!parent.exists() && !parent.mkdirs() && !parent.exists()) {
                return false
            }
            if (target.exists()) {
                return canReadWrite(target)
            }
            val probe = File(parent, PROBE_FILE_NAME)
            val created = probe.createNewFile()
            if (created) {
                probe.delete()
            }
            created
        } catch (_: Exception) {
            false
        }
    }

    fun widenForOtherApps(file: File) {
        file.setReadable(true, false)
        file.setWritable(true, false)
        file.parentFile?.let { dir ->
            dir.setReadable(true, false)
            dir.setExecutable(true, false)
        }
    }
}