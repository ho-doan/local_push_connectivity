// In order to *not* need this ignore, consider extracting the "web" version
// of your plugin as a separate package, instead of inlining it in the same
// package as the core of your plugin.
// ignore: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'dart:html' as html;

import 'dart:math' as math;

import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'local_push_connectivity_platform_interface.dart';
import 'models/models.dart';

/// A web implementation of the LocalPushConnectivityPlatform of the LocalPushConnectivity plugin.
class LocalPushConnectivityWeb extends LocalPushConnectivityPlatform {
  /// Constructs a LocalPushConnectivityWeb
  LocalPushConnectivityWeb();

  static void registerWith(Registrar registrar) {
    LocalPushConnectivityPlatform.instance = LocalPushConnectivityWeb();
  }

  /// Returns a [String] containing the version of the platform.
  @override
  Future<String?> getPlatformVersion() async {
    final version = web.window.navigator.userAgent;
    return version;
  }

  late String _host;
  late int _port;
  late String _path;
  late bool _wss;

  late ReplaceWeb? _replace;
  late ReloadWeb? _reload;

  late SocketBase socket;

  final _messageController = StreamController<MessageType>();

  @override
  Future<void> config({required ConnectMode mode}) async {
    if (mode is! ConnectModeWebSocket) {
      throw PlatformException(
        code: 'not support mode',
        message: 'not support mode ${mode.runtimeType.toString()}',
      );
    }
    _host = mode.host;
    _port = mode.port;
    _path = mode.part;
    _wss = mode.wss;
  }

  @override
  Future<void> initial({
    IosSettings? ios,
    AndroidSettings? android,
    WindowsSettings? widows,
    WebSettings? web,
    ConnectMode? mode,
  }) async {
    if (mode != null && mode is! ConnectModeWebSocket) {
      throw PlatformException(
        code: 'not support mode',
        message: 'not support mode ${mode.runtimeType.toString()}',
      );
    }
    _replace = web?.replace;
    _reload = web?.reload;
    if (mode != null) {
      mode as ConnectModeWebSocket;
      _host = mode.host;
      _port = mode.port;
      _path = mode.part;
      _wss = mode.wss;
    }
  }

  @override
  Stream<MessageType> get message => _messageController.stream;

  @override
  Future<bool> requestPermission() async {
    if (html.Notification.supported) {
      final permission = await html.Notification.requestPermission();
      if (permission == 'granted') {
        log('Permission granted');
        return true;
      } else {
        log('Permission denied');
        return false;
      }
    } else {
      log('Notifications not supported');
      return false;
    }
  }

  @override
  Future<void> setUser({required String userId}) async {
    await start();
    final deviceId = getDeviceID();
    log(deviceId);
    final data = <String, dynamic>{
      'MessageType': 'Register',
      'SendId': userId,
      'DeviceId': deviceId,
    };

    socket.sendMessage(json.encode(data));
  }

  @override
  Future<void> start() async {
    try {
      /// 'wss://$_host:$_port/ws/',
      socket = SocketBase.fromWebSocket(
        [
          if (_wss) 'wss://' else 'ws://',
          _host,
          ':',
          _port.toString(),
          _path,
        ].join(''),
        callback: (msg) {
          // final messageJson = json.decode(msg);
          final msgJS = MessageTypeJS(false, msg);
          final message = MessageType(inApp: false, message: msg);
          log('flutter log: ${msgJS.message}');
          _sendNotification(msgJS, _replace, _reload);
          _messageController.add(message);
        },
      );
      socket.connect();
    } catch (e) {
      log('initial websocket error $e');
    }
  }

  @override
  Future<void> stop() async {
    socket.dispose();
  }

  @override
  Future<void> configSSID(String ssid) async {}
}

//#region websocket common
class SocketBase {
  SocketBase({
    required this.callback,
    this.url,
    this.verifiedReceivedMessage,
    this.autoConnect = true,
  });

  factory SocketBase.fromWebSocket(
    String url, {
    required ValueChanged<String> callback,
    String? verifiedReceivedMessage,
    bool autoConnect = true,
  }) => SocketBase(
    url: url,
    callback: callback,
    verifiedReceivedMessage: verifiedReceivedMessage,
    autoConnect: autoConnect,
  );

  final String? url;
  final ValueChanged<String> callback;
  final String? verifiedReceivedMessage;
  final bool autoConnect;

  WebSocketChannel? _channel;

  StreamSubscription? _subscription;
  bool isConnect = false;

