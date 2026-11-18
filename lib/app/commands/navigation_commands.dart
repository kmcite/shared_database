import 'package:any/any.dart';
import 'package:shared_database/shared_database.dart';

import '../models/navigation_overlay.dart';
import '../models/route_location.dart';
import '../models/shell_tab.dart';
import '../states/navigation_state.dart';
import 'ref_mutate.dart';

class PushRouteCommand extends Command {
  const PushRouteCommand(this.location);

  final RouteLocation location;

  @override
  void call(Ref ref) {
    ref.mutate<NavigationState>((s) => s.stack.add(location));
  }
}

class PopRouteCommand extends Command {
  const PopRouteCommand();

  @override
  void call(Ref ref) {
    ref.mutate<NavigationState>((s) {
      if (s.stack.isNotEmpty) s.stack.removeLast();
    });
  }
}

/// System back / route pop — keeps state aligned with the navigator.
class UserPoppedRouteCommand extends Command {
  const UserPoppedRouteCommand();

  @override
  void call(Ref ref) {
    ref.mutate<NavigationState>((s) {
      if (s.stack.isNotEmpty) s.stack.removeLast();
    });
  }
}

class PushCollectionRouteCommand extends Command {
  const PushCollectionRouteCommand(this.collection, {this.focusRecordId});

  final CollectionInfo collection;
  final String? focusRecordId;

  @override
  void call(Ref ref) {
    ref.mutate<NavigationState>(
      (s) => s.stack.add(
        CollectionRouteLocation(collection, focusRecordId: focusRecordId),
      ),
    );
  }
}

class PushCollectionByNameRouteCommand extends Command {
  const PushCollectionByNameRouteCommand({
    required this.name,
    this.createdByPackage,
    this.recordCount = 0,
    this.createdAt = 0,
    this.focusRecordId,
  });

  final String name;
  final String? createdByPackage;
  final int recordCount;
  final int createdAt;
  final String? focusRecordId;

  @override
  void call(Ref ref) {
    ref.mutate<NavigationState>(
      (s) => s.stack.add(
        CollectionRouteLocation(
          CollectionInfo(
            name: name,
            createdAt: createdAt,
            createdByPackage: createdByPackage ?? '',
            recordCount: recordCount,
          ),
          focusRecordId: focusRecordId,
        ),
      ),
    );
  }
}

class PushAppCollectionsRouteCommand extends Command {
  const PushAppCollectionsRouteCommand({required this.packageName});

  final String packageName;

  @override
  void call(Ref ref) {
    ref.mutate<NavigationState>(
      (s) => s.stack.add(AppCollectionsRouteLocation(packageName)),
    );
  }
}

class SelectShellTabCommand extends Command {
  const SelectShellTabCommand(this.tab);

  final ShellTab tab;

  @override
  void call(Ref ref) {
    final nav = ref.of<NavigationState>();
    if (nav.shellTabIndex == tab.tabIndex) return;
    ref.mutate<NavigationState>((s) => s.shellTabIndex = tab.tabIndex);
  }
}

class SyncShellTabFromViewCommand extends Command {
  const SyncShellTabFromViewCommand(this.viewIndex);

  final int viewIndex;

  @override
  void call(Ref ref) {
    final nav = ref.of<NavigationState>();
    if (nav.shellTabIndex == viewIndex) return;
    ref.mutate<NavigationState>((s) => s.shellTabIndex = viewIndex);
  }
}

class ShowShellMoreSheetCommand extends Command {
  const ShowShellMoreSheetCommand(this.highlightedTabIndex);

  final int highlightedTabIndex;

  @override
  void call(Ref ref) {
    ref.mutate<NavigationState>(
      (s) => s.overlay = ShellMoreSheetOverlay(
        highlightedTabIndex: highlightedTabIndex,
      ),
    );
  }
}

class DismissNavigationOverlayCommand extends Command {
  const DismissNavigationOverlayCommand();

  @override
  void call(Ref ref) {
    ref.mutate<NavigationState>((s) => s.overlay = null);
  }
}

class OpenShellDrawerCommand extends Command {
  const OpenShellDrawerCommand();

  @override
  void call(Ref ref) {
    ref.mutate<NavigationState>((s) => s.shellDrawerOpen = true);
  }
}

class AckShellDrawerCommand extends Command {
  const AckShellDrawerCommand();

  @override
  void call(Ref ref) {
    ref.mutate<NavigationState>((s) => s.shellDrawerOpen = false);
  }
}