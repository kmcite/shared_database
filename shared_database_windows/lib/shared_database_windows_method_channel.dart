import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'shared_database_windows_platform_interface.dart';

/// An implementation of [SharedDatabaseWindowsPlatform] that uses method channels.
class MethodChannelSharedDatabaseWindows extends SharedDatabaseWindowsPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('shared_database_windows');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
