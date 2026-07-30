class ImageProxy {
  ImageProxy._();

  static const _proxyBase = String.fromEnvironment('MANGADEX_PROXY_BASE');

  /// Wraps a MangaDex-hosted image URL through our own proxy in
  /// production — MangaDex serves a "read this at mangadex.org"
  /// placeholder for images hotlinked directly without going through
  /// a proper referrer, so this routes them server-side instead.
  static String wrap(String rawUrl) {
    if (_proxyBase.isEmpty) return rawUrl;
    return '/api/image-proxy?url=${Uri.encodeQueryComponent(rawUrl)}';
  }
}
