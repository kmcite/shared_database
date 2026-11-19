package dev.loner.shared_database

internal fun Map<String, String>.toRecordData(collection: String): RecordData = RecordData(
    id = this[SharedDatabaseContract.Columns.ID] ?: "",
    collection = collection,
    dataJson = this[SharedDatabaseContract.Columns.DATA] ?: "{}",
    createdAt = this[SharedDatabaseContract.Columns.CREATED_AT]?.toLongOrNull() ?: 0L,
    updatedAt = this[SharedDatabaseContract.Columns.UPDATED_AT]?.toLongOrNull() ?: 0L,
    createdBy = this[SharedDatabaseContract.Columns.CREATED_BY] ?: "",
    updatedBy = this[SharedDatabaseContract.Columns.UPDATED_BY] ?: "",
)

internal fun Map<String, Any?>.toCollectionData(): CollectionData = CollectionData(
    name = this["name"] as? String ?: "",
    createdAt = (this["createdAt"] as? Number)?.toLong() ?: 0L,
    createdByPackage = this["createdByPackage"] as? String ?: "",
    recordCount = (this["recordCount"] as? Number)?.toLong() ?: 0L,
)