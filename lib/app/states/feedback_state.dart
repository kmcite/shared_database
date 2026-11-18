/// Snackbar / toast queue — shown by [AppRouter], cleared after display.
class FeedbackState {
  String? message;
  bool isError = false;
}