  Timer? _timer;

  Future<void> connect() async {
    await reconnect();
  }

  Future<void> reconnect() async {
    try {
      if (url != null) {
        log('connect $url');
        _channel = WebSocketChannel.connect(Uri.tryParse(url!)!);
        await _channel!.ready;
        _subscription = _channel!.stream.listen(
          (v) {
            if (verifiedReceivedMessage != null &&
                v.toString() != verifiedReceivedMessage) {
              sendMessage(verifiedReceivedMessage!);
              callback.call(v.toString());
            } else if (verifiedReceivedMessage == null) {
              callback.call(v.toString());
            }
          },
          onDone: () {
            log('done');
            dispose(false);
            if (autoConnect) {
              log('reconnect web socket');
              reconnect();
            }
          },
          onError: (e, s) {
            log('connect $url error: $e', stackTrace: s);
            dispose(false);
          },
          cancelOnError: true,
        );

        _timer ??= Timer.periodic(
          const Duration(seconds: 10),
          (_) async => await _channel?.ready,
        );
        isConnect = true;
      }
    } catch (e, s) {
      log('connect error: $e', stackTrace: s);
      dispose(false);
    }
  }

  // ignore: avoid_positional_boolean_parameters
  void dispose([bool cancelTimer = true]) {
    log('dispose socket');
    if (cancelTimer) _timer?.cancel();

    _channel?.sink.close(status.goingAway);

    _subscription?.cancel();
    isConnect = false;
    _channel = null;
  }

  void sendMessage(String message) {
    _channel?.sink.add(message);
  }
}

//#endregion

//#region common

typedef ReplaceWeb = String Function(String);
typedef ReloadWeb = bool Function(String);

// @JS('MessageTypeJS')
class MessageTypeJS {
  // external
  final bool inApp;
  // external
  final String message;

  const MessageTypeJS(this.inApp, this.message);

  // external factory MessageTypeJS(
  //   bool inApp,
  //   String message,
  // );
}

bool _sendNotification(
  MessageTypeJS message,
  ReplaceWeb? replace,
  ReloadWeb? reload,
) {
  // Check if the browser supports notifications
  if (html.Notification.supported == false) {
    log('Browser does not support notifications.');
    return false;
  }

  log('================== message: $message');
  Map<String, dynamic> messageJs = jsonDecode(message.message);

  if (messageJs['Notification']['Title'] == '') return false;

  log('================== browser state: ${html.document.visibilityState}');
  if (html.document.visibilityState == 'hidden') {
    var notification = html.Notification(
      messageJs['Notification']['Title'],
      body: messageJs['Notification']['Body'],
    );

    log('================== noti: ${messageJs['Notification']['Title']}');

    notification.onClick.listen((event) {
      event.preventDefault();
      String currentUrl = html.window.location.href;
      if (replace != null) {
        String url = replace(message.message);
        // html.window.focus();
        html.window.location.replace(url);

        if (currentUrl.contains(url)) {
          return;
        }
      }

      if (reload != null && reload(currentUrl)) {
        html.window.location.reload();
      }
    });
  }

  return true;
}

// Function to generate a UUID (v4)
String generateUUID() {
  final random = math.Random();
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replaceAllMapped(
    RegExp(r'x|y'),
    (match) {
      final r = random.nextInt(16);
      final v = match[0] == 'x' ? r : (r & 0x3 | 0x8);
      return v.toRadixString(16);
    },
  );
}

/// Function to set a cookie
void setCookie(String name, String value, int days) {
  DateTime now = DateTime.now();
  DateTime expiryDate = now.add(Duration(days: days));
  String expires = 'expires=${expiryDate.toUtc().toIso8601String()}';
  html.document.cookie = '$name=$value; $expires; path=/';
}

/// Function to retrieve a specific cookie
String? getCookie(String name) {
  String nameEQ = '$name=';
  List<String> cookies = html.document.cookie!.split(';');
  for (var cookie in cookies) {
    String trimmedCookie = cookie.trim();
    if (trimmedCookie.startsWith(nameEQ)) {
      return trimmedCookie.substring(nameEQ.length);
    }
  }
  return null;
}

/// Main function to get or create a device ID
String getDeviceID() {
  String? deviceId = getCookie("deviceId");
  if (deviceId == null) {
    deviceId = generateUUID(); // Generate a UUID
    setCookie("deviceId", deviceId, 365); // Cookie expires in 365 days
  }
  return deviceId;
}
//#endregion