
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:any/any.dart';

import '../../commands/backup_commands.dart';
import '../../commands/feedback_commands.dart';
import '../../commands/settings_commands.dart';
import '../../commands/settings_flow_commands.dart';
import '../../states/backup_op_state.dart';
import '../../states/console_state.dart';
import '../../states/settings_state.dart';
import '../shell/brand.dart';
import '../shell/app_theme.dart';
import '../widgets/widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.of<SettingsState>();
    final console = context.of<ConsoleState>();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        const ScreenHeader(
          title: 'Settings',
          subtitle: 'Appearance, backup, and behavior',
        ),
        Expanded(
          child: ListView(
            padding: AppLayout.pagePadding,
            children: [
              const SectionTitle('Appearance'),
              LiquidCard(
                padding: const EdgeInsets.all(16),
                tint: scheme.surfaceContainerLow,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Theme',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 10),
                      SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            icon: Icon(Icons.brightness_auto_rounded, size: 18),
                            label: Text('System'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode_rounded, size: 18),
                            label: Text('Light'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode_rounded, size: 18),
                            label: Text('Dark'),
                          ),
                        ],
                        selected: {settings.themeMode},
                        onSelectionChanged: (s) =>
                            context.call(SetThemeModeCommand(s.first)),
                      ),
                    ],
                ),
              ),
              const SectionTitle('Polling'),
              LiquidCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Watch interval',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                        'How often open screens poll the database for '
                        'changes made by other apps.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<Duration>(
                        segments: const [
                          ButtonSegment(
                            value: Duration(seconds: 1),
                            label: Text('1s'),
                          ),
                          ButtonSegment(
                            value: Duration(seconds: 2),
                            label: Text('2s'),
                          ),
                          ButtonSegment(
                            value: Duration(seconds: 5),
                            label: Text('5s'),
                          ),
                          ButtonSegment(
                            value: Duration(seconds: 10),
                            label: Text('10s'),
                          ),
                        ],
                        selected: {settings.watchInterval},
                        onSelectionChanged: (s) =>
                            context.call(SetWatchIntervalCommand(s.first)),
                      ),
                    ],
                ),
              ),
              const SectionTitle('Backup'),
              LiquidCard(
                padding: const EdgeInsets.all(16),
                accent: scheme.primary,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.backup_rounded, color: scheme.primary),
                          const SizedBox(width: 10),
                          Text(
                            'Full database',
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
                            onPressed: console.hasData
                                ? () => _exportFullBackup(context)
                                : null,
                            icon: const Icon(Icons.upload_rounded, size: 18),
                            label: const Text('Export everything'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _importFullBackup(context),
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: const Text('Import backup'),
                          ),
                        ],
                      ),
                    ],
                ),
              ),
              const SectionTitle('Danger zone'),
              LiquidCard(
                padding: const EdgeInsets.all(16),
                tint: scheme.errorContainer.withValues(alpha: 0.4),
                accent: scheme.error,
                featured: true,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: scheme.error,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Factory reset',
                            style: Theme.of(context).textTheme.titleMedium
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
                        onPressed: console.hasData
                            ? () => context.call(
                                  const ShowFactoryResetStepOneCommand(),
                                )
                            : null,
                        icon: const Icon(
                          Icons.delete_forever_outlined,
                          size: 18,
                        ),
                        label: const Text('Wipe EVERYTHING'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Deletes every collection, record, and preference. '
                        'Export a backup first.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                ),
              ),
              const SectionTitle('About'),
              LiquidCard(
                padding: const EdgeInsets.all(16),
                elevated: true,
                child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          Brand.appIcon,
                          width: 44,
                          height: 44,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.storage_rounded,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(Brand.appName,
                                style:
                                    Theme.of(context).textTheme.titleMedium),
                            Text(
                              'Shared database host · v1.3.0',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                            Text(
                              'Schema v3 · Android + Windows',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.outline),
                            ),
                          ],
                        ),
                      ),
                    ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> _exportFullBackup(BuildContext context) async {
  try {
    await context.call(const PrepareFullBackupCommand());
    if (!context.mounted) return;
    final backup = context.read<BackupOpState>();
    final json = backup.exportJson;
    if (json == null) throw StateError('Backup export failed');
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
      context.call(
        ShowFeedbackCommand(
          'Exported ${backup.recordCount} record(s) across '
          '${backup.collectionCount} collection(s)',
        ),
      );
    }
  } catch (e) {
    if (context.mounted) context.call(ShowErrorFeedbackCommand(e));
  }
}

Future<void> _importFullBackup(BuildContext context) async {
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
        context.call(
          const ShowFeedbackCommand('Not a shared_database backup file'),
        );
      }
      return;
    }

    if (!context.mounted) return;
    context.call(
      ShowImportBackupConfirmCommand(
        Map<String, dynamic>.from(decoded),
      ),
    );
  } catch (e) {
    if (context.mounted) context.call(ShowErrorFeedbackCommand(e));
  }
}