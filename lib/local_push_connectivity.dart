import 'local_push_connectivity_platform_interface.dart';
import 'models/models.dart';

export 'models/models.dart';

class LocalPushConnectivity {
  const LocalPushConnectivity._();
  static const instance = LocalPushConnectivity._();

  Future<String?> getPlatformVersion() {
    return LocalPushConnectivityPlatform.instance.getPlatformVersion();
  }

  Stream<MessageType> get message =>
      LocalPushConnectivityPlatform.instance.message;

  Future<void> initial({
    AndroidSettings? android,
    WindowsSettings? widows,
    IosSettings? ios,
    WebSettings? web,
    required ConnectMode? mode,
  }) => LocalPushConnectivityPlatform.instance.initial(
    mode: mode,
    android: android,
    widows: widows,
    ios: ios,
  );

  Future<void> config({required ConnectMode mode}) =>
      LocalPushConnectivityPlatform.instance.config(mode: mode);
  Future<void> configSSID(String ssid) =>
      LocalPushConnectivityPlatform.instance.configSSID(ssid);

  Future<void> setUser({required String userId}) =>
      LocalPushConnectivityPlatform.instance.setUser(userId: userId);

  Future<bool> requestPermission() =>
      LocalPushConnectivityPlatform.instance.requestPermission();

  Future<void> start() => LocalPushConnectivityPlatform.instance.start();

  Future<void> stop() => LocalPushConnectivityPlatform.instance.stop();
}
