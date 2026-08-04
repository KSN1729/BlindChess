import 'package:flutter/widgets.dart';
import 'package:audioplayers/audioplayers.dart';
import 'settings_service.dart';

/// Service in charge of playing standard match sound effects.
class AudioService {
  static final AudioService instance = AudioService._internal();
  AudioService._internal();

  AudioPlayer? _player;

  /// Helper getter that detects if we are running in a widget test context.
  bool get _isTesting =>
      WidgetsBinding.instance.toString().contains('TestWidgetsFlutterBinding');

  /// Lazy initialisation of the player instance.
  void _initPlayer() {
    if (_isTesting) return; // Do not initialize in tests
    _player ??= AudioPlayer();
  }

  /// Plays an audio asset.
  ///
  /// [Offline-First Architecture & App Store Reliability]
  /// Bundling audio files locally (e.g. under assets/sounds/) ensures that the application operates
  /// 100% offline without any runtime dependencies on external URLs/CDN servers. This eliminates
  /// risk of sudden silence if third-party audio hosting goes down, reduces initial latency,
  /// and aligns with App Store requirements for robust offline execution.
  Future<void> _playSound(String assetPath) async {
    if (_isTesting) {
      return; // Completely skip audio playback during widget tests
    }
    if (SettingsService.instance.isMuted) return; // Skip if muted

    try {
      _initPlayer();
      await _player?.stop();
      await _player?.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  /// Plays sound effect for a standard move.
  Future<void> playMove() async {
    await _playSound('sounds/move.wav');
  }

  /// Plays sound effect for a piece capture.
  Future<void> playCapture() async {
    await _playSound('sounds/capture.wav');
  }

  /// Plays sound effect for check or game over alert.
  Future<void> playCheck() async {
    await _playSound('sounds/check.wav');
  }

  /// Plays sound effect for an incorrect selection guess.
  Future<void> playIncorrectGuess() async {
    await _playSound('sounds/incorrect_guess.wav');
  }
}
