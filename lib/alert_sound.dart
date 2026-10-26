import 'package:audioplayers/audioplayers.dart';

abstract class AlertSound {
  Future<void> play();
  Future<void> stop();
  Future<void> dispose();
}

class DeviceAlertSound implements AlertSound {
  AudioPlayer? _player;
  int _generation = 0;
  @override
  Future<void> play() async {
    final token = ++_generation;
    final player = _player ??= AudioPlayer();
    await player.stop();
    if (token != _generation) return;
    await player.play(AssetSource('sounds/page.wav'));
  }

  @override
  Future<void> stop() async {
    _generation++;
    await _player?.stop();
  }

  @override
  Future<void> dispose() async {
    _generation++;
    await _player?.dispose();
  }
}
