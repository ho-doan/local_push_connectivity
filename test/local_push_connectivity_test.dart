import 'package:flutter_test/flutter_test.dart';
import 'package:local_push_connectivity/local_push_connectivity.dart';
import 'package:local_push_connectivity/local_push_connectivity_platform_interface.dart';
import 'package:local_push_connectivity/local_push_connectivity_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockLocalPushConnectivityPlatform
    with MockPlatformInterfaceMixin
    implements LocalPushConnectivityPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<void> config({required ConnectMode mode}) {
    // TODO: implement config
    throw UnimplementedError();
  }

  @override
  Future<void> configSSID(String ssid) {
    // TODO: implement configSSID
    throw UnimplementedError();
  }

  @override
  Future<void> initial({
    IosSettings? ios,
    AndroidSettings? android,
    WindowsSettings? widows,
    WebSettings? web,
    ConnectMode? mode,
  }) {
    // TODO: implement initial
    throw UnimplementedError();
  }

  @override
  // TODO: implement message
  Stream<MessageType> get message => throw UnimplementedError();

  @override
  Future<bool> requestPermission() {
    // TODO: implement requestPermission
    throw UnimplementedError();
  }

  @override
  Future<void> setUser({required String userId}) {
    // TODO: implement setUser
    throw UnimplementedError();
  }

  @override
  Future<void> start() {
    // TODO: implement start
    throw UnimplementedError();
  }

  @override
  Future<void> stop() {
    // TODO: implement stop
    throw UnimplementedError();
  }
}

void main() {
  final LocalPushConnectivityPlatform initialPlatform =
      LocalPushConnectivityPlatform.instance;

  test('$MethodChannelLocalPushConnectivity is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelLocalPushConnectivity>());
  });

  test('getPlatformVersion', () async {
    LocalPushConnectivity localPushConnectivityPlugin =
        LocalPushConnectivity.instance;
    MockLocalPushConnectivityPlatform fakePlatform =
        MockLocalPushConnectivityPlatform();
    LocalPushConnectivityPlatform.instance = fakePlatform;

    expect(await localPushConnectivityPlugin.getPlatformVersion(), '42');
  });
}
