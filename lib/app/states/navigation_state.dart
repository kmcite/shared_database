import '../models/navigation_overlay.dart';
import '../models/route_location.dart';

/// Shell tab, pushed routes, modals, and drawer — UI router source of truth.
class NavigationState {
  NavigationState({
    this.shellTabIndex = 0,
    List<RouteLocation>? stack,
    this.overlay,
    this.shellDrawerOpen = false,
  }) : stack = stack ?? [];

  /// [ShellTab.tabIndex] — drives [PageView] and chrome selection.
  int shellTabIndex;

  /// Root navigator stack above [AppShell].
  List<RouteLocation> stack;

  /// When non-null, [AppRouter] presents the overlay.
  NavigationOverlay? overlay;

  /// Pulse true to open the shell drawer once ([AppShell] acks it).
  bool shellDrawerOpen;
}