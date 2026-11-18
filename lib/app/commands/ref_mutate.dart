import 'package:any/any.dart';

/// Helpers for mutable state held in [AnyScope].
extension RefMutate on Ref {
  /// In-place edit; no `return s` or cascade required.
  void mutate<S>(void Function(S s) edit) {
    call<S>((s) {
      edit(s);
      return s;
    });
  }

  /// Notify after mutating via [of] (e.g. `ref.of<S>().field = x; ref.touch<S>();`).
  void touch<S>() => call<S>((s) => s);
}