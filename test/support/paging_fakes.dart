import 'dart:async';
import 'package:friend_pager/alert_sound.dart';
import 'package:friend_pager/backend/paging_repository.dart';
import 'package:friend_pager/backend/registration_repository.dart';

const testInstallation =
    Installation(id: 'own-installation', displayName: 'Pilot', receiving: true);

class FakeRegistrationRepository implements RegistrationRepository {
  bool receiving = true;
  bool fail = false;
  @override
  Future<Installation?> restore() async => testInstallation;
  @override
  Future<Installation> join(
          {required String password,
          required String displayName,
          required String platform,
          required String deviceName,
          required String appVersion}) async =>
      testInstallation;
  @override
  Future<Installation> setReceiving(bool enabled) async {
    if (fail) throw StateError('offline');
    receiving = enabled;
    return Installation(
        id: testInstallation.id, displayName: 'Pilot', receiving: enabled);
  }
}

class FakePagingRepository implements PagingRepository {
  final events = StreamController<String>.broadcast();
  final connections = StreamController<bool>.broadcast();
  final pages = <String, PageAlert?>{};
  int sends = 0;
  int reads = 0;
  bool fail = false;
  Completer<void>? pendingSend;
  Completer<PageAlert?>? pendingRead;
  bool disposed = false;
  @override
  Stream<String> get alerts => events.stream;
  @override
  Stream<bool> get connection => connections.stream;
  @override
  Future<void> start() async {
    connections.add(true);
  }

  @override
  Future<PageAlert?> getLiveAlert(String id) async {
    reads++;
    if (fail) throw StateError('offline');
    return pendingRead == null ? pages[id] : pendingRead!.future;
  }

  @override
  Future<void> send() async {
    sends++;
    if (fail) throw StateError('unknown submission outcome');
    await pendingSend?.future;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await events.close();
    await connections.close();
  }
}

class FakeSound implements AlertSound {
  int plays = 0;
  int stops = 0;
  bool fail = false;
  bool disposed = false;
  @override
  Future<void> play() async {
    plays++;
    if (fail) throw StateError('blocked');
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

PageAlert page(String id,
        {String sender = 'another-installation',
        Duration remaining = const Duration(seconds: 20)}) =>
    PageAlert(
        id: id,
        senderId: sender,
        senderName: 'Other pilot',
        remaining: remaining);
