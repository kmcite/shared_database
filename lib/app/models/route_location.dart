import 'package:shared_database/shared_database.dart';

/// Serializable root [Navigator] destinations — mutated via [NavigationState].
sealed class RouteLocation {
  const RouteLocation();
}

final class CollectionRouteLocation extends RouteLocation {
  const CollectionRouteLocation(this.collection, {this.focusRecordId});

  final CollectionInfo collection;
  final String? focusRecordId;
}

final class AppCollectionsRouteLocation extends RouteLocation {
  const AppCollectionsRouteLocation(this.packageName);

  final String packageName;
}