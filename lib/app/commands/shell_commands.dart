import 'package:any/any.dart';

import 'console_commands.dart';

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
    await const ReloadConsoleCommand().call(ref);
  }
}