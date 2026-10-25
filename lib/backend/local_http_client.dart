import 'package:http/http.dart' as http;
import 'local_config.dart';

/// Fail closed before opening a connection outside this local backend origin.
class LocalHttpClient extends http.BaseClient {
  LocalHttpClient(LocalConfig config, {http.Client? inner})
      : _origin = Uri.parse(config.url).origin,
        _inner = inner ?? http.Client();
  final String _origin;
  final http.Client _inner;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request.url.origin != _origin) {
      throw StateError('Only the configured local backend origin is allowed.');
    }
    request.followRedirects = false;
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
