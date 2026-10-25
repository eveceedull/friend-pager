import 'package:supabase_flutter/supabase_flutter.dart';

class Installation {
  const Installation(
      {required this.id, required this.displayName, required this.receiving});
  factory Installation.fromJson(Map<String, dynamic> data) => Installation(
        id: data['id'] as String,
        displayName: data['display_name'] as String,
        receiving: data['receiving'] as bool,
      );
  final String id;
  final String displayName;
  final bool receiving;
}

class JoinFailure implements Exception {
  const JoinFailure(this.message);
  final String message;
}

abstract class RegistrationRepository {
  Future<Installation?> restore();
  Future<Installation> join(
      {required String password,
      required String displayName,
      required String platform,
      required String deviceName,
      required String appVersion});
  Future<Installation> setReceiving(bool enabled);
}

class SupabaseRegistrationRepository implements RegistrationRepository {
  SupabaseRegistrationRepository(this.client);
  final SupabaseClient client;
  @override
  Future<Installation?> restore() async {
    if (client.auth.currentSession == null) return null;
    final data = await client
        .from('installations')
        .select()
        .eq('user_id', client.auth.currentUser!.id)
        .maybeSingle();
    return data == null ? null : Installation.fromJson(data);
  }

  @override
  Future<Installation> join(
      {required String password,
      required String displayName,
      required String platform,
      required String deviceName,
      required String appVersion}) async {
    if (client.auth.currentSession == null) {
      await client.auth.signInAnonymously();
    }
    final data = Map<String, dynamic>.from(
        await client.rpc('join_installation', params: {
      'p_password': password,
      'p_display_name': displayName.trim(),
      'p_platform': platform,
      'p_device_name': deviceName.trim(),
      'p_app_version': appVersion,
      'p_receiving': true,
    }) as Map);
    if (data['error'] != null) {
      throw JoinFailure(data['error'] == 'rate_limited'
          ? 'Too many join attempts. Try again in 15 minutes.'
          : 'Unable to join. Check the group password.');
    }
    return Installation.fromJson(
        Map<String, dynamic>.from(data['installation'] as Map));
  }

  @override
  Future<Installation> setReceiving(bool enabled) async =>
      Installation.fromJson(
        Map<String, dynamic>.from(await client.rpc('set_receiving', params: {
          'p_receiving': enabled,
        }) as Map),
      );
}
