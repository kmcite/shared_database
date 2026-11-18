import 'package:any/any.dart';
import 'package:flutter/services.dart';

import '../states/feedback_state.dart';
import 'ref_mutate.dart';

class ShowFeedbackCommand extends Command {
  const ShowFeedbackCommand(this.message, {this.isError = false});

  final String message;
  final bool isError;

  @override
  void call(Ref ref) {
    ref.mutate<FeedbackState>((s) {
      s.message = message;
      s.isError = isError;
    });
  }
}

class ClearFeedbackCommand extends Command {
  const ClearFeedbackCommand();

  @override
  void call(Ref ref) {
    ref.mutate<FeedbackState>((s) {
      s.message = null;
      s.isError = false;
    });
  }
}

class ShowErrorFeedbackCommand extends Command {
  const ShowErrorFeedbackCommand(this.error);

  final Object error;

  @override
  void call(Ref ref) {
    ShowFeedbackCommand(error.toString(), isError: true).call(ref);
  }
}

class CopyToClipboardCommand extends Command {
  const CopyToClipboardCommand(this.text, {this.label});

  final String text;
  final String? label;

  @override
  Future<void> call(Ref ref) async {
    await Clipboard.setData(ClipboardData(text: text));
    ShowFeedbackCommand(label ?? 'Copied to clipboard').call(ref);
  }
}

/// Runs [inner] and posts success or error feedback.
class RunWithFeedbackCommand extends Command {
  const RunWithFeedbackCommand(this.inner, {this.successMessage});

  final Command inner;
  final String? successMessage;

  @override
  Future<void> call(Ref ref) async {
    try {
      await inner.call(ref);
      if (successMessage != null) {
        ShowFeedbackCommand(successMessage!).call(ref);
      }
    } catch (e) {
      ShowErrorFeedbackCommand(e).call(ref);
      rethrow;
    }
  }
}