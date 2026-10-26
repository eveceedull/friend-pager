import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:friend_pager/backend/local_config.dart';
import 'package:friend_pager/backend/local_http_client.dart';
import 'package:friend_pager/backend/paging_repository.dart';
import 'package:friend_pager/backend/registration_repository.dart';
import 'package:friend_pager/paging_controller.dart';
import '../test/support/paging_fakes.dart' show FakeSound;
import 'local_backend_test.dart' show MemoryAuthStorage;

class TestDevice {
  TestDevice(this.client, this.registration, this.installation, this.paging,
      this.sound, this.controller);
  final SupabaseClient client;
  final SupabaseRegistrationRepository registration;
  final Installation installation;
  final SupabasePagingRepository paging;
  final FakeSound sound;
  final PagingController controller;
}

void main() {
  final config = LocalConfig(const String.fromEnvironment('SUPABASE_URL'),
      const String.fromEnvironment('SUPABASE_ANON_KEY'));
  final clients = <SupabaseClient>[];
  final transports = <LocalHttpClient>[];
  final devices = <TestDevice>[];
  SupabaseClient client() {
    final transport = LocalHttpClient(config);
    transports.add(transport);
    final c = SupabaseClient(config.url, config.anonKey,
        httpClient: transport,
        authOptions: AuthClientOptions(
            autoRefreshToken: false, pkceAsyncStorage: MemoryAuthStorage()));
    clients.add(c);
    return c;
  }

  Future<TestDevice> device(String name) async {
    final c = client();
    final registration = SupabaseRegistrationRepository(c);
    final member = await registration.join(
        password: 'local-group-password',
        displayName: name,
        platform: 'web',
        deviceName: 'Synthetic device',
        appVersion: 'test+1');
    final paging = SupabasePagingRepository(c);
    final sound = FakeSound();
    final controller = PagingController(
        repository: paging,
        sound: sound,
        installationId: member.id,
        receiving: true);
    final result =
        TestDevice(c, registration, member, paging, sound, controller);
    devices.add(result);
    await controller.start();
    expect(controller.connected, isTrue);
    return result;
  }

  Future<void> until(bool Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Expected local Realtime event was not observed');
      }
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }

  Future<SupabaseClient> admin() async {
    final c = client();
    await c.auth.signInWithPassword(
        email: 'local-admin@example.test', password: 'local-admin-password');
    return c;
  }

  tearDown(() async {
    for (final d in devices) {
      d.controller.dispose();
      await d.paging.dispose();
    }
    devices.clear();
    // Channel cleanup is asynchronous; clients explicitly remove remaining channels.
    for (final c in clients) {
      await c.removeAllChannels();
      await c.dispose();
    }
    clients.clear();
    for (final t in transports) {
      t.close();
    }
    transports.clear();
  });

  test(
      'real Realtime dispatch sounds other eligible installations, never the sender',
      () async {
    final sender = await device('Server supplied sender');
    final receiver = await device('Server supplied sender');
    final muted = await device('Muted');
    final revoked = await device('Revoked');
    await muted.registration.setReceiving(false);
    muted.controller.setReceiving(false);
    final administrator = await admin();
    await administrator
        .rpc('revoke_installation', params: {'p_id': revoked.installation.id});
    await sender.controller.send();
    expect(sender.controller.submitted, isTrue);
    await until(() => receiver.sound.plays == 1);
    expect(receiver.controller.current!.senderName, 'Server supplied sender');
    expect(sender.sound.plays, 0);
    expect(await sender.client.from('alert_deliveries').select(), isEmpty);
    expect(await muted.client.from('alert_deliveries').select(), isEmpty);
    expect(await revoked.client.from('alert_deliveries').select(), isEmpty);
    // Receiving disabled must not disable sending.
    await sender.registration.setReceiving(false);
    sender.controller.setReceiving(false);
    await sender.controller.send();
    await until(() => receiver.sound.plays == 2);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(sender.sound.plays, 0);
    expect(muted.sound.plays, 0);
    expect(revoked.sound.plays, 0);
  });

  test(
      'unregistered/revoked tokens cannot send or forge deliveries or sender names',
      () async {
    final unregistered = client();
    await unregistered.auth.signInAnonymously();
    await expectLater(
        unregistered.rpc('send_alert'), throwsA(isA<PostgrestException>()));
    final sender = await device('Real name');
    final receiver = await device('Other');
    await expectLater(
        sender.client.from('alert_deliveries').insert({
          'sender_name': 'Forged',
          'recipient_user_id': receiver.client.auth.currentUser!.id,
        }),
        throwsA(isA<PostgrestException>()));
    await expectLater(
        sender.client.rpc('send_alert', params: {'sender_name': 'Forged'}),
        throwsA(isA<PostgrestException>()));
    final administrator = await admin();
    await administrator
        .rpc('revoke_installation', params: {'p_id': sender.installation.id});
    await expectLater(sender.paging.send(), throwsA(isA<PostgrestException>()));
    expect(receiver.sound.plays, 0);
    final unauthenticated = client();
    await expectLater(
        unauthenticated.rpc('send_alert'), throwsA(isA<PostgrestException>()));
  });

  test(
      'in-flight delivery revalidation honors receiving changes, revocation and short expiry',
      () async {
    final sender = await device('Sender');
    final receiver = await device('Receiver');
    // Keep a raw delivery ID without presenting it automatically on this client.
    receiver.controller.dispose();
    await receiver.client.removeAllChannels();
    await sender.paging.send();
    final rows = await receiver.client.from('alert_deliveries').select();
    expect(rows, hasLength(1));
    final row = rows.single;
    final id = row['id'] as String;
    final created = DateTime.parse(row['created_at'] as String);
    final expires = DateTime.parse(row['expires_at'] as String);
    expect(expires.difference(created), const Duration(seconds: 20));
    final probe = SupabasePagingRepository(receiver.client);
    expect((await probe.getLiveAlert(id))!.senderName, 'Sender');
    expect(await sender.paging.getLiveAlert(id), isNull);
    await receiver.registration.setReceiving(false);
    expect(await probe.getLiveAlert(id), isNull);
    await receiver.registration.setReceiving(true);
    final administrator = await admin();
    await administrator
        .rpc('revoke_installation', params: {'p_id': receiver.installation.id});
    expect(await probe.getLiveAlert(id), isNull);
    await receiver.registration.join(
        password: 'local-group-password',
        displayName: 'Receiver',
        platform: 'web',
        deviceName: 'Synthetic device',
        appVersion: 'test+1');
    // This test waits for the real server TTL; no expiry or authorization gates are bypassed.
    await Future<void>.delayed(const Duration(seconds: 21));
    expect(await probe.getLiveAlert(id), isNull);
    expect(await receiver.client.from('alert_deliveries').select(), isEmpty);
    await probe.dispose();
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('subscription reconnects do not fetch or replay queued alerts',
      () async {
    final sender = await device('Sender');
    final receiver = await device('Receiver');
    receiver.controller.dispose();
    await receiver.client.removeAllChannels();
    await sender.paging.send();
    expect(
        await receiver.client.from('alert_deliveries').select(), hasLength(1));
    final repo = SupabasePagingRepository(receiver.client);
    final sounds = FakeSound();
    final reconnected = PagingController(
        repository: repo,
        sound: sounds,
        installationId: receiver.installation.id,
        receiving: true);
    addTearDown(() async {
      reconnected.dispose();
      await repo.dispose();
    });
    await reconnected.start();
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(sounds.plays, 0);
    await sender.paging.send();
    await until(() => sounds.plays == 1);
    expect(reconnected.current!.senderName, 'Sender');
  });
}
