class LocalConfig {
  LocalConfig(this.url, this.anonKey) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'http' ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        !isLocalHost(uri.host) ||
        anonKey.isEmpty) {
      throw const FormatException(
          'A local Supabase URL and public key are required.');
    }
  }
  final String url;
  final String anonKey;
  static bool isLocalHost(String host) {
    if (host == 'localhost' || host == '::1') return true;
    final parts = host.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((v) => v == null || v < 0 || v > 255)) {
      return false;
    }
    return parts[0] == 127 ||
        parts[0] == 10 ||
        (parts[0] == 192 && parts[1] == 168) ||
        (parts[0] == 172 && parts[1]! >= 16 && parts[1]! <= 31);
  }
}
