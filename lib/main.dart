import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'backend/local_config.dart';
import 'backend/local_http_client.dart';
import 'backend/registration_repository.dart';
import 'registration_screen.dart';
export 'pager_screen.dart';

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
        httpClient: LocalHttpClient(config),
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
