import 'package:any/any.dart';

import '../repositories/database_repository.dart';
import '../states/collection_op_state.dart';
import 'ref_mutate.dart';
import 'console_commands.dart';
import 'preferences_commands.dart';

class CreateCollectionCommand extends Command {
  const CreateCollectionCommand(this.name);

  final String name;

  @override
  Future<void> call(Ref ref) async {
    await ref.get<DatabaseRepository>().collections.ensure(name);
    await const ReloadConsoleCommand().call(ref);
  }
}

class RenameCollectionCommand extends Command {
  const RenameCollectionCommand({required this.from, required this.to});

  final String from;
  final String to;

  @override
  Future<void> call(Ref ref) async {
    await ref.get<DatabaseRepository>().collections.rename(from, to);
    await const ReloadConsoleCommand().call(ref);
  }
}

class DeleteCollectionCommand extends Command {
  const DeleteCollectionCommand(this.name);

  final String name;

  @override
  Future<void> call(Ref ref) async {
    await ref.get<DatabaseRepository>().collections.remove(name);
    await const ReloadConsoleCommand().call(ref);
  }
}

class ClearCollectionCommand extends Command {
  const ClearCollectionCommand(this.name);

  final String name;

  @override
  Future<void> call(Ref ref) async {
    await ref.get<DatabaseRepository>().collections.clearRecords(name);
    await const ReloadConsoleCommand().call(ref);
  }
}

class ImportCollectionCommand extends Command {
  const ImportCollectionCommand({
    required this.collection,
    required this.decoded,
  });

  final String collection;
  final dynamic decoded;

  @override
  Future<void> call(Ref ref) async {
    final result =
        await ref.get<DatabaseRepository>().backup.importCollectionPayload(
              collection,
              decoded,
            );
    ref.mutate<CollectionOpState>((s) => s.lastImport = result);
    await const ReloadConsoleCommand().call(ref);
    if (result.preferenceCount > 0) {
      await const ReloadPreferencesCommand().call(ref);
    }
  }
}

class PrepareCollectionExportCommand extends Command {
  const PrepareCollectionExportCommand(this.collection);

  final String collection;

  @override
  Future<void> call(Ref ref) async {
    final repo = ref.get<DatabaseRepository>();
    final records = await repo.collections.getAllRecords(collection);
    final json = await repo.backup.exportCollectionJson(
      collection,
      records: records,
    );
    ref.mutate<CollectionOpState>((s) {
      s.exportCollection = collection;
      s.exportJson = json;
      s.exportRecordCount = records.length;
    });
  }
}