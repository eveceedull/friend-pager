import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:friend_pager/backend/local_config.dart';
import 'package:friend_pager/backend/local_http_client.dart';

void main() {
  test('only the configured origin is contacted; redirects cannot leave it',
      () async {
    var requests = 0;
    final client =
        LocalHttpClient(LocalConfig('http://127.0.0.1:54321', 'local'),
            inner: MockClient((request) async {
      requests++;
      expect(request.followRedirects, isFalse);
      return http.Response('', 302,
          headers: {'location': 'https://example.invalid'});
    }));
    addTearDown(client.close);
    expect(
        (await client.get(Uri.parse('http://127.0.0.1:54321/auth/v1/settings')))
            .statusCode,
        302);
    for (final url in [
      'https://example.invalid',
      'http://169.254.169.254',
      'http://127.0.0.1:54322',
      'https://127.0.0.1:54321'
    ]) {
      await expectLater(client.get(Uri.parse(url)), throwsStateError);
    }
    expect(requests, 1);
  });
}
