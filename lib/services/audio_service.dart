import 'package:flutter/widgets.dart';
import 'package:audioplayers/audioplayers.dart';
import 'settings_service.dart';
import 'accessibility_settings_service.dart';

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
  Future<void> _playSound(String assetPath) async {
    if (_isTesting) {
      return; // Completely skip audio playback during widget tests
    }
    if (SettingsService.instance.isMuted) return; // Skip if muted
    if (!AccessibilitySettingsService.instance.audioFeedbackEnabled) return; // Skip if audio feedback is disabled

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

  /// Plays sound effect for check.
  Future<void> playCheck() async {
    await _playSound('sounds/check.wav');
  }

  /// Plays sound effect for an incorrect selection guess / illegal move.
  Future<void> playIncorrectGuess() async {
    await _playSound('sounds/incorrect_guess.wav');
  }

  /// Plays sound effect for pawn promotion.
  Future<void> playPromotion() async {
    await _playSound('sounds/check.wav');
  }

  /// Plays sound effect for a game over event.
  Future<void> playGameOver() async {
    await _playSound('sounds/check.wav');
  }

  /// Plays sound effect for an illegal move.
  Future<void> playIllegalMove() async {
    await playIncorrectGuess();
  }
}
