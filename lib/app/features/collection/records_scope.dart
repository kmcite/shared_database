import 'package:any/any.dart';
import 'package:flutter/material.dart';

import '../../commands/records_commands.dart';
import '../../repositories/records_repository.dart';
import '../../states/records_state.dart';

/// Nested scope for one collection's record browser.
class RecordsScope extends StatelessWidget {
  const RecordsScope({
    super.key,
    required this.collectionName,
    required this.child,
  });

  final String collectionName;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnyScope(
      repositories: [Binding(RecordsRepository(collectionName))],
      states: (_) => [RecordsState(collectionName: collectionName)],
      child: _RecordsScopeLifecycle(child: child),
    );
  }
}

class _RecordsScopeLifecycle extends StatefulWidget {
  const _RecordsScopeLifecycle({required this.child});

  final Widget child;

  @override
  State<_RecordsScopeLifecycle> createState() => _RecordsScopeLifecycleState();
}

class _RecordsScopeLifecycleState extends State<_RecordsScopeLifecycle> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.call(const StartRecordsWatchCommand());
    });
  }

  @override
  void dispose() {
    context.call(const StopRecordsWatchCommand());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}