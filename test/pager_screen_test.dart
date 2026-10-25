import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:friend_pager/main.dart';

void main() {
  testWidgets('shows paging and receiving controls', (tester) async {
    await tester.pumpWidget(const FriendPagerApp());

    expect(find.text('Receive Alerts'), findsOneWidget);
    expect(find.text('SEND ALERT'), findsOneWidget);
    expect(find.textContaining('Prototype only'), findsOneWidget);
  });

  testWidgets('receive toggle can be switched off and does not disable sending',
      (tester) async {
    await tester.pumpWidget(const FriendPagerApp());

    final receive = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(receive.value, isTrue);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();

    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse);
    expect(find.text('SEND ALERT'), findsOneWidget);
  });

  testWidgets('sending must first be armed and may be cancelled',
      (tester) async {
    await tester.pumpWidget(const FriendPagerApp());
    await tester.tap(find.byKey(const Key('send_alert_button')));
    await tester.pump();

    expect(find.text('Slide to confirm (demo)'), findsOneWidget);
    expect(find.text('Demo alert submitted (not sent)'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.text('SEND ALERT'), findsOneWidget);
  });

  testWidgets('completing confirmation only simulates an alert',
      (tester) async {
    await tester.pumpWidget(const FriendPagerApp());
    await tester.tap(find.byKey(const Key('send_alert_button')));
    await tester.pump();
    final slider = tester.widget<Slider>(find.byKey(const Key('confirmation_slider')));
    slider.onChanged!(1);
    await tester.pump();

    expect(find.text('Demo alert submitted (not sent)'), findsOneWidget);
    await tester.tap(find.text('Reset demo'));
    await tester.pump();
    expect(find.text('SEND ALERT'), findsOneWidget);
  });
}
