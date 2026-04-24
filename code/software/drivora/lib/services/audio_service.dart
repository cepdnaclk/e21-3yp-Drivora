import 'package:audioplayers/audioplayers.dart';

class AudioService {
  final AudioPlayer _player = AudioPlayer();

  AudioService() {
    _player.setReleaseMode(ReleaseMode.stop);
  }

  Future<void> playAlertSound() async {
    try {
      await _player.stop();
      // Tech beep
      await _player.play(UrlSource('https://www.soundjay.com/buttons/sounds/beep-07a.mp3'));
    } catch (e) {
      print('Audio error: $e');
    }
  }

  Future<void> playCriticalSound() async {
    try {
      await _player.stop();
      // Urgent siren
      await _player.play(UrlSource('https://www.soundjay.com/buttons/sounds/beep-11.mp3'));
    } catch (e) {
      print('Audio error: $e');
    }
  }

  Future<void> stop() async {
    await _player.stop();
  }
}
