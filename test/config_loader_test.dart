import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:friend_pager/backend/config_loader.dart';

void main() {
  test('explicit local dart-defines work without runtime configuration',
      () async {
    final config =
        await loadLocalConfig(url: 'http://127.0.0.1:54321', anonKey: 'local');
    expect(config.url, 'http://127.0.0.1:54321');
    expect(config.anonKey, 'local');
  });
  test(
      'Compose web reads the public key from its own local origin without redirects',
      () async {
    final config = await loadLocalConfig(
        url: '',
        anonKey: '',
        webUri: Uri.parse('http://localhost:7357/'),
        client: MockClient((request) async {
          expect(request.url.toString(),
              'http://localhost:7357/local-config.json');
          expect(request.followRedirects, isFalse);
          return http.Response(
              '{"SUPABASE_ANON_KEY":"local","SUPABASE_URL":"https://ignored.invalid"}',
              200);
        }));
    expect(config.url, 'http://localhost:7357');
    expect(config.anonKey, 'local');
  });
  test(
      'runtime configuration never fetches a public origin or metadata endpoint',
      () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('{}', 200);
    });
    for (final url in ['https://example.invalid/', 'http://169.254.169.254/']) {
      await expectLater(
          loadLocalConfig(
              url: '', anonKey: '', webUri: Uri.parse(url), client: client),
          throwsFormatException);
    }
    expect(calls, 0);
  });
  test('missing config, redirects and partial explicit settings fail closed',
      () async {
    for (final status in [302, 404]) {
      await expectLater(
          loadLocalConfig(
              url: '',
              anonKey: '',
              webUri: Uri.parse('http://localhost:7357'),
              client: MockClient((_) async => http.Response('', status))),
          throwsFormatException);
    }
    await expectLater(
        loadLocalConfig(
            url: 'http://localhost:54321',
            anonKey: '',
            webUri: Uri.parse('http://localhost:7357')),
        throwsFormatException);
  });
}
