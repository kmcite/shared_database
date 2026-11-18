import 'package:shared_database/shared_database.dart';

class SearchHit {
  const SearchHit({required this.collection, required this.record});

  final String collection;
  final SharedRecord record;
}

/// In-memory search results (Search tab only).
class SearchState {
  int runId = 0;
  bool searching = false;
  String? progress;
  List<SearchHit> hits = [];
  Map<String, int> perCollection = {};
}