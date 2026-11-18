import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:any/any.dart';
import 'package:shared_database/shared_database.dart';

import '../../commands/console_commands.dart';
import '../../states/console_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/page_header.dart';

/// Full-database export / import and danger-zone operations.
class BackupPage extends StatelessWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.of<ConsoleState>();
    final scheme = Theme.of(context).colorScheme;
    return Column(
          children: [
            const PageHeader(
              title: 'Backup',
              subtitle: 'Export, import and danger-zone operations',
            ),
            Expanded(
              child: ListView(
                padding: AppLayout.pagePadding,
                children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.backup_rounded, color: scheme.primary),
                        const SizedBox(width: 10),
                        Text(
                          'Full backup',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Exports every collection (all records) and every '
                      'preference into one JSON file. Import merges records '
                      'by id — it never deletes anything.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: state.hasData
                              ? () => _exportAll(context, state)
                              : null,
                          icon: const Icon(Icons.upload_rounded, size: 18),
                          label: const Text('Export everything'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _importAll(context, state),
                          icon:
                              const Icon(Icons.download_rounded, size: 18),
                          label: const Text('Import backup'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SectionTitle('Danger zone'),
            Card(
              color: scheme.errorContainer.withValues(alpha: 0.35),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: scheme.error),
                        const SizedBox(width: 10),
                        Text(
                          'Irreversible operations',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: scheme.error),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.error,
                        side: BorderSide(color: scheme.error),
                      ),
                      onPressed: state.hasData
                          ? () => _wipeAll(context, state)
                          : null,
                      icon: const Icon(Icons.delete_forever_outlined,
                          size: 18),
                      label: const Text('Factory reset — wipe EVERYTHING'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Deletes every collection, every record and every '
                      'preference. The database is left completely empty. '
                      'Export a backup first.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'shared_database · schema v3 · Android + Windows',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.outline,
                    ),
              ),
            ),
                ],
              ),
            ),
          ],
        );
  }

  Future<void> _exportAll(
      BuildContext context, ConsoleState state) async {
    try {
      final db = SharedDatabase.instance;
      final collections = <String, dynamic>{};
      var totalRecords = 0;
      for (final c in state.collections) {
        final rows = await db.getAll(c.name);
        totalRecords += rows.length;
        collections[c.name] = rows
            .map(
              (r) => {
                'id': r.id,
                'data': r.data,
                'createdAt': r.createdAt,
                'updatedAt': r.updatedAt,
                'createdBy': r.createdBy,
                'updatedBy': r.updatedBy,
              },
            )
            .toList();
      }
      final prefs = <String, String?>{};
      for (final key in await db.getPreferenceKeys()) {
        prefs[key] = await db.getPreference(key);
      }
      final payload = {
        'format': 'shared_database.backup',
        'version': 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'collections': collections,
        'preferences': prefs,
      };
      final json = const JsonEncoder.withIndent('  ').convert(payload);
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Export database backup',
        fileName: 'shared_database_$stamp.json',
        bytes: utf8.encode(json),
      );
      if (saved != null && context.mounted) {
        Ui.message(
          context,
          'Exported $totalRecords record(s) across '
          '${collections.length} collection(s)',
        );
      }
    } catch (e) {
      if (context.mounted) Ui.error(context, e);
    }
  }

  Future<void> _importAll(
      BuildContext context, ConsoleState state) async {
    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: 'Import database backup',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      final file = files.firstOrNull;
      if (file == null || !context.mounted) return;
      final bytes = await file.readAsBytes();
      if (!context.mounted) return;
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map || decoded['collections'] is! Map) {
        if (context.mounted) {
          Ui.message(context, 'Not a shared_database backup file');
        }
        return;
      }

      final ok = await Ui.confirm(
        context,
        title: 'Import backup?',
        message: 'Records are merged by id (existing ids are overwritten). '
            'Nothing is deleted.',
        confirmLabel: 'Import',
        destructive: false,
      );
      if (!ok || !context.mounted) return;

      final db = SharedDatabase.instance;
      final collections = decoded['collections'] as Map;
      var imported = 0;
      for (final entry in collections.entries) {
        final name = entry.key;
        if (name is! String || entry.value is! List) continue;
        await db.ensureCollection(name);
        final batch = <({String? id, Map<String, dynamic> data})>[];
        for (final item in entry.value as List) {
          if (item is! Map || item['data'] is! Map) continue;
          batch.add((
            id: item['id'] is String ? item['id'] as String : null,
            data: Map<String, dynamic>.from(item['data'] as Map),
          ));
          if (batch.length >= 200) {
            await db.putMany(name, batch);
            imported += batch.length;
            batch.clear();
          }
        }
        if (batch.isNotEmpty) {
          await db.putMany(name, batch);
          imported += batch.length;
        }
      }
      final prefs = decoded['preferences'];
      if (prefs is Map) {
        for (final e in prefs.entries) {
          if (e.key is String) {
            await db.setPreference(
              e.key as String,
              e.value?.toString() ?? '',
            );
          }
        }
      }
      context.call(const ReloadConsoleCommand());
      if (context.mounted) {
        Ui.message(context, 'Imported $imported record(s)');
      }
    } catch (e) {
      if (context.mounted) Ui.error(context, e);
    }
  }

  Future<void> _wipeAll(
      BuildContext context, ConsoleState state) async {
    final first = await Ui.confirm(
      context,
      title: 'Factory reset?',
      message: 'This permanently deletes EVERYTHING: all '
          '${state.collectionCount} collection(s), all '
          '${state.recordCount} record(s), and all '
          '${state.preferenceCount} preference(s). '
          'This cannot be undone.',
      confirmLabel: 'Continue',
    );
    if (!first || !context.mounted) return;
    final second = await Ui.confirm(
      context,
      title: 'Final confirmation',
      message: 'Export a backup first if you need this data. '
          'Wipe the entire database?',
      confirmLabel: 'WIPE EVERYTHING',
    );
    if (!second || !context.mounted) return;
    try {
      final db = SharedDatabase.instance;
      for (final c in state.collections) {
        await db.removeCollection(c.name);
      }
      for (final key in await db.getPreferenceKeys()) {
        await db.removePreference(key);
      }
      context.call(const ReloadConsoleCommand());
      if (context.mounted) {
        Ui.message(context, 'Database completely wiped');
      }
    } catch (e) {
      if (context.mounted) Ui.error(context, e);
    }
  }
}
