package dev.loner.shared_database

import android.net.Uri

object SharedDatabaseContract {
    const val AUTHORITY = "dev.loner.shared_database"
    const val DB_NAME = "shared.db"

    val BASE_URI: Uri = Uri.parse("content://$AUTHORITY")

    object Paths {
        const val COLLECTIONS = "collections"
        const val RECORDS = "records"
    }

    object Columns {
        const val ID = "id"
        const val DATA = "data"
        const val COLLECTION = "collection"
        const val CREATED_AT = "created_at"
        const val UPDATED_AT = "updated_at"
        const val CREATED_BY = "created_by_package"
        const val UPDATED_BY = "updated_by_package"
    }
}
