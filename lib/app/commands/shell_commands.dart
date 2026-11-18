import 'package:any/any.dart';

import '../models/shell_tab.dart';
import '../states/shell_navigation_state.dart';
import 'console_commands.dart';

class SelectShellTabCommand extends Command {
  const SelectShellTabCommand(this.tab);

  final ShellTab tab;

  @override
  void call(Ref ref) {
    final nav = ref.of<ShellNavigationState>();
    if (nav.selectedIndex == tab.tabIndex) return;
    ref.call<ShellNavigationState>((s) => s..selectedIndex = tab.tabIndex);
  }
}

/// Keeps state in sync when the user swipes the [PageView].
class SyncShellTabFromPageCommand extends Command {
  const SyncShellTabFromPageCommand(this.pageIndex);

  final int pageIndex;

  @override
  void call(Ref ref) {
    final nav = ref.of<ShellNavigationState>();
    if (nav.selectedIndex == pageIndex) return;
    ref.call<ShellNavigationState>((s) => s..selectedIndex = pageIndex);
  }
}

/// First frame after [AppHost] mounts: settings, preferences, console.
class StartAppHostCommand extends Command {
  const StartAppHostCommand();

  @override
  Future<void> call(Ref ref) async {
    await const BootstrapAppCommand().call(ref);
  }
}

class AppHostResumedCommand extends Command {
  const AppHostResumedCommand();

  @override
  Future<void> call(Ref ref) async {
    await const ConsoleResumedCommand().call(ref);
  }
}