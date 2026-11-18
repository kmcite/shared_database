import 'dart:async';

import 'package:any/any.dart';
import 'package:flutter/material.dart';
import '../../commands/console_commands.dart';
import '../../commands/shell_commands.dart';
import '../../repositories/database_repository.dart';
import '../router/app_router.dart';
import '../../states/backup_op_state.dart';
import '../../states/collection_op_state.dart';
import '../../states/console_state.dart';
import '../../states/search_state.dart';
import '../../states/preferences_state.dart';
import '../../states/settings_state.dart';
import '../../states/feedback_state.dart';
import '../../states/navigation_state.dart';

/// Root [AnyScope], console lifecycle side-effects, and themed [AppRouter].
class AppHost extends StatefulWidget {
  const AppHost({super.key});

  @override
  State<AppHost> createState() => _AppHostState();
}

class _AppHostState extends State<AppHost> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return AnyScope(
      repositories: [Binding(DatabaseRepository())],
      states: (_) => [
        ConsoleState(),
        SettingsState(),
        PreferencesState(),
        NavigationState(),
        FeedbackState(),
        CollectionOpState(),
        BackupOpState(),
        SearchState(),
      ],
      child: _AppHostEffects(
        child: AppRouter(navigatorKey: _navigatorKey),
      ),
    );
  }
}

/// Bootstrap, resume refresh, and console poll timer.
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