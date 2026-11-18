enum RecordsViewMode { cards, table }

enum RecordsSort {
  updatedDesc('Updated ↓'),
  updatedAsc('Updated ↑'),
  createdDesc('Created ↓'),
  createdAsc('Created ↑'),
  idAsc('ID A→Z'),
  idDesc('ID Z→A');

  const RecordsSort(this.label);
  final String label;
}