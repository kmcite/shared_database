import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'shared_database_windows_method_channel.dart';

abstract class SharedDatabaseWindowsPlatform extends PlatformInterface {
  /// Constructs a SharedDatabaseWindowsPlatform.
  SharedDatabaseWindowsPlatform() : super(token: _token);

  static final Object _token = Object();

  static SharedDatabaseWindowsPlatform _instance = MethodChannelSharedDatabaseWindows();

  /// The default instance of [SharedDatabaseWindowsPlatform] to use.
  ///
  /// Defaults to [MethodChannelSharedDatabaseWindows].
  static SharedDatabaseWindowsPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [SharedDatabaseWindowsPlatform] when
  /// they register themselves.
  static set instance(SharedDatabaseWindowsPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
