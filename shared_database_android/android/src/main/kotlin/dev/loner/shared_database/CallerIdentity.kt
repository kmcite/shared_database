package dev.loner.shared_database

import android.content.Context
import android.os.Binder
import android.os.Process

object CallerIdentity {
    fun resolve(context: Context): String {
        val uid = Binder.getCallingUid()
        if (uid == Process.myUid()) {
            return context.packageName
        }
        val packages = context.packageManager.getPackagesForUid(uid)
        if (!packages.isNullOrEmpty()) {
            return packages[0]
        }
        return "uid:$uid"
    }
}
