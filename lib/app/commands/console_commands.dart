import 'package:any/any.dart';
import 'package:shared_database/shared_database.dart';

import '../repositories/database_repository.dart';
import '../states/console_state.dart';
import 'preferences_commands.dart';
import 'settings_commands.dart';

class BootstrapAppCommand extends Command {
  const BootstrapAppCommand();

  @override
  Future<void> call(Ref ref) async {
    await const LoadSettingsCommand().call(ref);
    await const ReloadPreferencesCommand().call(ref);
    await const ReloadConsoleCommand(showSpinner: true).call(ref);
  }
}

class ReloadConsoleCommand extends Command {
  const ReloadConsoleCommand({this.showSpinner = false});

  final bool showSpinner;

  @override
  Future<void> call(Ref ref) async {
    final current = ref.of<ConsoleState>();
    if (showSpinner && !current.hasData) {
      ref.call<ConsoleState>((_) => current.copyWith(loading: true));
    }
    try {
      final db = ref.get<DatabaseRepository>();
      final results = await Future.wait([
        db.collectionsDetailed(),
        db.preferenceKeys(),
      ]);
      final detailed = results[0] as List<CollectionInfo>;
      final prefKeys = results[1] as List<String>;

      final byApp = <String, List<CollectionInfo>>{};
      for (final c in detailed) {
        byApp.putIfAbsent(c.createdByPackage, () => []).add(c);
      }
      final apps = byApp.entries
          .map(
            (e) => AppDataInfo(
              packageName: e.key,
              collectionCount: e.value.length,
              recordCount: e.value.fold(0, (sum, c) => sum + c.recordCount),
              collections: e.value,
            ),
          )
          .toList()
        ..sort((a, b) => a.packageName.compareTo(b.packageName));

      ref.call<ConsoleState>(
        (_) => current.copyWith(
          collections: detailed,
          apps: apps,
          preferenceCount: prefKeys.length,
          hasData: true,
          loading: false,
          clearError: true,
        ),
      );
    } catch (e) {
      ref.call<ConsoleState>(
        (_) => current.copyWith(
          error: e.toString(),
          loading: false,
        ),
      );
    }
  }
}

class ConsoleResumedCommand extends Command {
  const ConsoleResumedCommand();

  @override
  Future<void> call(Ref ref) async {
    await const ReloadConsoleCommand().call(ref);
  }
}