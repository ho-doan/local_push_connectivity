import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'local_push_connectivity_platform_interface.dart';
import 'models/models.dart';

/// An implementation of [LocalPushConnectivityPlatform] that uses method channels.
class MethodChannelLocalPushConnectivity extends LocalPushConnectivityPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('local_push_connectivity');

  @visibleForTesting
  final eventChannel = const EventChannel('local_push_connectivity/events');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<void> config({required ConnectMode mode}) =>
      methodChannel.invokeMethod<void>('config', {
        if (Platform.isWindows && mode is ConnectModeTCPSecure)
          'host': mode.dnsName ?? mode.cnName ?? mode.host
        else
          'host': mode.host,
        if (Platform.isWindows)
          'port': mode.port.toString()
        else
          'port': mode.port,
        if (mode is ConnectModeTCPSecure) 'publicHasKey': mode.publicHasKey,
        if (mode is ConnectModeWebSocket) 'part': mode.part,
        if (mode is ConnectModeWebSocket) 'wss': mode.wss,
      });

  @override
  Future<void> initial({
    IosSettings? ios,
    AndroidSettings? android,
    WindowsSettings? widows,
    WebSettings? web,
    ConnectMode? mode,
  }) async {
    await methodChannel.invokeMethod<void>('initial', {
      /// for android & windows
      'iconNotification': Platform.isWindows ? widows?.icon : android?.icon,
      'channelNotification': android?.channelNotification,

      /// for windows
      'displayName': widows?.displayName,

      /// for windows
      'iconContent': widows?.iconContent,

      /// for windows
      'appBundle': widows?.bundleId,

      /// for ios
      'ssid': ios?.ssid,
      'enableSSID': ios?.enableSSID,
      'host': mode?.host,
      if (Platform.isWindows)
        'port': mode?.port.toString()
      else
        'port': mode?.port,
      if (mode != null && mode is ConnectModeTCPSecure)
        'publicHasKey': mode.publicHasKey,
      if (mode != null && mode is ConnectModeWebSocket) 'part': mode.part,
      if (mode != null && mode is ConnectModeWebSocket) 'wss': mode.wss,
    });
  }

  @override
  Stream<MessageType> get message =>
      eventChannel.receiveBroadcastStream().map((e) {
        final json = jsonDecode(e);
        final type = json['type'] as bool? ?? false;
        log('========== $json');
        return MessageType(
          inApp: type,
          message: json['data'] is Map
              ? jsonEncode(json['data'])
              : json['data'] as String? ?? '',
        );
      });

  @override
  Future<bool> requestPermission() async {
    if (Platform.isWindows) return true;
    final check = await methodChannel.invokeMethod<bool>('requestPermission');
    return check ?? false;
  }

  @override
  Future<void> setUser({required String userId}) =>
      methodChannel.invokeMethod<void>('setUser', {'userId': userId});

  @override
  Future<void> start() => methodChannel.invokeMethod<void>('start');

  @override
  Future<void> stop() => methodChannel.invokeMethod<void>('stop');

  @override
  Future<void> configSSID(String ssid) async {
    if (Platform.isIOS) {
      await methodChannel.invokeMethod<void>('configSSID', {'ssid': ssid});
    }
  }
}
