import 'dart:async';

import 'package:any/any.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../commands/console_commands.dart';
import '../../commands/shell_commands.dart';
import '../../models/shell_tab.dart';
import '../../repositories/database_repository.dart';
import '../../states/console_state.dart';
import '../../states/preferences_state.dart';
import '../../states/settings_state.dart';
import '../../states/shell_navigation_state.dart';
import '../../brand/brand.dart';
import '../../theme/app_theme.dart';

/// Root [AnyScope], console lifecycle side-effects, themed app, and shell chrome.
class AppHost extends StatelessWidget {
  const AppHost({super.key});

  @override
  Widget build(BuildContext context) {
    return AnyScope(
      repositories: [Binding(DatabaseRepository())],
      states: (_) => [
        const ConsoleState(),
        SettingsState(),
        const PreferencesState(),
        ShellNavigationState(),
      ],
      child: const _AppHostEffects(child: _HostedMaterialApp()),
    );
  }
}

class _HostedMaterialApp extends StatelessWidget {
  const _HostedMaterialApp();

  @override
  Widget build(BuildContext context) {
    final settings = context.of<SettingsState>();
    final seed = settings.accent.seed;
    return MaterialApp(
      title: Brand.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(seed),
      darkTheme: AppTheme.dark(seed),
      themeMode: settings.themeMode,
      home: const AppShell(),
    );
  }
}

/// Bootstrap, resume refresh, and console poll timer — no navigation state here.
class _AppHostEffects extends StatefulWidget {
  const _AppHostEffects({required this.child});

  final Widget child;

  @override
  State<_AppHostEffects> createState() => _AppHostEffectsState();
}

class _AppHostEffectsState extends State<_AppHostEffects>
    with WidgetsBindingObserver {
  Timer? _poll;
  Duration? _pollInterval;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.call(const StartAppHostCommand());
      _syncPollTimer();
    });
  }

  void _syncPollTimer() {
    final interval = context.read<SettingsState>().watchInterval;
    if (_pollInterval == interval && _poll != null) return;
    _pollInterval = interval;
    _poll?.cancel();
    _poll = Timer.periodic(interval, (_) {
      if (mounted) context.call(const ReloadConsoleCommand());
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.call(const AppHostResumedCommand());
    }
  }

  @override
  Widget build(BuildContext context) {
    context.of<SettingsState>();
    _syncPollTimer();
    return widget.child;
  }
}

/// Shell layout: drawer / rail / bottom bar + tab pages.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.of<ShellNavigationState>();
    final index = nav.selectedIndex;
    final tab = ShellTab.at(index) ?? ShellTab.overview;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: scheme.surface,
        systemNavigationBarIconBrightness:
            dark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        appBar: wide
            ? null
            : AppBar(title: Text(tab.label), centerTitle: false),
        drawer: wide ? null : _ShellDrawer(selectedIndex: index),
        body: Row(
          children: [
            if (wide)
              NavigationRail(
                extended: MediaQuery.sizeOf(context).width >= 1100,
                selectedIndex: index,
                onDestinationSelected: (i) {
                  final t = ShellTab.at(i);
                  if (t != null) context.call(SelectShellTabCommand(t));
                },
                labelType: NavigationRailLabelType.none,
                destinations: [
                  for (final t in ShellTab.values)
                    NavigationRailDestination(
                      icon: Icon(t.icon),
                      selectedIcon: Icon(t.selectedIcon),
                      label: Text(t.label),
                    ),
                ],
              ),
            const Expanded(child: _ShellPageView()),
          ],
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: index < 3 ? index : 3,
                onDestinationSelected: (i) {
                  if (i == 3) {
                    _showMoreSheet(context, index);
                  } else {
                    context.call(SelectShellTabCommand(ShellTab.values[i]));
                  }
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard_rounded),
                    label: 'Overview',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.folder_outlined),
                    selectedIcon: Icon(Icons.folder_rounded),
                    label: 'Collections',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.search_rounded),
                    label: 'Search',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.more_horiz_rounded),
                    label: 'More',
                  ),
                ],
              ),
      ),
    );
  }

  void _showMoreSheet(BuildContext context, int selectedIndex) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in ShellTab.values.where((t) => t.tabIndex >= 3))
              ListTile(
                leading: Icon(t.icon),
                title: Text(t.label),
                selected: selectedIndex == t.tabIndex,
                onTap: () {
                  Navigator.pop(ctx);
                  context.call(SelectShellTabCommand(t));
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ShellDrawer extends StatelessWidget {
  const _ShellDrawer({required this.selectedIndex});

  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Text(
                'Shared Database',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final t in ShellTab.values)
              ListTile(
                leading: Icon(
                  selectedIndex == t.tabIndex ? t.selectedIcon : t.icon,
                ),
                title: Text(t.label),
                selected: selectedIndex == t.tabIndex,
                onTap: () {
                  Navigator.pop(context);
                  context.call(SelectShellTabCommand(t));
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Owns [PageController] only; index is driven by [ShellNavigationState].
class _ShellPageView extends StatefulWidget {
  const _ShellPageView();

  @override
  State<_ShellPageView> createState() => _ShellPageViewState();
}

class _ShellPageViewState extends State<_ShellPageView> {
  late final PageController _controller;
  int? _appliedIndex;

  @override
  void initState() {
    super.initState();
    final initial = context.read<ShellNavigationState>().selectedIndex;
    _controller = PageController(initialPage: initial);
    _appliedIndex = initial;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(int index) {
    if (!_controller.hasClients) return;
    if (_controller.page?.round() == index) return;
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final index = context.of<ShellNavigationState>().selectedIndex;
    if (_appliedIndex != index) {
      _appliedIndex = index;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _animateTo(index);
      });
    }

    return PageView(
      controller: _controller,
      physics: const BouncingScrollPhysics(),
      onPageChanged: (i) => context.call(SyncShellTabFromPageCommand(i)),
      children: ShellTab.pages,
    );
  }
}

/// Jumps to a main tab from overview section headers.
class ShellTabMarker extends StatelessWidget {
  const ShellTabMarker({
    super.key,
    required this.tab,
    this.label,
    this.compact = false,
  });

  final ShellTab tab;
  final String? label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final caption = label ?? tab.label;

    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.call(SelectShellTabCommand(tab)),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 5 : 6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tab.icon, size: compact ? 14 : 16, color: scheme.primary),
              if (caption.isNotEmpty) ...[
                SizedBox(width: compact ? 4 : 6),
                Text(
                  caption,
                  style: text.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              Icon(
                Icons.arrow_forward_rounded,
                size: compact ? 14 : 16,
                color: scheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}