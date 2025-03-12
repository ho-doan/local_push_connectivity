import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:local_push_connectivity/local_push_connectivity.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  HttpOverrides.global = MyHttpOverrides();
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await LocalPushConnectivity.instance.initial(
        widows: const WindowsSettings(
          displayName: 'Local Push Sample',
          bundleId: 'com.hodoan.local_push_connectivity_example',
          icon: r'assets\favicon.png',
          iconContent: r'assets\info.svg',
        ),
        android: const AndroidSettings(icon: '@mipmap/ic_launcher'),
        ios: const IosSettings(ssid: 'HoDoanWifi'),
        web: const WebSettings(),
        // mode: const ConnectModeWebSocket(
        //   // host: 'ho-doan.com',
        //   host: '10.50.80.172',
        //   port: 4040,
        //   wss: false,
        //   // wss: false,
        //   part: '/ws/',
        // ),
        mode: const ConnectModeTCP(host: '10.50.80.172', port: 4041),
      );
      await LocalPushConnectivity.instance.requestPermission();
      runApp(const MyApp());
    },
    (e, s) {
      log(e.toString(), stackTrace: s);
    },
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';

  late StreamSubscription _subscription;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    String platformVersion;
    try {
      _subscription = LocalPushConnectivity.instance.message.listen((data) {
        log(data.message);
      });

      platformVersion =
          await LocalPushConnectivity.instance.getPlatformVersion() ??
          'Unknown platform version';

      // await LocalPushConnectivity.instance.config(
      //   mode: const ConnectModeWebSocket(
      //     host: 'localhost',
      //     port: 4040,
      //     wss: false,
      //     part: '/ws/',
      //   ),
      // );
      await LocalPushConnectivity.instance.config(
        mode: const ConnectModeWebSocket(
          // host: '10.50.80.172',
          host: '10.50.10.20',
          port: 4040,
          wss: false,
          part: '/ws/',
        ),
      );

      /// use TCP
      // await LocalPushConnectivity.instance.config(
      //   mode: const ConnectModeTCP(
      //     // host: '10.50.80.172',
      //     host: '10.50.10.20',
      //     port: 4041,
      //   ),
      // );

      /// use TCP Secure
      // await LocalPushConnectivity.instance.config(
      //   mode: const ConnectModeTCPSecure(
      //     // host: '10.50.80.172',
      //     host: '10.50.10.20',
      //     cnName: 'SimplePushServer',
      //     dnsName: 'simplepushserver.example',
      //     port: 4042,
      //     publicHasKey: 'XTQSZGrHFDV6KdlHsGVhixmbI/Cm2EMsz2FqE2iZoqU=',
      //   ),
      // );
      await LocalPushConnectivity.instance.setUser(userId: '4');
      await LocalPushConnectivity.instance.configSSID('OmiGuest');
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    // LocalPushConnectivity.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Plugin example app')),
        body: Center(child: Text('Running on: $_platformVersion\n')),
      ),
    );
  }
}
