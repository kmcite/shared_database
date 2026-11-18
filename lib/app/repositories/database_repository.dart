import 'package:shared_database/shared_database.dart';

import 'backup_repository.dart';
import 'collections_repository.dart';
import 'preferences_repository.dart';

/// Root DB access for the host app — one [SharedDatabase], three behavioral repos.
class DatabaseRepository {
  DatabaseRepository({SharedDatabase? db})
      : collections = CollectionsRepository(db ?? SharedDatabase.instance),
        preferences = PreferencesRepository(db ?? SharedDatabase.instance),
        backup = BackupRepository(db ?? SharedDatabase.instance);

  final CollectionsRepository collections;
  final PreferencesRepository preferences;
  final BackupRepository backup;
}