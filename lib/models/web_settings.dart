class WebSettings {
  final String Function(String)? replace;
  final bool Function(String)? reload;

  const WebSettings({
    this.replace,
    this.reload,
  });
}
