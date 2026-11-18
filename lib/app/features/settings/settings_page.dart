import 'package:flutter/material.dart';
import 'package:any/any.dart';

import '../../brand/brand.dart';
import '../../commands/settings_commands.dart';
import '../../states/settings_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/page_header.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.of<SettingsState>();
    final scheme = Theme.of(context).colorScheme;
    return Column(
          children: [
            const PageHeader(
              title: 'Settings',
              subtitle: 'Appearance and behavior, saved to the database',
            ),
            Expanded(
              child: ListView(
                padding: AppLayout.pagePadding,
                children: [
            const SectionTitle('Appearance'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
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
                          icon: Icon(Icons.brightness_auto_rounded,
                              size: 18),
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
                      onSelectionChanged: (s) => context.call(
                            SetThemeModeCommand(s.first),
                          ),
                    ),
                    const SizedBox(height: 20),
                    Text('Accent color',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final accent in AppAccent.values)
                          _AccentSwatch(
                            accent: accent,
                            selected:
                                settings.accent == accent,
                            onTap: () =>
                                context.call(SetAccentCommand(accent)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SectionTitle('Data'),
            Card(
              child: Padding(
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
                      onSelectionChanged: (s) => context.call(
                            SetWatchIntervalCommand(s.first),
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SectionTitle('About'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
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
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium),
                          Text(
                            'Shared database host · v1.3.0',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
                ],
              ),
            ),
          ],
        );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final AppAccent accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: accent.seed,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? scheme.onSurface : Colors.transparent,
            width: selected ? 3 : 0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.seed.withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: selected
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
            : Tooltip(
                message: accent.label,
                child: Icon(accent.icon, color: Colors.white, size: 20),
              ),
      ),
    );
  }
}
