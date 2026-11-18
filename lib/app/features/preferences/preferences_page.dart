import 'package:any/any.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_database/shared_database.dart';

import '../../commands/preferences_commands.dart';
import '../../states/preferences_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/page_header.dart';

/// Browse and edit the shared key/value preferences store.
class PreferencesPage extends StatefulWidget {
  const PreferencesPage({super.key});

  @override
  State<PreferencesPage> createState() => _PreferencesPageState();
}

class _PreferencesPageState extends State<PreferencesPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final prefs = context.of<PreferencesState>();
    final q = _query.trim().toLowerCase();
    final keys = q.isEmpty
        ? prefs.keys
        : prefs.keys.where((k) => k.toLowerCase().contains(q)).toList();
    return Column(
      children: [
        const PageHeader(
          title: 'Preferences',
          subtitle: 'Shared key/value store used by all apps',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Filter keys…',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'New preference',
                onPressed: () => _editKey(context),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: prefs.loading
              ? const LoadingView(message: 'Loading preferences…')
              : prefs.error != null
                  ? ErrorView(
                      message: prefs.error!,
                      onRetry: () =>
                          context.call(const ReloadPreferencesCommand()),
                    )
                  : keys.isEmpty
                      ? EmptyState(
                          icon: Icons.tune_rounded,
                          message: prefs.keys.isEmpty
                              ? 'No preferences stored yet.\n'
                                  'Apps write them with '
                                  'setPreference(key, value).'
                              : 'No keys match.',
                        )
                      : ListView.builder(
                          padding: AppLayout.pagePadding,
                          itemCount: keys.length,
                          itemBuilder: (context, i) => _PrefTile(keyName: keys[i]),
                        ),
        ),
      ],
    );
  }

  Future<void> _editKey(BuildContext context, {String? existing}) async {
    final keyController = TextEditingController(text: existing ?? '');
    final valueController = TextEditingController();
    String? error;
    final isNew = existing == null;

    if (existing != null) {
      valueController.text =
          await SharedDatabase.instance.getPreference(existing) ?? '';
    }
    if (!context.mounted) return;

    final result = await showModalBottomSheet<({String key, String value})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isNew ? 'New preference' : 'Edit preference',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: keyController,
                    enabled: isNew,
                    decoration: InputDecoration(
                      labelText: 'Key',
                      errorText: error,
                    ),
                    onChanged: (_) => setLocal(() => error = null),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: valueController,
                    maxLines: 4,
                    minLines: 1,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Value',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          final key = keyController.text.trim();
                          if (key.isEmpty) {
                            setLocal(() => error = 'Key is required');
                            return;
                          }
                          Navigator.pop(
                            context,
                            (key: key, value: valueController.text),
                          );
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    keyController.dispose();
    valueController.dispose();
    if (result == null || !context.mounted) return;
    try {
      await context.call(
        SetPreferenceCommand(result.key, result.value),
      );
      if (context.mounted) Ui.message(context, 'Saved "${result.key}"');
    } catch (e) {
      if (context.mounted) Ui.error(context, e);
    }
  }
}

class _PrefTile extends StatelessWidget {
  const _PrefTile({required this.keyName});

  final String keyName;

  @override
  Widget build(BuildContext context) {
    context.of<PreferencesState>();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.key_rounded, color: scheme.primary, size: 20),
        title: SelectableText(
          keyName,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: FutureBuilder<String?>(
          future: SharedDatabase.instance.getPreference(keyName),
          builder: (context, snap) {
            final value = snap.data;
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 14,
                width: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              );
            }
            return SelectableText(
              value ?? '(null)',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
              maxLines: 2,
            );
          },
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Copy value',
              icon: const Icon(Icons.copy_rounded, size: 18),
              onPressed: () async {
                final v =
                    await SharedDatabase.instance.getPreference(keyName);
                if (v != null && context.mounted) {
                  await Clipboard.setData(ClipboardData(text: v));
                  if (context.mounted) {
                    Ui.message(context, 'Copied "$keyName"');
                  }
                }
              },
            ),
            PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'edit') {
                  await _editExisting(context);
                } else if (action == 'delete') {
                  final ok = await Ui.confirm(
                    context,
                    title: 'Delete preference?',
                    message: 'Remove "$keyName"?',
                    confirmLabel: 'Delete',
                  );
                  if (ok && context.mounted) {
                    await context.call(RemovePreferenceCommand(keyName));
                  }
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
        onTap: () => _editExisting(context),
      ),
    );
  }

  Future<void> _editExisting(BuildContext context) async {
    final valueController = TextEditingController(
      text: await SharedDatabase.instance.getPreference(keyName) ?? '',
    );
    if (!context.mounted) return;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(keyName),
        content: TextField(
          controller: valueController,
          maxLines: 6,
          minLines: 1,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: const InputDecoration(labelText: 'Value'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, valueController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    valueController.dispose();
    if (result == null || !context.mounted) return;
    try {
      await context.call(SetPreferenceCommand(keyName, result));
      if (context.mounted) Ui.message(context, 'Saved "$keyName"');
    } catch (e) {
      if (context.mounted) Ui.error(context, e);
    }
  }
}