import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class PageAlert {
  const PageAlert(
      {required this.id,
      required this.senderId,
      required this.senderName,
      required this.remaining});
  final String id;
  final String senderId;
  final String senderName;
  final Duration remaining;
}

abstract class PagingRepository {
  Stream<String> get alerts;
  Stream<bool> get connection;
  Future<void> start();
  Future<PageAlert?> getLiveAlert(String id);
  Future<void> send();
  Future<void> dispose();
}

class SupabasePagingRepository implements PagingRepository {
  SupabasePagingRepository(this.client);
  final SupabaseClient client;
  final _alerts = StreamController<String>.broadcast();
  final _connection = StreamController<bool>.broadcast();
  RealtimeChannel? _channel;
  bool _disposed = false;
  Future<void>? _closing;
  @override
  Stream<String> get alerts => _alerts.stream;
  @override
  Stream<bool> get connection => _connection.stream;
  @override
  Future<void> start() async {
    final user = client.auth.currentUser;
    if (user == null || _channel != null || _disposed) {
      throw StateError('Installation session required');
    }
    final ready = Completer<void>();
    _channel = client
        .channel('pages:${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'alert_deliveries',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'recipient_user_id',
              value: user.id),
          callback: (payload) {
            if (!_disposed && payload.newRecord['id'] is String) {
              _alerts.add(payload.newRecord['id'] as String);
            }
          },
        )
        .subscribe((status, error) {
      if (_disposed) return;
      _connection.add(status == RealtimeSubscribeStatus.subscribed);
      if (status == RealtimeSubscribeStatus.subscribed && !ready.isCompleted) {
        ready.complete();
      }
      if ((status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut) &&
          !ready.isCompleted) {
        ready.completeError(StateError('Realtime unavailable'));
      }
    });
    await ready.future.timeout(const Duration(seconds: 10));
  }

  @override
  Future<void> send() async {
    // POST RPC: a single submission; never retry an ambiguous outcome.
    await client.rpc('send_alert').timeout(const Duration(seconds: 5));
  }

  @override
  Future<PageAlert?> getLiveAlert(String id) async {
    final elapsed = Stopwatch()..start();
    final value = await client.rpc('get_live_alert',
        params: {'p_id': id}).timeout(const Duration(seconds: 3));
    if (value == null) return null;
    final data = Map<String, dynamic>.from(value as Map);
    final remaining =
        Duration(milliseconds: (data['remaining_ms'] as num).toInt()) -
            elapsed.elapsed;
    if (remaining <= Duration.zero) return null;
    return PageAlert(
        id: data['id'] as String,
        senderId: data['sender_installation_id'] as String,
        senderName: data['sender_name'] as String,
        remaining: remaining);
  }

  @override
  Future<void> dispose() => _closing ??= _close();

  Future<void> _close() async {
    _disposed = true;
    final channel = _channel;
    if (channel != null) await client.removeChannel(channel);
    await _alerts.close();
    await _connection.close();
  }
}
