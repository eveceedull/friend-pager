import 'dart:async';
import 'package:flutter/foundation.dart';
import 'alert_sound.dart';
import 'backend/paging_repository.dart';

class PagingController extends ChangeNotifier {
  PagingController(
      {required this.repository,
      required this.sound,
      required this.installationId,
      required this.receiving});
  final PagingRepository? repository;
  final AlertSound sound;
  final String installationId;
  bool receiving;
  bool connected = false;
  bool sending = false;
  bool submitted = false;
  String? error;
  String? soundError;
  PageAlert? current;
  bool _disposed = false;
  int _generation = 0;
  StreamSubscription<String>? _alerts;
  StreamSubscription<bool>? _connection;
  final _seen = <String>{};
  final _forget = <String, Timer>{};
  Timer? _expiry;

  Future<void> start() async {
    final repo = repository;
    if (repo == null) {
      error = 'Paging backend not configured.';
      notifyListeners();
      return;
    }
    _alerts = repo.alerts.listen((id) => unawaited(_receive(id)), onError: (_) {
      if (!_disposed) {
        connected = false;
        notifyListeners();
      }
    });
    _connection = repo.connection.listen((value) {
      if (_disposed) return;
      connected = value;
      if (!value) {
        _generation++;
        dismiss();
      }
      notifyListeners();
    });
    try {
      await repo.start();
    } catch (_) {
      if (!_disposed) {
        connected = false;
        error =
            'Alert connection unavailable. Keep the app open while it reconnects.';
        notifyListeners();
      }
    }
  }

  Future<void> _receive(String id) async {
    if (_disposed || !_seen.add(id)) return;
    _forget[id] = Timer(const Duration(seconds: 21), () {
      _seen.remove(id);
      _forget.remove(id);
    });
    if (!receiving || !connected) return;
    final generation = _generation;
    try {
      final alert = await repository!.getLiveAlert(id);
      if (_disposed ||
          generation != _generation ||
          !receiving ||
          !connected ||
          alert == null ||
          alert.senderId == installationId ||
          alert.remaining <= Duration.zero) {
        return;
      }
      _expiry?.cancel();
      current = alert;
      _expiry = Timer(alert.remaining, dismiss);
      notifyListeners();
      try {
        await sound.play();
      } catch (_) {
        if (!_disposed) {
          soundError =
              'Sound unavailable. Use Enable/test sound and check device volume.';
          notifyListeners();
        }
      }
      if (_disposed || generation != _generation || current?.id != alert.id) {
        await sound.stop();
      }
    } catch (_) {
      // Fire-and-forget receipt validation: drop unavailable/expired events, no retries.
    }
  }

  Future<void> send() async {
    if (_disposed || sending) return;
    sending = true;
    submitted = false;
    error = null;
    notifyListeners();
    try {
      if (repository == null) throw StateError('No backend');
      await repository!.send();
      if (!_disposed) submitted = true;
    } catch (_) {
      if (!_disposed) {
        error =
            'Could not confirm submission. It may have been sent. No automatic retry was made.';
      }
    } finally {
      if (!_disposed) {
        sending = false;
        notifyListeners();
      }
    }
  }

  void resetSubmission() {
    submitted = false;
    error = null;
    notifyListeners();
  }

  void setReceiving(bool value) {
    if (receiving == value) return;
    receiving = value;
    _generation++;
    if (!value) dismiss();
    notifyListeners();
  }

  Future<void> testSound() async {
    if (!receiving || _disposed) return;
    try {
      await sound.play();
      if (!_disposed) soundError = null;
    } catch (_) {
      if (!_disposed) {
        soundError =
            'Sound unavailable. Check browser permissions and device volume.';
      }
    }
    if (!_disposed) notifyListeners();
  }

  void dismiss() {
    _expiry?.cancel();
    current = null;
    unawaited(sound.stop().catchError((_) {}));
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _expiry?.cancel();
    for (final timer in _forget.values) {
      timer.cancel();
    }
    unawaited(_alerts?.cancel());
    unawaited(_connection?.cancel());
    unawaited(repository?.dispose().catchError((_) {}));
    unawaited(sound.dispose().catchError((_) {}));
    super.dispose();
  }
}
