import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'local_push_connectivity_method_channel.dart';
import 'models/models.dart';

abstract class LocalPushConnectivityPlatform extends PlatformInterface {
  /// Constructs a LocalPushConnectivityPlatform.
  LocalPushConnectivityPlatform() : super(token: _token);

  static final Object _token = Object();

  static LocalPushConnectivityPlatform _instance =
      MethodChannelLocalPushConnectivity();

  /// The default instance of [LocalPushConnectivityPlatform] to use.
  ///
  /// Defaults to [MethodChannelLocalPushConnectivity].
  static LocalPushConnectivityPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [LocalPushConnectivityPlatform] when
  /// they register themselves.
  static set instance(LocalPushConnectivityPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Stream<MessageType> get message;

  Future<void> initial({
    IosSettings? ios,
    AndroidSettings? android,
    WindowsSettings? widows,
    WebSettings? web,
    ConnectMode? mode,
  });

  Future<void> config({required ConnectMode mode});
  Future<void> configSSID(String ssid);

  Future<void> setUser({required String userId});

  Future<bool> requestPermission();

  Future<void> start();

  Future<void> stop();
}
