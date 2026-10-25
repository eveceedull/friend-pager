import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'backend/local_config.dart';
import 'backend/registration_repository.dart';
import 'registration_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  RegistrationRepository? repository;
  String? setupError;
  var appVersion = 'unknown';
  try {
    final config = LocalConfig(const String.fromEnvironment('SUPABASE_URL'),
        const String.fromEnvironment('SUPABASE_ANON_KEY'));
    await Supabase.initialize(
        url: config.url,
        publishableKey: config.anonKey,
        authOptions: const FlutterAuthClientOptions(detectSessionInUri: false));
    repository = SupabaseRegistrationRepository(Supabase.instance.client);
    final info = await PackageInfo.fromPlatform();
    appVersion = '${info.version}+${info.buildNumber}';
  } catch (_) {
    setupError =
        'Start local Supabase and launch with the local configuration file. See README for setup.';
  }
  runApp(FriendPagerApp(
      repository: repository, appVersion: appVersion, setupError: setupError));
}

class FriendPagerApp extends StatelessWidget {
  const FriendPagerApp(
      {super.key, this.repository, this.appVersion = 'test', this.setupError});
  final RegistrationRepository? repository;
  final String appVersion;
  final String? setupError;
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Friend Pager',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.red),
        home: repository == null
            ? Scaffold(
                body: Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(setupError ??
                            'Local backend configuration required. See README.'))))
            : RegistrationGate(
                repository: repository!,
                appVersion: appVersion,
                platform: kIsWeb ? 'web' : defaultTargetPlatform.name),
      );
}

class PagerScreen extends StatefulWidget {
  const PagerScreen({super.key, this.installation, this.repository});
  final Installation? installation;
  final RegistrationRepository? repository;

  @override
  State<PagerScreen> createState() => _PagerScreenState();
}

class _PagerScreenState extends State<PagerScreen> {
  late bool _receiveAlerts = widget.installation?.receiving ?? true;
  bool _savingReceive = false;
  String? _receiveError;

  Future<void> _changeReceiving(bool enabled) async {
    setState(() {
      _savingReceive = true;
      _receiveError = null;
    });
    try {
      final result = await widget.repository?.setReceiving(enabled);
      if (mounted) {
        setState(() => _receiveAlerts = result?.receiving ?? enabled);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _receiveError =
            'Could not save receiving preference. Check your connection or rejoin after restarting.');
      }
    } finally {
      if (mounted) setState(() => _savingReceive = false);
    }
  }

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
              child: SingleChildScrollView(
                  child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.installation != null)
                    Text('Joined as ${widget.installation!.displayName}'),
                  if (_receiveError != null) Text(_receiveError!),
                  SwitchListTile(
                    title: const Text('Receive Alerts'),
                    subtitle: const Text('This device only'),
                    value: _receiveAlerts,
                    onChanged: _savingReceive ? null : _changeReceiving,
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
                    'Alert sending is a demo. No notifications are sent.',
                    textAlign: TextAlign.center,
                  ),
                ],
              )),
            ),
          ),
        ),
      ),
    );
  }
}
