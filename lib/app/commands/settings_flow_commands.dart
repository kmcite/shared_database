import 'package:any/any.dart';

import '../models/navigation_overlay.dart';
import '../states/console_state.dart';
import '../states/navigation_state.dart';
import 'ref_mutate.dart';
import 'backup_commands.dart';
import 'feedback_commands.dart';

class ShowImportBackupConfirmCommand extends Command {
  const ShowImportBackupConfirmCommand(this.decoded);

  final Map<String, dynamic> decoded;

  @override
  void call(Ref ref) {
    ref.mutate<NavigationState>(
      (s) => s.overlay = ConfirmOverlay(
        title: 'Import backup?',
        message:
            'Records are merged by id (existing ids are overwritten). '
            'Nothing is deleted.',
        confirmLabel: 'Import',
        destructive: false,
        onAccept: RunWithFeedbackCommand(
          ImportFullBackupCommand(decoded),
          successMessage: 'Backup imported',
        ),
      ),
    );
  }
}

class ShowFactoryResetStepOneCommand extends Command {
  const ShowFactoryResetStepOneCommand();

  @override
  void call(Ref ref) {
    final state = ref.of<ConsoleState>();
    ref.mutate<NavigationState>(
      (s) => s.overlay = ConfirmOverlay(
        title: 'Factory reset?',
        message:
            'This permanently deletes EVERYTHING: all '
            '${state.collectionCount} collection(s), all '
            '${state.recordCount} record(s), and all '
            '${state.preferenceCount} preference(s). '
            'This cannot be undone.',
        confirmLabel: 'Continue',
        onAccept: const ShowFactoryResetFinalConfirmCommand(),
      ),
    );
  }
}

class ShowFactoryResetFinalConfirmCommand extends Command {
  const ShowFactoryResetFinalConfirmCommand();

  @override
  void call(Ref ref) {
    ref.mutate<NavigationState>(
      (s) => s.overlay = ConfirmOverlay(
        title: 'Final confirmation',
        message:
            'Export a backup first if you need this data. '
            'Wipe the entire database?',
        confirmLabel: 'WIPE EVERYTHING',
        onAccept: const RunWithFeedbackCommand(
          WipeDatabaseCommand(),
          successMessage: 'Database completely wiped',
        ),
      ),
    );
  }
}