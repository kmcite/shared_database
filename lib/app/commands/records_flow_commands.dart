import 'package:any/any.dart';

import '../models/navigation_overlay.dart';
import '../states/navigation_state.dart';
import '../states/records_state.dart';
import 'ref_mutate.dart';
import 'console_commands.dart';
import 'feedback_commands.dart';
import 'records_commands.dart';

class ShowDeleteSelectedRecordsConfirmCommand extends Command {
  const ShowDeleteSelectedRecordsConfirmCommand();

  @override
  void call(Ref ref) {
    final records = ref.of<RecordsState>();
    final n = records.selected.length;
    ref.mutate<NavigationState>(
      (s) => s.overlay = ConfirmOverlay(
        title: 'Delete $n record(s)?',
        message:
            'This permanently removes the selected records from '
            '"${records.collectionName}".',
        onAccept: _DeleteSelectedWithFeedback(n),
      ),
    );
  }
}

class _DeleteSelectedWithFeedback extends Command {
  const _DeleteSelectedWithFeedback(this.count);

  final int count;

  @override
  Future<void> call(Ref ref) async {
    await RunWithFeedbackCommand(
      const DeleteSelectedRecordsCommand(),
      successMessage: 'Deleted $count record(s)',
    ).call(ref);
    await const ReloadConsoleCommand().call(ref);
  }
}