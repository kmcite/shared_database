package dev.loner.shared_database

object SharedDatabaseContract {
    const val STORAGE_DIR = "dev.loner.shared_database"
    const val DB_NAME = "shared.db"

    object Columns {
        const val ID = "id"
        const val DATA = "data"
        const val COLLECTION = "collection"
        const val CREATED_AT = "created_at"
        const val UPDATED_AT = "updated_at"
        const val CREATED_BY = "created_by_package"
        const val UPDATED_BY = "updated_by_package"
        const val KEY = "key"
        const val VALUE = "value"
        const val RECORD_COUNT = "record_count"
    }
}