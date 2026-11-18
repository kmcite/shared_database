import 'package:any/any.dart';
import 'package:flutter/material.dart';
import '../../commands/feedback_commands.dart';
import '../../commands/preferences_commands.dart';
import '../../commands/preferences_flow_commands.dart';
import '../../states/preferences_state.dart';
import '../shell/app_theme.dart';
import '../widgets/widgets.dart';

/// Browse and edit the shared key/value preferences store.
class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
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
        const ScreenHeader(
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
          context.read<PreferencesState>().values[existing] ?? '';
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
      if (context.mounted) {
        context.call(ShowFeedbackCommand('Saved "${result.key}"'));
      }
    } catch (e) {
      if (context.mounted) context.call(ShowErrorFeedbackCommand(e));
    }
  }
}

class _PrefTile extends StatelessWidget {
  const _PrefTile({required this.keyName});

  final String keyName;

  @override
  Widget build(BuildContext context) {
    final prefs = context.of<PreferencesState>();
    final scheme = Theme.of(context).colorScheme;
    return LiquidCard(
      padding: EdgeInsets.zero,
      accent: scheme.primary,
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
        subtitle: SelectableText(
          prefs.values[keyName] ?? '(null)',
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
          ),
          maxLines: 2,
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Copy value',
              icon: const Icon(Icons.copy_rounded, size: 18),
              onPressed: () {
                final v = prefs.values[keyName];
                if (v != null) {
                  context.call(
                    CopyToClipboardCommand(v, label: 'Copied "$keyName"'),
                  );
                }
              },
            ),
            PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'edit') {
                  await _editExisting(context);
                } else if (action == 'delete') {
                  context.call(
                    ShowRemovePreferenceConfirmCommand(keyName),
                  );
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
      text: context.read<PreferencesState>().values[keyName] ?? '',
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
      if (context.mounted) {
        context.call(ShowFeedbackCommand('Saved "$keyName"'));
      }
    } catch (e) {
      if (context.mounted) context.call(ShowErrorFeedbackCommand(e));
    }
  }
}