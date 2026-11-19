package dev.loner.shared_database

import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import kotlin.coroutines.resume
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * Activity-scoped permission / settings flows for [SharedDatabaseStorageAccess].
 * Host apps do not implement this — the plugin owns it.
 */
internal class SharedDatabasePermissionCoordinator {

    private var activity: Activity? = null
    private var permissionContinuation: ((Boolean) -> Unit)? = null
    private var manageStorageContinuation: ((Boolean) -> Unit)? = null

    fun onAttach(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(::onPermissionResult)
        binding.addActivityResultListener(::onActivityResult)
    }

    fun onDetach(fullTeardown: Boolean) {
        if (fullTeardown) {
            activity = null
            cancelPending()
        }
    }

    suspend fun ensureAccess(context: Context): Boolean {
        if (SharedDatabaseStorageAccess.hasAccess(context)) {
            return true
        }
        val host = activity
            ?: throw FlutterError(
                code = "STORAGE_PERMISSION",
                message =
                    "Storage permission required but no Activity is available " +
                    "(call SharedDatabase.open() while the app is in the foreground).",
                details = null,
            )
        if (!requestLegacyPermissions(host, context)) {
            return false
        }
        if (SharedDatabaseStorageAccess.hasAccess(context)) {
            return true
        }
        return requestAllFilesAccessIfNeeded(host, context)
    }

    private suspend fun requestLegacyPermissions(
        host: Activity,
        context: Context,
    ): Boolean {
        val permissions = SharedDatabaseStorageAccess.legacyPermissionsToRequest(context)
        if (permissions.isEmpty()) {
            return true
        }
        return suspendCancellableCoroutine { cont ->
            cont.invokeOnCancellation { permissionContinuation = null }
            permissionContinuation = { granted ->
                if (cont.isActive) {
                    cont.resume(granted)
                }
            }
            host.requestPermissions(
                permissions,
                SharedDatabaseStorageAccess.PERMISSION_REQUEST_CODE,
            )
        }
    }

    private suspend fun requestAllFilesAccessIfNeeded(
        host: Activity,
        context: Context,
    ): Boolean {
        if (!SharedDatabaseStorageAccess.needsAllFilesAccessSettings(context)) {
            return SharedDatabaseStorageAccess.hasAccess(context)
        }
        return suspendCancellableCoroutine { cont ->
            cont.invokeOnCancellation { manageStorageContinuation = null }
            manageStorageContinuation = { ok ->
                if (cont.isActive) {
                    cont.resume(ok)
                }
            }
            try {
                host.startActivityForResult(
                    SharedDatabaseStorageAccess.allFilesAccessIntent(context),
                    SharedDatabaseStorageAccess.MANAGE_STORAGE_REQUEST_CODE,
                )
            } catch (_: Exception) {
                manageStorageContinuation = null
                if (cont.isActive) {
                    cont.resume(SharedDatabaseStorageAccess.hasAccess(context))
                }
            }
        }
    }

    private fun onPermissionResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != SharedDatabaseStorageAccess.PERMISSION_REQUEST_CODE) {
            return false
        }
        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        permissionContinuation?.invoke(granted)
        permissionContinuation = null
        return true
    }

    private fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?): Boolean {
        if (requestCode != SharedDatabaseStorageAccess.MANAGE_STORAGE_REQUEST_CODE) {
            return false
        }
        val context = activity?.applicationContext ?: return true
        manageStorageContinuation?.invoke(SharedDatabaseStorageAccess.hasAccess(context))
        manageStorageContinuation = null
        return true
    }

    private fun cancelPending() {
        permissionContinuation = null
        manageStorageContinuation = null
    }
}