import 'package:any/any.dart';

import '../models/navigation_overlay.dart';
import '../states/navigation_state.dart';
import 'ref_mutate.dart';
import 'collection_commands.dart';
import 'feedback_commands.dart';
import 'navigation_commands.dart';

class ShowCreateCollectionPromptCommand extends Command {
  const ShowCreateCollectionPromptCommand();

  @override
  void call(Ref ref) {
    ref.mutate<NavigationState>(
      (s) => s.overlay = const TextPromptOverlay(
        title: 'New collection',
        fieldLabel: 'Collection name',
        confirmLabel: 'Create',
        intent: CreateCollectionIntent(),
      ),
    );
  }
}

class ShowRenameCollectionPromptCommand extends Command {
  const ShowRenameCollectionPromptCommand(this.from);

  final String from;

  @override
  void call(Ref ref) {
    ref.mutate<NavigationState>(
      (s) => s.overlay = TextPromptOverlay(
        title: 'Rename collection',
        fieldLabel: 'Collection name',
        confirmLabel: 'Rename',
        intent: RenameCollectionIntent(from),
        initial: from,
      ),
    );
  }
}

class ShowDeleteCollectionConfirmCommand extends Command {
  const ShowDeleteCollectionConfirmCommand({
    required this.name,
    required this.recordCount,
  });

  final String name;
  final int recordCount;

  @override
  void call(Ref ref) {
    final message = recordCount == 0
        ? 'Delete "$name"? This cannot be undone.'
        : 'Delete "$name" and its $recordCount record(s)? '
            'This cannot be undone.';
    ref.mutate<NavigationState>(
      (s) => s.overlay = ConfirmOverlay(
        title: 'Delete collection?',
        message: message,
        onAccept: RunWithFeedbackCommand(
          DeleteCollectionCommand(name),
          successMessage: 'Deleted "$name"',
        ),
      ),
    );
  }
}

class ShowDeleteCollectionAndPopConfirmCommand extends Command {
  const ShowDeleteCollectionAndPopConfirmCommand({
    required this.name,
    required this.recordCount,
  });

  final String name;
  final int recordCount;

  @override
  void call(Ref ref) {
    final message = recordCount == 0
        ? 'Delete "$name"? This cannot be undone.'
        : 'Delete "$name" and its $recordCount record(s)? '
            'This cannot be undone.';
    ref.mutate<NavigationState>(
      (s) => s.overlay = ConfirmOverlay(
        title: 'Delete collection?',
        message: message,
        onAccept: _DeleteCollectionAndPop(name),
      ),
    );
  }
}

class _DeleteCollectionAndPop extends Command {
  const _DeleteCollectionAndPop(this.name);

  final String name;

  @override
  Future<void> call(Ref ref) async {
    await RunWithFeedbackCommand(
      DeleteCollectionCommand(name),
      successMessage: 'Deleted "$name"',
    ).call(ref);
    const PopRouteCommand().call(ref);
  }
}

class ShowClearCollectionConfirmCommand extends Command {
  const ShowClearCollectionConfirmCommand({
    required this.name,
    required this.recordCount,
  });

  final String name;
  final int recordCount;

  @override
  void call(Ref ref) {
    ref.mutate<NavigationState>(
      (s) => s.overlay = ConfirmOverlay(
        title: 'Clear collection?',
        message:
            'Remove all $recordCount record(s) from "$name"? '
            'The collection itself is kept.',
        confirmLabel: 'Clear',
        onAccept: RunWithFeedbackCommand(
          ClearCollectionCommand(name),
          successMessage: 'Cleared "$name"',
        ),
      ),
    );
  }
}