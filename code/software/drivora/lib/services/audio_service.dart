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

  /// Per-type volume overrides (0–100). Defaults to 100 (full volume).
  final Map<AlertType, int> _volumeOverrides = {
    AlertType.collision: 100,
    AlertType.obstacleProx: 80,
    AlertType.laneWarning: 70,
    AlertType.drowsiness: 90,
    AlertType.info: 50,
    AlertType.systemAlert: 60,
    AlertType.calibration: 60,
  };

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) {
      stopAll();
    }
  }

  /// Set per-alert-type volume (0–100).
  Future<void> setVolumeForType(AlertType type, int volume) async {
    _volumeOverrides[type] = volume.clamp(0, 100);
  }

  /// Returns the normalised volume (0.0–1.0) for a given alert type.
  double _volumeFor(AlertType type) {
    return (_volumeOverrides[type] ?? 100) / 100.0;
  }

  /// Play a short preview/test tone at [volume] (0–100).
  Future<void> playTestTone({int volume = 70}) async {
    if (!_isEnabled) return;
    final normVolume = volume.clamp(0, 100) / 100.0;
    _playTone(880, 200, normVolume * 0.1);
  }

  /// Front Collision Warning - Emergency siren pattern
  /// 1250 Hz urgent pattern, repeating
  Future<void> playCollisionAlert() async {
    if (!_isEnabled) return;

    _stopRepetition();
    _currentAlert = AlertType.collision;

    _beepCount = 0;
    _playCollisionPattern();
  }

  Future<void> _playCollisionPattern() async {
    if (_currentAlert != AlertType.collision || !_isEnabled) return;

    final vol = _volumeFor(AlertType.collision);
    // Play 2-beep burst then wait 300ms
    for (var i = 0; i < 2; i++) {
      _playTone(1250, 100, vol * 0.09);
      await Future.delayed(const Duration(milliseconds: 150));
    }
  }

  /// Lane Warning - Soft warning beep
  Future<void> playLaneAlert() async {
    if (!_isEnabled) return;

    _stopRepetition();
    _currentAlert = AlertType.laneWarning;

    _playTone(850, 70, _volumeFor(AlertType.laneWarning) * 0.06);
  }

  /// General alert sound
  Future<void> playGeneralAlert() async {
    if (!_isEnabled) return;

    _stopRepetition();
    _currentAlert = AlertType.info;

    _playTone(800, 150, _volumeFor(AlertType.info) * 0.07);
  }

  /// System health alert
  Future<void> playSystemAlert() async {
    if (!_isEnabled) return;

    _stopRepetition();
    _currentAlert = AlertType.systemAlert;

    final vol = _volumeFor(AlertType.systemAlert);
    _playTone(700, 100, vol * 0.06);
    await Future.delayed(const Duration(milliseconds: 150));
    _playTone(700, 100, vol * 0.06);
  }

  /// Calibration success - ascending tones
  Future<void> playCalibrationSuccess() async {
    if (!_isEnabled) return;

    _stopRepetition();
    _currentAlert = AlertType.calibration;

    final vol = _volumeFor(AlertType.calibration);
    _playTone(800, 100, vol * 0.07);
    await Future.delayed(const Duration(milliseconds: 120));
    _playTone(1000, 100, vol * 0.07);
    await Future.delayed(const Duration(milliseconds: 120));
    _playTone(1200, 150, vol * 0.08);
  }

  /// Simple tone generation using audioplayers with fallback to asset beep.
  void _playTone(int frequency, int durationMs, double volume) {
    _alertPlayer.play(
      UrlSource(_generateToneUrl(frequency, durationMs, volume)),
    ).onError((error, stackTrace) {
      // Fallback: use simple beep asset
      _alertPlayer.play(AssetSource('sounds/beep.wav')).ignore();
    });
  }

  /// Generate data URI for tone (fallback stub — returns empty to use asset fallback).
  String _generateToneUrl(int frequency, int ms, double volume) {
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

  /// Obstacle Proximity Alert - progressive beeping based on distance.
  Future<void> playObstacleProximity({double distanceCm = 100.0}) async {
    if (!_isEnabled) return;

    _stopRepetition();
    _currentAlert = AlertType.obstacleProx;

    final vol = _volumeFor(AlertType.obstacleProx);
    final delayMs = math.max(100, 500 - (distanceCm ~/ 10)).toInt();
    _playTone(1000, 50, vol * 0.07);
    await Future.delayed(Duration(milliseconds: delayMs));
  }

  /// Lane Warning Alert — alias for playLaneAlert.
  Future<void> playLaneWarning() async => playLaneAlert();

  /// Drowsiness Alert - strong repeating alert pattern.
  Future<void> playDrowsinessAlert() async {
    if (!_isEnabled) return;

    _stopRepetition();
    _currentAlert = AlertType.drowsiness;

    final vol = _volumeFor(AlertType.drowsiness);
    _playTone(980, 150, vol * 0.08);
    await Future.delayed(const Duration(milliseconds: 100));
    _playTone(980, 150, vol * 0.08);
    await Future.delayed(const Duration(milliseconds: 600));
  }

  /// Dispose resources
  void dispose() {
    _stopRepetition();
    _alertPlayer.dispose();
    _bgPlayer.dispose();
  }
}