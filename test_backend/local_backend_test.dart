import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:friend_pager/backend/local_config.dart';
import 'package:friend_pager/backend/registration_repository.dart';

void main() {
  final config = LocalConfig(const String.fromEnvironment('SUPABASE_URL'),
      const String.fromEnvironment('SUPABASE_ANON_KEY'));
  final clients = <SupabaseClient>[];
  SupabaseClient client() {
    final value = SupabaseClient(config.url, config.anonKey,
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    clients.add(value);
    return value;
  }

  Future<Installation> join(SupabaseRegistrationRepository repo,
          {String password = 'local-group-password',
          String name = 'Same name'}) =>
      repo.join(
          password: password,
          displayName: name,
          platform: 'web',
          deviceName: 'Synthetic device',
          appVersion: 'test+1');
  tearDown(() async {
    for (final c in clients) {
      await c.dispose();
    }
    clients.clear();
  });

  test(
      'two devices can use the same name; RLS isolates them and preferences persist',
      () async {
    final a = client();
    final b = client();
    final repo = SupabaseRegistrationRepository(a);
    expect(await repo.restore(), isNull);
    final first = await join(repo);
    final second = await join(SupabaseRegistrationRepository(b));
    expect(first.id, isNot(second.id));
    expect(first.displayName, second.displayName);
    expect(await a.from('installations').select(), hasLength(1));
    expect(await a.from('installations').select().eq('id', second.id), isEmpty);
    await expectLater(
        a
            .from('installations')
            .update({'receiving': false}).eq('id', second.id),
        throwsA(isA<PostgrestException>()));
    expect((await repo.setReceiving(false)).receiving, isFalse);
    final session = a.auth.currentSession!.toJson();
    final restored = client();
    await restored.auth.recoverSession(jsonEncode(session));
    final saved = await SupabaseRegistrationRepository(restored).restore();
    expect(saved!.id, first.id);
    expect(saved.receiving, isFalse);
    expect(
        (await SupabaseRegistrationRepository(b).restore())!.receiving, isTrue);
  });

  test('wrong password creates no membership; attempts are actually persisted',
      () async {
    final c = client();
    final repo = SupabaseRegistrationRepository(c);
    for (var i = 0; i < 5; i++) {
      await expectLater(
          join(repo, password: 'wrong'), throwsA(isA<JoinFailure>()));
    }
    await expectLater(
        join(repo),
        throwsA(isA<JoinFailure>()
            .having((e) => e.message, 'rate limit', contains('15 minutes'))));
    expect(await repo.restore(), isNull);
    await expectLater(
        repo.setReceiving(false), throwsA(isA<PostgrestException>()));
  });

  test(
      'unregistered or anonymous API clients cannot read, insert or revoke installations',
      () async {
    final c = client();
    await expectLater(
        c.from('installations').select(), throwsA(isA<PostgrestException>()));
    final repo = SupabaseRegistrationRepository(c);
    final own = await join(repo);
    await expectLater(
        c.from('installations').insert({'display_name': 'forged'}),
        throwsA(isA<PostgrestException>()));
    await expectLater(c.rpc('revoke_installation', params: {'p_id': own.id}),
        throwsA(isA<PostgrestException>()));
    // User-controlled profile data must never confer administration privileges.
    await c.auth
        .updateUser(UserAttributes(data: {'role': 'admin', 'is_admin': true}));
    await expectLater(c.rpc('revoke_installation', params: {'p_id': own.id}),
        throwsA(isA<PostgrestException>()));
  });

  test(
      'admin password login is separate; revocation blocks an existing token until password rejoin',
      () async {
    final c = client();
    final repo = SupabaseRegistrationRepository(c);
    final own = await join(repo);
    final admin = client();
    await admin.auth.signInWithPassword(
        email: 'local-admin@example.test', password: 'local-admin-password');
    expect(await admin.from('installations').select().eq('id', own.id),
        hasLength(1));
    await expectLater(join(SupabaseRegistrationRepository(admin)),
        throwsA(isA<PostgrestException>()));
    await admin.rpc('revoke_installation', params: {'p_id': own.id});
    expect(await repo.restore(), isNull);
    await expectLater(
        repo.setReceiving(false), throwsA(isA<PostgrestException>()));
    await expectLater(
        join(repo, password: 'wrong'), throwsA(isA<JoinFailure>()));
    expect((await join(repo)).id, own.id);
    expect((await repo.restore())!.receiving, isTrue);
  });

  test(
      'public email signup cannot create admin accounts; invalid data is rejected server-side',
      () async {
    final c = client();
    await expectLater(
        c.auth.signUp(
            email: 'uninvited@example.test', password: 'test-password-123'),
        throwsA(isA<AuthException>()));
    await c.auth.signInAnonymously();
    for (final change in [
      {'p_display_name': '  '},
      {'p_platform': 'ios'},
      {'p_device_name': ''},
      {'p_password': 'a' * 73},
      {'p_receiving': null},
    ]) {
      await expectLater(
          c.rpc('join_installation', params: {
            'p_password': 'local-group-password',
            'p_display_name': 'Test',
            'p_platform': 'linux',
            'p_device_name': 'Device',
            'p_app_version': 'test',
            'p_receiving': true,
            ...change,
          }),
          throwsA(isA<PostgrestException>()));
    }
    // The private schema/password hash must never be available via REST.
    await expectLater(c.schema('private').from('group_credentials').select(),
        throwsA(isA<PostgrestException>()));
  });
}
