abstract class ConnectMode {
  final String host;
  final int port;
  const ConnectMode({
    required this.host,
    required this.port,
  });
}

class ConnectModeTCP extends ConnectMode {
  const ConnectModeTCP({
    required super.host,
    required super.port,
  });
}

class ConnectModeTCPSecure extends ConnectMode {
  final String publicHasKey;
  final String? cnName;
  final String? dnsName;

  const ConnectModeTCPSecure({
    required super.host,
    required super.port,
    required this.publicHasKey,
    this.cnName,
    this.dnsName,
  });
}

class ConnectModeWebSocket extends ConnectMode {
  final bool wss;
  final String part;

  const ConnectModeWebSocket({
    required super.host,
    required super.port,
    required this.wss,
    required this.part,
  });
}
