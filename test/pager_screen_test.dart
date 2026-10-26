import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:friend_pager/pager_screen.dart';
import 'support/paging_fakes.dart';
import 'package:friend_pager/backend/paging_repository.dart';

const sendButton = Key('send_alert_button');
const sliderKey = Key('confirmation_slider');
const submitted = 'Alert submitted. Delivery is best effort.';
Future<void> arm(WidgetTester tester) async {
  await tester.tap(find.byKey(sendButton));
  await tester.pumpAndSettle();
}

Future<void> slide(WidgetTester tester) async {
  final rect = tester.getRect(find.byKey(sliderKey));
  await tester.dragFrom(
      Offset(rect.left + 24, rect.center.dy), Offset(rect.width - 48, 0));
  await tester.pumpAndSettle();
}

void main() {
  late FakePagingRepository paging;
  late FakeRegistrationRepository registration;
  late FakeSound sound;
  Future<void> mount(WidgetTester tester) async {
    paging = FakePagingRepository();
    registration = FakeRegistrationRepository();
    sound = FakeSound();
    await tester.pumpWidget(MaterialApp(
        home: PagerScreen(
            installation: testInstallation,
            repository: registration,
            paging: paging,
            sound: sound)));
    await tester.pumpAndSettle();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }

  testWidgets('shows real controls and live connection state without sending',
      (tester) async {
    await mount(tester);
    expect(find.text('Connected for live alerts'), findsOneWidget);
    expect(find.text('Receive Alerts'), findsOneWidget);
    expect(find.byKey(sendButton), findsOneWidget);
    expect(paging.sends, 0);
    expect(sound.plays, 0);
    paging.connections.add(false);
    await tester.pumpAndSettle();
    expect(find.text('Live alerts disconnected'), findsOneWidget);
  });
  testWidgets(
      'arming, tapping the end, partial sliding and cancelling never send',
      (tester) async {
    await mount(tester);
    await arm(tester);
    final rect = tester.getRect(find.byKey(sliderKey));
    await tester.tapAt(Offset(rect.right - 24, rect.center.dy));
    await tester.pumpAndSettle();
    expect(paging.sends, 0);
    await tester.dragFrom(
        Offset(rect.left + 24, rect.center.dy), Offset(rect.width / 3, 0));
    await tester.pumpAndSettle();
    expect(paging.sends, 0);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(sendButton), findsOneWidget);
    await arm(tester);
    expect(paging.sends, 0);
  });
  for (final receiving in [true, false]) {
    testWidgets('slide submits without sounding sender; receiving=$receiving',
        (tester) async {
      await mount(tester);
      if (!receiving) {
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
      }
      await arm(tester);
      await slide(tester);
      expect(find.text(submitted), findsOneWidget);
      expect(paging.sends, 1);
      expect(sound.plays, 0);
      await tester.tap(find.text('Send another alert'));
      await tester.pumpAndSettle();
      await arm(tester);
      await slide(tester);
      expect(paging.sends, 2);
      expect(sound.plays, 0);
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          receiving);
    });
  }
  testWidgets(
      'pending submission blocks duplicate sends and failures never retry',
      (tester) async {
    await mount(tester);
    paging.pendingSend = Completer<void>();
    await arm(tester);
    await slide(tester);
    expect(find.text('Submitting alert…'), findsOneWidget);
    expect(paging.sends, 1);
    expect(find.byKey(sendButton), findsNothing);
    paging.pendingSend!.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.textContaining('may have been sent'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    expect(paging.sends, 1);
  });
  testWidgets(
      'received page shows sender, sounds once and expires without history',
      (tester) async {
    await mount(tester);
    paging.pages['page'] = page('page', remaining: const Duration(seconds: 2));
    paging.events.add('page');
    await tester.pumpAndSettle();
    expect(find.text('Alert from Other pilot'), findsOneWidget);
    expect(sound.plays, 1);
    paging.events.add('page');
    await tester.pumpAndSettle();
    expect(sound.plays, 1);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const Key('received_alert')), findsNothing);
    expect(sound.stops, greaterThan(0));
  });
  testWidgets(
      'sender echoes, expired events and disabled receivers never sound',
      (tester) async {
    await mount(tester);
    paging.pages['echo'] = page('echo', sender: testInstallation.id);
    paging.pages['stale'] = page('stale', remaining: Duration.zero);
    paging.events.add('echo');
    paging.events.add('stale');
    await tester.pumpAndSettle();
    expect(sound.plays, 0);
    expect(find.byKey(const Key('received_alert')), findsNothing);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    paging.pages['off'] = page('off');
    paging.events.add('off');
    await tester.pumpAndSettle();
    expect(sound.plays, 0);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    paging.events.add('off');
    await tester.pumpAndSettle();
    expect(sound.plays, 0);
  });
  testWidgets('receiving disabled during validation suppresses in-flight sound',
      (tester) async {
    await mount(tester);
    paging.pendingRead = Completer<PageAlert?>();
    paging.events.add('page');
    await tester.pump();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    paging.pendingRead!.complete(page('page'));
    await tester.pumpAndSettle();
    expect(sound.plays, 0);
    expect(find.byKey(const Key('received_alert')), findsNothing);
  });
  testWidgets('sound failures are visible and enable/test sound can recover',
      (tester) async {
    await mount(tester);
    sound.fail = true;
    paging.pages['page'] = page('page');
    paging.events.add('page');
    await tester.pumpAndSettle();
    expect(find.textContaining('Sound unavailable'), findsOneWidget);
    sound.fail = false;
    await tester.tap(find.text('Enable/test sound'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sound unavailable'), findsNothing);
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('received_alert')), findsNothing);
  });
}
