import 'package:any/any.dart';

import '../repositories/database_repository.dart';
import '../states/backup_op_state.dart';
import '../states/console_state.dart';
import 'ref_mutate.dart';
import 'console_commands.dart';
import 'preferences_commands.dart';

class PrepareFullBackupCommand extends Command {
  const PrepareFullBackupCommand();

  @override
  Future<void> call(Ref ref) async {
    final console = ref.of<ConsoleState>();
    final result = await ref
        .get<DatabaseRepository>()
        .backup
        .exportFullBackup(console.collections);
    ref.mutate<BackupOpState>((s) {
      s.exportJson = result.json;
      s.recordCount = result.recordCount;
      s.collectionCount = console.collections.length;
    });
  }
}

class ImportFullBackupCommand extends Command {
  const ImportFullBackupCommand(this.decoded);

  final Map<String, dynamic> decoded;

  @override
  Future<void> call(Ref ref) async {
    await ref.get<DatabaseRepository>().backup.importFullBackup(decoded);
    await const ReloadConsoleCommand().call(ref);
    await const ReloadPreferencesCommand().call(ref);
  }
}

class WipeDatabaseCommand extends Command {
  const WipeDatabaseCommand();

  @override
  Future<void> call(Ref ref) async {
    final collections = ref.of<ConsoleState>().collections;
    await ref.get<DatabaseRepository>().backup.wipeAll(collections);
    await const ReloadConsoleCommand().call(ref);
    await const ReloadPreferencesCommand().call(ref);
  }
}