import 'dart:convert';
import 'package:http/http.dart' as http;
import 'local_config.dart';
import 'local_http_client.dart';

/// Native/CLI builds keep using dart-defines. Compose web builds obtain only a
/// public API key from their own local origin; the JSON cannot redirect the API.
Future<LocalConfig> loadLocalConfig({
  required String url,
  required String anonKey,
  Uri? webUri,
  http.Client? client,
}) async {
  if (url.isNotEmpty || anonKey.isNotEmpty || webUri == null) {
    return LocalConfig(url, anonKey);
  }
  final origin = webUri.origin;
  final guard = LocalConfig(origin, 'configuration-check');
  final local = LocalHttpClient(guard, inner: client);
  try {
    final response = await local
        .get(Uri.parse('$origin/local-config.json'))
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) {
      throw const FormatException('Local config unavailable');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return LocalConfig(origin, data['SUPABASE_ANON_KEY'] as String);
  } finally {
    local.close();
  }
}
