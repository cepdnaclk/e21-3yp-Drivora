import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';

enum AlertType {
  collision,        // Front collision imminent - emergency siren pattern
  laneWarning,      // Lane departure - alert beeps
  obstacleProx,     // Obstacle proximity rear - progressive beeps
  drowsiness,       // Drowsiness/lean warning - strong repeating alert
  info,             // General info - soft notification
  systemAlert,      // System health alert
  calibration,      // Calibration success/progress
}

class AudioService {

  AudioService() {
    _alertPlayer.setReleaseMode(ReleaseMode.stop);
    _bgPlayer.setReleaseMode(ReleaseMode.stop);
  }
  final AudioPlayer _alertPlayer = AudioPlayer();
  final AudioPlayer _bgPlayer = AudioPlayer();

  Timer? _repititionTimer;
  AlertType? _currentAlert;
  int _beepCount = 0;
  bool _isEnabled = true;

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) {
      stopAll();
    }
  }

  /// Front Collision Warning - Emergency siren pattern
  /// 1250 Hz urgent pattern, repeating
  Future<void> playCollisionAlert() async {
    if (!_isEnabled) return;

    _stopRepetition();
    _currentAlert = AlertType.collision;

    // Emergency pattern: high-low pulse
    const pattern = [
      1250, 950,   // High-low pulse (ms frequencies)
      1250, 950,
    ];
    const durations = [100, 100, 100, 100];

    _beepCount = 0;
    _playCollisionPattern();
  }

  Future<void> _playCollisionPattern() async {
    if (_currentAlert != AlertType.collision || !_isEnabled) return;

    // Play 2-beep burst then wait 300ms
    for (var i = 0; i < 2; i++) {
      _playTone(1250, 100, 0.09);
      await Future.delayed(const Duration(milliseconds: 150));
    }
  }

  /// Lane Warning - Soft warning beep
  Future<void> playLaneAlert() async {
    if (!_isEnabled) return;

    _stopRepetition();
    _currentAlert = AlertType.laneWarning;

    _playTone(850, 70, 0.06);
  }

  /// General alert sound
  Future<void> playGeneralAlert() async {
    if (!_isEnabled) return;

    _stopRepetition();
    _currentAlert = AlertType.info;

    _playTone(800, 150, 0.07);
  }

  /// System health alert
  Future<void> playSystemAlert() async {
    if (!_isEnabled) return;

    _stopRepetition();
    _currentAlert = AlertType.systemAlert;

    _playTone(700, 100, 0.06);
    await Future.delayed(const Duration(milliseconds: 150));
    _playTone(700, 100, 0.06);
  }

  /// Calibration success - ascending tones
  Future<void> playCalibrationSuccess() async {
    if (!_isEnabled) return;

    _stopRepetition();
    _currentAlert = AlertType.calibration;

    _playTone(800, 100, 0.07);
    await Future.delayed(const Duration(milliseconds: 120));
    _playTone(1000, 100, 0.07);
    await Future.delayed(const Duration(milliseconds: 120));
    _playTone(1200, 150, 0.08);
  }

  /// Simple tone generation (placeholder - uses multiple calls for now)
  void _playTone(int frequency, int durationMs, double volume) {
    // This is a simplified version that would trigger actual tone synthesis
    // In a real implementation, you'd use:
    // - native platform channels
    // - or audio generation packages
    // For now, we use short audioplayer beeps as fallback
    _alertPlayer.play(
      UrlSource(_generateToneUrl(frequency, durationMs, volume)),
    ).onError((error, stackTrace) {
      // Fallback: use simple beep
      _alertPlayer.play(AssetSource('sounds/beep.wav')).ignore();
    });
  }

  /// Generate data URI for tone (fallback)
  String _generateToneUrl(int frequency, int ms, double volume) {
    // This would generate a proper data URI for audio
    // For now, return empty to use fallback
    return '';
  }

  /// Stop all audio and timers
  Future<void> stopAll() async {
    _stopRepetition();
    await _alertPlayer.stop();
    await _bgPlayer.stop();
    _currentAlert = null;
    _beepCount = 0;
  }

  /// Stop the repetition timer
  void _stopRepetition() {
    _repititionTimer?.cancel();
    _repititionTimer = null;
  }

  /// Check if audio is currently playing
  bool get isPlayingAlert => _currentAlert != null;

  /// Get current alert type
  AlertType? get currentAlertType => _currentAlert;

  /// Obstacle Proximity Alert - with distance parameter
  /// Progressive beeping based on distance
  Future<void> playObstacleProximity({double distanceCm = 100.0}) async {
    if (!_isEnabled) return;

    _stopRepetition();
    _currentAlert = AlertType.obstacleProx;

    // Progressive beeping based on distance
    // Closer = faster beeps
    final delayMs = math.max(100, 500 - (distanceCm ~/ 10)).toInt();
    _playTone(1000, 50, 0.07);
    await Future.delayed(Duration(milliseconds: delayMs));
  }

  /// Lane Warning Alert
  /// Alias for playLaneAlert
  Future<void> playLaneWarning() async => playLaneAlert();

  /// Drowsiness Alert
  /// Strong repeating alert pattern
  Future<void> playDrowsinessAlert() async {
    if (!_isEnabled) return;

    _stopRepetition();
    _currentAlert = AlertType.drowsiness;

    // Twin beeps pattern
    _playTone(980, 150, 0.08);
    await Future.delayed(const Duration(milliseconds: 100));
    _playTone(980, 150, 0.08);
    await Future.delayed(const Duration(milliseconds: 600));
  }

  /// Dispose resources
  void dispose() {
    _stopRepetition();
    _alertPlayer.dispose();
    _bgPlayer.dispose();
  }
}

