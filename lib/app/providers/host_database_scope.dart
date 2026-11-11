import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../state/host_console_controller.dart';

/// Provides [HostConsoleController] for the Database shell and child routes.
class HostDatabaseScope extends StatelessWidget {
  const HostDatabaseScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HostConsoleController()..start(),
      child: child,
    );
  }
}
