import 'dart:convert';

import 'package:any/any.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../commands/collection_commands.dart';
import '../../commands/feedback_commands.dart';
import '../../states/collection_op_state.dart';

Future<void> runCollectionExport(
  BuildContext context, {
  required String collection,
}) async {
  try {
    await context.call(PrepareCollectionExportCommand(collection));
    if (!context.mounted) return;
    final export = context.read<CollectionOpState>();
    final json = export.exportJson;
    if (json == null) return;
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Export $collection',
      fileName: '$collection.json',
      bytes: utf8.encode(json),
    );
    if (saved != null && context.mounted) {
      context.call(
        ShowFeedbackCommand(
          'Exported ${export.exportRecordCount} record(s)',
        ),
      );
    }
  } catch (e) {
    if (context.mounted) context.call(ShowErrorFeedbackCommand(e));
  }
}

Future<int?> runCollectionImport(
  BuildContext context, {
  required String collection,
}) async {
  try {
    final files = await FilePicker.pickFiles(
      dialogTitle: 'Import into $collection',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final file = files.firstOrNull;
    if (file == null || !context.mounted) return null;
    final bytes = await file.readAsBytes();
    if (!context.mounted) return null;

    final decoded = jsonDecode(utf8.decode(bytes));
    try {
      await context.call(
        ImportCollectionCommand(collection: collection, decoded: decoded),
      );
    } on FormatException {
      if (context.mounted) {
        context.call(const ShowFeedbackCommand('Unrecognized file format'));
      }
      return null;
    }

    if (!context.mounted) return null;
    final result = context.read<CollectionOpState>().lastImport;
    if (result != null) {
      context.call(
        ShowFeedbackCommand(
          'Imported ${result.recordCount} record(s)'
          '${result.preferenceCount > 0 ? ' + ${result.preferenceCount} preference(s)' : ''} '
          'into $collection',
        ),
      );
      return result.recordCount;
    }
    return null;
  } catch (e) {
    if (context.mounted) context.call(ShowErrorFeedbackCommand(e));
    return null;
  }
}