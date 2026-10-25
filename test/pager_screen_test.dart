import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:friend_pager/main.dart';

const sendButton = Key('send_alert_button');
const confirmationSlider = Key('confirmation_slider');
const submittedMessage = 'Demo alert submitted (not sent)';

Future<void> armAlert(WidgetTester tester) async {
  await tester.tap(find.byKey(sendButton));
  await tester.pumpAndSettle();
}

Future<void> slideToConfirm(WidgetTester tester) async {
  final rect = tester.getRect(find.byKey(confirmationSlider));
  await tester.dragFrom(
    Offset(rect.left + 24, rect.center.dy),
    Offset(rect.width - 48, 0),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows paging and receiving controls without submitting', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PagerScreen()));

    expect(find.text('Receive Alerts'), findsOneWidget);
    expect(find.byKey(sendButton), findsOneWidget);
    expect(find.textContaining('No notifications are sent'), findsOneWidget);
    expect(find.byKey(confirmationSlider), findsNothing);
    expect(find.text(submittedMessage), findsNothing);
  });

  testWidgets('receiving can be toggled off and back on', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PagerScreen()));
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
  });

  testWidgets('arming alone never submits and cancellation permits rearming', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PagerScreen()));
    await armAlert(tester);
    expect(find.text('Slide to confirm (demo)'), findsOneWidget);
    expect(find.byKey(sendButton), findsNothing);
    expect(find.text(submittedMessage), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(sendButton), findsOneWidget);
    expect(find.byKey(confirmationSlider), findsNothing);
    expect(find.text(submittedMessage), findsNothing);
    await armAlert(tester);
    expect(find.byKey(confirmationSlider), findsOneWidget);
    expect(find.text(submittedMessage), findsNothing);
  });

  testWidgets('a partial slide never submits', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PagerScreen()));
    await armAlert(tester);
    final rect = tester.getRect(find.byKey(confirmationSlider));
    await tester.dragFrom(
      Offset(rect.left + 24, rect.center.dy),
      Offset(rect.width / 3, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text(submittedMessage), findsNothing);
    expect(find.byKey(confirmationSlider), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(sendButton), findsOneWidget);
  });

  for (final receiving in [true, false]) {
    testWidgets('a real slide submits the demo with receiving=$receiving', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: PagerScreen()));
      if (!receiving) {
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
      }
      await armAlert(tester);
      await slideToConfirm(tester);
      expect(find.text(submittedMessage), findsOneWidget);
      expect(find.byKey(confirmationSlider), findsNothing);
      expect(find.byKey(sendButton), findsNothing);
      await tester.tap(find.text('Reset demo'));
      await tester.pumpAndSettle();
      expect(find.byKey(sendButton), findsOneWidget);
      expect(find.text(submittedMessage), findsNothing);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        receiving,
      );
      await armAlert(tester);
      await slideToConfirm(tester);
      expect(find.text(submittedMessage), findsOneWidget);
    });
  }
}
