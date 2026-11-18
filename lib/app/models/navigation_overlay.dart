import 'package:any/any.dart';

/// Modal UI driven by [NavigationState.overlay] and [AppRouter].
sealed class NavigationOverlay {
  const NavigationOverlay();
}

/// Bottom sheet listing shell tabs 3+ (Preferences, Settings, …).
final class ShellMoreSheetOverlay extends NavigationOverlay {
  const ShellMoreSheetOverlay({required this.highlightedTabIndex});

  final int highlightedTabIndex;
}

final class ConfirmOverlay extends NavigationOverlay {
  const ConfirmOverlay({
    required this.title,
    required this.message,
    this.confirmLabel = 'Delete',
    this.destructive = true,
    this.onAccept,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;
  final Command? onAccept;
}

sealed class PromptIntent {
  const PromptIntent();
}

final class CreateCollectionIntent extends PromptIntent {
  const CreateCollectionIntent();
}

final class RenameCollectionIntent extends PromptIntent {
  const RenameCollectionIntent(this.from);

  final String from;
}

final class TextPromptOverlay extends NavigationOverlay {
  const TextPromptOverlay({
    required this.title,
    required this.fieldLabel,
    required this.confirmLabel,
    required this.intent,
    this.initial,
  });

  final String title;
  final String fieldLabel;
  final String confirmLabel;
  final PromptIntent intent;
  final String? initial;
}