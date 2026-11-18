import 'package:any/any.dart';

import '../models/navigation_overlay.dart';
import '../states/navigation_state.dart';
import 'ref_mutate.dart';
import 'feedback_commands.dart';
import 'preferences_commands.dart';

class ShowRemovePreferenceConfirmCommand extends Command {
  const ShowRemovePreferenceConfirmCommand(this.key);

  final String key;

  @override
  void call(Ref ref) {
    ref.mutate<NavigationState>(
      (s) => s.overlay = ConfirmOverlay(
        title: 'Remove preference?',
        message: 'Delete "$key" from the shared preference store?',
        onAccept: RunWithFeedbackCommand(
          RemovePreferenceCommand(key),
          successMessage: 'Removed "$key"',
        ),
      ),
    );
  }
}