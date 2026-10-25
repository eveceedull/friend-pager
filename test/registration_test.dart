import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:friend_pager/main.dart';
import 'package:friend_pager/backend/local_config.dart';
import 'package:friend_pager/backend/registration_repository.dart';

const member =
    Installation(id: 'test-id', displayName: 'Pilot', receiving: false);

class FakeRegistration extends RegistrationRepository {
  Installation? saved;
  Object? restoreError;
  Object? joinError;
  bool saveFails = false;
  int joins = 0;
  Completer<Installation>? pending;
  Map<String, String>? details;
  @override
  Future<Installation?> restore() async {
    if (restoreError != null) throw restoreError!;
    return saved;
  }

  @override
  Future<Installation> join(
      {required String password,
      required String displayName,
      required String platform,
      required String deviceName,
      required String appVersion}) async {
    joins++;
    details = {
      'password': password,
      'name': displayName,
      'platform': platform,
      'device': deviceName,
      'version': appVersion
    };
    if (joinError != null) throw joinError!;
    return pending == null ? member : pending!.future;
  }

  @override
  Future<Installation> setReceiving(bool enabled) async {
    if (saveFails) throw StateError('offline');
    return Installation(
        id: member.id, displayName: member.displayName, receiving: enabled);
  }
}

Future<void> fill(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('display_name')), 'Pilot');
  await tester.enterText(
      find.byKey(const Key('group_password')), 'test-group-password');
}

void main() {
  test('local config accepts only loopback and private literal addresses', () {
    for (final host in [
      'localhost',
      '127.0.0.1',
      '10.0.2.2',
      '192.168.1.20',
      '172.16.0.2',
      '[::1]'
    ]) {
      expect(
          LocalConfig('http://$host:54321', 'public-key').url, contains(host));
    }
    for (final url in [
      '',
      'https://example.supabase.co',
      'http://example.com',
      'http://169.254.169.254',
      'http://172.32.0.1',
      'http://192.168.1.999',
      'http://localhost.example.com',
      'http://user:pass@localhost',
      'http://localhost/path',
      'http://localhost?redirect=external',
      'http://localhost#fragment'
    ]) {
      expect(() => LocalConfig(url, 'public-key'), throwsFormatException);
    }
    expect(() => LocalConfig('http://localhost', ''), throwsFormatException);
  });
  testWidgets('missing configuration never shows the demo as a joined user',
      (tester) async {
    await tester.pumpWidget(const FriendPagerApp());
    expect(find.textContaining('configuration required'), findsOneWidget);
    expect(find.text('SEND ALERT'), findsNothing);
  });
  testWidgets('requires a name and password before contacting the backend',
      (tester) async {
    final repo = FakeRegistration();
    await tester.pumpWidget(FriendPagerApp(repository: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('join_group')));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsNWidgets(2));
    expect(repo.joins, 0);
    expect(find.text('SEND ALERT'), findsNothing);
  });
  testWidgets(
      'joins once, clears the password, passes metadata and shows saved receiving preference',
      (tester) async {
    final repo = FakeRegistration()..pending = Completer<Installation>();
    await tester
        .pumpWidget(FriendPagerApp(repository: repo, appVersion: '1.2.3+4'));
    await tester.pumpAndSettle();
    await fill(tester);
    await tester.tap(find.byKey(const Key('join_group')));
    await tester.pump();
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('join_group')))
            .onPressed,
        isNull);
    expect(repo.joins, 1);
    expect(repo.details!['version'], '1.2.3+4');
    expect(repo.details!['name'], 'Pilot');
    repo.pending!.complete(member);
    await tester.pumpAndSettle();
    expect(find.text('Joined as Pilot'), findsOneWidget);
    expect(find.byKey(const Key('group_password')), findsNothing);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue);
  });
  testWidgets('wrong password leaves join screen available for retry',
      (tester) async {
    final repo = FakeRegistration()
      ..joinError = const JoinFailure('Wrong password');
    await tester.pumpWidget(FriendPagerApp(repository: repo));
    await tester.pumpAndSettle();
    await fill(tester);
    await tester.tap(find.byKey(const Key('join_group')));
    await tester.pumpAndSettle();
    expect(find.text('Wrong password'), findsOneWidget);
    expect(find.text('SEND ALERT'), findsNothing);
    repo.joinError = null;
    await tester.tap(find.byKey(const Key('join_group')));
    await tester.pumpAndSettle();
    expect(find.text('Joined as Pilot'), findsOneWidget);
  });
  testWidgets(
      'connection errors do not expose raw error details or unlock the pager',
      (tester) async {
    final repo = FakeRegistration()
      ..joinError = StateError('sensitive details');
    await tester.pumpWidget(FriendPagerApp(repository: repo));
    await tester.pumpAndSettle();
    await fill(tester);
    await tester.tap(find.byKey(const Key('join_group')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Check your connection'), findsOneWidget);
    expect(find.textContaining('sensitive details'), findsNothing);
  });
  testWidgets(
      'restore failure offers retry without creating a replacement identity',
      (tester) async {
    final repo = FakeRegistration()..restoreError = StateError('offline');
    await tester.pumpWidget(FriendPagerApp(repository: repo));
    await tester.pumpAndSettle();
    expect(find.text('Retry connection'), findsOneWidget);
    expect(repo.joins, 0);
    repo.restoreError = null;
    repo.saved = member;
    await tester.tap(find.text('Retry connection'));
    await tester.pumpAndSettle();
    expect(find.text('Joined as Pilot'), findsOneWidget);
    expect(repo.joins, 0);
  });
  testWidgets(
      'failed preference save preserves previous state and sending remains available',
      (tester) async {
    final repo = FakeRegistration()
      ..saved = member
      ..saveFails = true;
    await tester.pumpWidget(FriendPagerApp(repository: repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse);
    expect(find.textContaining('Could not save receiving'), findsOneWidget);
    expect(find.text('SEND ALERT'), findsOneWidget);
  });
}
