import 'package:any/any.dart';

import '../models/navigation_overlay.dart';
import '../states/navigation_state.dart';
import '../models/collection_name.dart';
import 'ref_mutate.dart';
import 'collection_commands.dart';
import 'feedback_commands.dart';
import 'records_commands.dart';

class AcceptNavigationOverlayCommand extends Command {
  const AcceptNavigationOverlayCommand();

  @override
  Future<void> call(Ref ref) async {
    final overlay = ref.of<NavigationState>().overlay;
    ref.mutate<NavigationState>((s) => s.overlay = null);
    if (overlay is ConfirmOverlay && overlay.onAccept != null) {
      await overlay.onAccept!.call(ref);
    }
  }
}

class SubmitTextPromptCommand extends Command {
  const SubmitTextPromptCommand(this.value);

  final String value;

  @override
  Future<void> call(Ref ref) async {
    final overlay = ref.of<NavigationState>().overlay;
    if (overlay is! TextPromptOverlay) return;
    final trimmed = value.trim();
    final err = switch (overlay.intent) {
      CreateCollectionIntent() || RenameCollectionIntent() =>
        validateCollectionName(trimmed),
    };
    if (err != null) {
      ShowFeedbackCommand(err, isError: true).call(ref);
      return;
    }
    ref.mutate<NavigationState>((s) => s.overlay = null);

    switch (overlay.intent) {
      case CreateCollectionIntent():
        await RunWithFeedbackCommand(
          CreateCollectionCommand(trimmed),
          successMessage: 'Created "$trimmed"',
        ).call(ref);
      case RenameCollectionIntent(:final from):
        if (trimmed == from) return;
        await RunWithFeedbackCommand(
          RenameCollectionCommand(from: from, to: trimmed),
          successMessage: 'Renamed to "$trimmed"',
        ).call(ref);
        try {
          await RenameRecordsCollectionCommand(trimmed).call(ref);
        } on StateError {
          // Not on a live records screen.
        }
    }
  }
}