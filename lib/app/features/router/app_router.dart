import 'package:any/any.dart';
import 'package:flutter/material.dart';

import '../../commands/console_commands.dart';
import '../../commands/feedback_commands.dart';
import '../../commands/navigation_commands.dart';
import '../../commands/overlay_commands.dart';
import '../../models/collection_name.dart';
import '../../models/navigation_overlay.dart';
import '../../models/route_location.dart';
import '../../models/shell_tab.dart';
import '../../states/feedback_state.dart';
import '../../states/navigation_state.dart';
import '../../states/settings_state.dart';
import '../app_collections/app_collections_screen.dart';
import '../collection/collection_screen.dart';
import '../shell/app_shell.dart';
import '../shell/app_theme.dart';
import '../shell/brand.dart';

/// [MaterialApp] plus sync from [NavigationState] → navigator, overlays, snackbars.
class AppRouter extends StatefulWidget {
  const AppRouter({super.key, required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  int _syncedStackLength = 0;
  bool _ignoreNextPop = false;
  NavigationOverlay? _presentedOverlay;
  bool _overlayVisible = false;

  late final _RouteStackObserver _observer = _RouteStackObserver(
    onUserPop: _onUserPop,
  );

  void _onUserPop() {
    if (!mounted) return;
    if (_ignoreNextPop) {
      _ignoreNextPop = false;
      return;
    }
    final nav = context.read<NavigationState>();
    if (nav.stack.isEmpty) return;
    context.call(const UserPoppedRouteCommand());
    setState(() {
      if (_syncedStackLength > 0) _syncedStackLength--;
    });
  }

  @override
  Widget build(BuildContext context) {
    context.of<NavigationState>();
    context.of<FeedbackState>();
    final settings = context.of<SettingsState>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final nav = context.read<NavigationState>();
      _syncStack(nav);
      _syncOverlay(nav);
      _syncFeedback(context.read<FeedbackState>());
    });

    return MaterialApp(
      navigatorKey: widget.navigatorKey,
      navigatorObservers: [_observer],
      title: Brand.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      home: const AppShell(),
    );
  }

  void _syncFeedback(FeedbackState fb) {
    final msg = fb.message;
    if (msg == null) return;
    final navContext = widget.navigatorKey.currentContext;
    if (navContext == null || !navContext.mounted) return;
    final scheme = Theme.of(navContext).colorScheme;
    ScaffoldMessenger.of(navContext)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: fb.isError ? scheme.errorContainer : null,
        ),
      );
    context.call(const ClearFeedbackCommand());
  }

  void _syncStack(NavigationState nav) {
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) return;

    while (_syncedStackLength < nav.stack.length) {
      final location = nav.stack[_syncedStackLength];
      final reloadOnPop = location is CollectionRouteLocation;
      _syncedStackLength++;
      navigator.push<void>(_routeFor(location)).whenComplete(() {
        if (!mounted) return;
        if (reloadOnPop) context.call(const ReloadConsoleCommand());
      });
    }

    while (_syncedStackLength > nav.stack.length) {
      _ignoreNextPop = true;
      navigator.pop();
      _syncedStackLength--;
    }
  }

  void _syncOverlay(NavigationState nav) {
    final navContext = widget.navigatorKey.currentContext;
    if (navContext == null || !navContext.mounted) return;

    final overlay = nav.overlay;
    if (overlay == null) {
      if (_overlayVisible) {
        Navigator.of(navContext, rootNavigator: true).pop();
        _overlayVisible = false;
        _presentedOverlay = null;
      }
      return;
    }

    if (_overlayVisible && identical(overlay, _presentedOverlay)) return;

    _presentedOverlay = overlay;
    _overlayVisible = true;

    switch (overlay) {
      case ShellMoreSheetOverlay(:final highlightedTabIndex):
        _presentShellMore(navContext, highlightedTabIndex);
      case ConfirmOverlay():
        _presentConfirm(navContext, overlay);
      case TextPromptOverlay():
        _presentTextPrompt(navContext, overlay);
    }
  }

  void _presentShellMore(BuildContext navContext, int highlightedTabIndex) {
    showModalBottomSheet<void>(
      context: navContext,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in ShellTab.values.where((t) => t.tabIndex >= 3))
              ListTile(
                leading: Icon(t.icon),
                title: Text(t.label),
                selected: highlightedTabIndex == t.tabIndex,
                onTap: () {
                  Navigator.pop(ctx);
                  context.call(SelectShellTabCommand(t));
                  context.call(const DismissNavigationOverlayCommand());
                },
              ),
          ],
        ),
      ),
    ).whenComplete(_onOverlayClosed);
  }

  void _presentConfirm(BuildContext navContext, ConfirmOverlay overlay) {
    showDialog<void>(
      context: navContext,
      builder: (ctx) => AlertDialog(
        title: Text(overlay.title),
        content: Text(overlay.message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.call(const DismissNavigationOverlayCommand());
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: overlay.destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.error,
                    foregroundColor: Theme.of(ctx).colorScheme.onError,
                  )
                : null,
            onPressed: () {
              Navigator.pop(ctx);
              context.call(const AcceptNavigationOverlayCommand());
            },
            child: Text(overlay.confirmLabel),
          ),
        ],
      ),
    ).whenComplete(_onOverlayClosed);
  }

  void _presentTextPrompt(BuildContext navContext, TextPromptOverlay overlay) {
    var value = overlay.initial ?? '';
    String? errorText;
    showModalBottomSheet<void>(
      context: navContext,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (context, setLocal) {
              void submit() {
                final err = validateCollectionName(value);
                if (err != null) {
                  setLocal(() => errorText = err);
                  return;
                }
                Navigator.pop(context);
                context.call(SubmitTextPromptCommand(value.trim()));
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    overlay.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: overlay.initial,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: overlay.fieldLabel,
                      errorText: errorText,
                    ),
                    textInputAction: TextInputAction.done,
                    onChanged: (v) {
                      value = v;
                      if (errorText != null) setLocal(() => errorText = null);
                    },
                    onFieldSubmitted: (_) => submit(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.call(const DismissNavigationOverlayCommand());
                        },
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: submit,
                        child: Text(overlay.confirmLabel),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    ).whenComplete(_onOverlayClosed);
  }

  void _onOverlayClosed() {
    if (!mounted) return;
    final presented = _presentedOverlay;
    setState(() {
      _overlayVisible = false;
      _presentedOverlay = null;
    });
    final current = context.read<NavigationState>().overlay;
    if (identical(current, presented)) {
      context.call(const DismissNavigationOverlayCommand());
    }
  }

  MaterialPageRoute<void> _routeFor(RouteLocation location) {
    switch (location) {
      case CollectionRouteLocation(
          :final collection,
          :final focusRecordId,
        ):
        return MaterialPageRoute<void>(
          builder: (_) => CollectionScreen(
            collection: collection,
            focusRecordId: focusRecordId,
          ),
        );
      case AppCollectionsRouteLocation(:final packageName):
        return MaterialPageRoute<void>(
          builder: (_) => AppCollectionsScreen(packageName: packageName),
        );
    }
  }
}

class _RouteStackObserver extends NavigatorObserver {
  _RouteStackObserver({required this.onUserPop});

  final VoidCallback onUserPop;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onUserPop();
  }
}