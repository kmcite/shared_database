import '../models/collection_import_result.dart';

/// Scratch values from the latest collection export/import command.
class CollectionOpState {
  String? exportCollection;
  String? exportJson;
  int exportRecordCount = 0;

  CollectionImportResult? lastImport;
}