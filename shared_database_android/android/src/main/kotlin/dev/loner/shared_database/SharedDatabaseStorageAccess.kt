package dev.loner.shared_database

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import androidx.core.content.ContextCompat

/**
 * Policy for the shared Documents database path — permissions are declared in this plugin's manifest.
 */
object SharedDatabaseStorageAccess {

    const val PERMISSION_REQUEST_CODE = 0x5D01
    const val MANAGE_STORAGE_REQUEST_CODE = 0x5D02

    fun hasAccess(context: Context): Boolean =
        hasLegacyPermissions(context) &&
            satisfiesAllFilesPolicy(context) &&
            SharedDatabasePathIo.canUseSharedLocation(context)

    fun legacyPermissionsToRequest(context: Context): Array<String> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return emptyArray()
        }
        val needed = mutableListOf<String>()
        if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.S_V2) {
            if (!isGranted(context, Manifest.permission.READ_EXTERNAL_STORAGE)) {
                needed += Manifest.permission.READ_EXTERNAL_STORAGE
            }
        }
        if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P) {
            if (!isGranted(context, Manifest.permission.WRITE_EXTERNAL_STORAGE)) {
                needed += Manifest.permission.WRITE_EXTERNAL_STORAGE
            }
        }
        return needed.toTypedArray()
    }

    fun needsAllFilesAccessSettings(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            return false
        }
        if (Environment.isExternalStorageManager()) {
            return false
        }
        return !SharedDatabasePathIo.canUseSharedLocation(context)
    }

    fun allFilesAccessIntent(context: Context): Intent {
        val perApp = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
            data = Uri.parse("package:${context.packageName}")
        }
        if (perApp.resolveActivity(context.packageManager) != null) {
            return perApp
        }
        return Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
    }

    private fun hasLegacyPermissions(context: Context): Boolean =
        legacyPermissionsToRequest(context).isEmpty()

    /**
     * On API 30+, either "All files access" is granted or direct path probe succeeded.
     */
    private fun satisfiesAllFilesPolicy(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            return true
        }
        if (Environment.isExternalStorageManager()) {
            return true
        }
        return SharedDatabasePathIo.canUseSharedLocation(context)
    }

    private fun isGranted(context: Context, permission: String): Boolean =
        ContextCompat.checkSelfPermission(context, permission) ==
            PackageManager.PERMISSION_GRANTED
}