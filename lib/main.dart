import 'package:flutter/material.dart';

void main() => runApp(const FriendPagerApp());

class FriendPagerApp extends StatelessWidget {
  const FriendPagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Friend Pager',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.red),
      home: const PagerScreen(),
    );
  }
}

class PagerScreen extends StatefulWidget {
  const PagerScreen({super.key});

  @override
  State<PagerScreen> createState() => _PagerScreenState();
}

class _PagerScreenState extends State<PagerScreen> {
  bool _receiveAlerts = true;
  bool _armed = false;
  bool _submitted = false;

  void _confirm() {
    setState(() {
      _armed = false;
      _submitted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Friend Pager')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SwitchListTile(
                    title: const Text('Receive Alerts'),
                    subtitle: const Text('This device only'),
                    value: _receiveAlerts,
                    onChanged: (enabled) =>
                        setState(() => _receiveAlerts = enabled),
                  ),
                  const SizedBox(height: 48),
                  const Icon(Icons.notifications_active, size: 72),
                  const SizedBox(height: 24),
                  if (_submitted) ...[
                    const Text('Demo alert submitted (not sent)'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(() => _submitted = false),
                      child: const Text('Reset demo'),
                    ),
                  ] else if (_armed) ...[
                    const Text('Slide to confirm (demo)'),
                    const SizedBox(height: 12),
                    Slider(
                      key: const Key('confirmation_slider'),
                      value: 0,
                      min: 0,
                      max: 1,
                      onChanged: (value) {
                        if (value >= 1) _confirm();
                      },
                    ),
                    TextButton(
                      onPressed: () => setState(() => _armed = false),
                      child: const Text('Cancel'),
                    ),
                  ] else
                    FilledButton.icon(
                      key: const Key('send_alert_button'),
                      onPressed: () => setState(() => _armed = true),
                      icon: const Icon(Icons.campaign),
                      label: const Text('SEND ALERT'),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'Prototype only. No accounts, network requests, or notifications are implemented.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
