/// Latest full-database backup prepared by [PrepareFullBackupCommand].
class BackupOpState {
  String? exportJson;
  int collectionCount = 0;
  int recordCount = 0;
}