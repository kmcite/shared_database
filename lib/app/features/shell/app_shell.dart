import 'package:any/any.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../commands/navigation_commands.dart';
import '../../models/shell_tab.dart';
import '../../states/navigation_state.dart';
import '../widgets/widgets.dart';

/// Shell layout: drawer / rail / bottom bar + tab screens.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final nav = context.of<NavigationState>();
    final index = nav.shellTabIndex;
    final tab = ShellTab.at(index) ?? ShellTab.overview;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    if (nav.shellDrawerOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scaffoldKey.currentState?.openDrawer();
        context.call(const AckShellDrawerCommand());
      });
    }

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
        key: _scaffoldKey,
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
            const Expanded(child: _ShellTabView()),
          ],
        ),
        bottomNavigationBar: wide
            ? null
            : DecoratedBox(
                decoration: Liquid.panel(
                  context,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  alpha: 0.78,
                  elevated: true,
                  strength: 1.1,
                ),
                child: NavigationBar(
                  height: 64,
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  indicatorColor:
                      scheme.primaryContainer.withValues(alpha: 0.55),
                  selectedIndex: index < 3 ? index : 3,
                  onDestinationSelected: (i) {
                    if (i == 3) {
                      context.call(ShowShellMoreSheetCommand(index));
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

class _ShellTabView extends StatefulWidget {
  const _ShellTabView();

  @override
  State<_ShellTabView> createState() => _ShellTabViewState();
}

class _ShellTabViewState extends State<_ShellTabView> {
  late final PageController _controller;
  int? _appliedIndex;

  @override
  void initState() {
    super.initState();
    final initial = context.read<NavigationState>().shellTabIndex;
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
    final index = context.of<NavigationState>().shellTabIndex;
    if (_appliedIndex != index) {
      _appliedIndex = index;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _animateTo(index);
      });
    }

    return PageView(
      controller: _controller,
      physics: const BouncingScrollPhysics(),
      onPageChanged: (i) => context.call(SyncShellTabFromViewCommand(i)),
      children: ShellTab.screens,
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

    return DecoratedBox(
      decoration: Liquid.pill(
        context,
        tint: scheme.primaryContainer,
        alpha: 0.62,
      ).copyWith(
        boxShadow: Liquid.shadows(context, strength: 0.65),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.call(SelectShellTabCommand(tab)),
          borderRadius: BorderRadius.circular(999),
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
      ),
    );
  }
}