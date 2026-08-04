import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Abstract translation layer for device microphone speech recognition
/// allowing 100% test isolation.
abstract class SpeechService {
  static SpeechService instance = RealSpeechService();

  bool get isListening;
  Future<bool> initialize();
  Future<void> listen({
    required Function(String text, double confidence) onResult,
    required VoidCallback onStatusChanged,
  });
  Future<void> stop();
}

/// Production implementation leveraging native OS Android/iOS speech APIs.
class RealSpeechService implements SpeechService {
  stt.SpeechToText? _speech;
  bool _isInitialized = false;

  @override
  bool get isListening => _speech?.isListening ?? false;

  @override
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    _speech ??= stt.SpeechToText();
    try {
      _isInitialized = await _speech!.initialize(
        onError: (errorNotification) {
          debugPrint('Speech recognition error: ${errorNotification.errorMsg}');
        },
        onStatus: (status) {
          debugPrint('Speech recognition status: $status');
        },
      );
    } catch (e) {
      debugPrint('Error initializing speech: $e');
      _isInitialized = false;
    }
    return _isInitialized;
  }

  @override
  Future<void> listen({
    required Function(String text, double confidence) onResult,
    required VoidCallback onStatusChanged,
  }) async {
    if (!_isInitialized) {
      final success = await initialize();
      if (!success) return;
    }

    try {
      await _speech!.listen(
        onResult: (result) {
          onResult(result.recognizedWords, result.confidence);
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
          cancelOnError: true,
          partialResults: true,
          listenFor: const Duration(seconds: 10),
          pauseFor: const Duration(seconds: 3),
        ),
      );
      onStatusChanged();
    } catch (e) {
      debugPrint('Error starting listening: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _speech?.stop();
    } catch (e) {
      debugPrint('Error stopping speech: $e');
    }
  }
}

/// Simulated mock implementation used exclusively in automated widget/unit tests.
class MockSpeechService implements SpeechService {
  bool _isListening = false;
  Function(String text, double confidence)? currentResultCallback;
  VoidCallback? currentStatusCallback;

  @override
  bool get isListening => _isListening;

  @override
  Future<bool> initialize() async {
    return true;
  }

  @override
  Future<void> listen({
    required Function(String text, double confidence) onResult,
    required VoidCallback onStatusChanged,
  }) async {
    _isListening = true;
    currentResultCallback = onResult;
    currentStatusCallback = onStatusChanged;
    onStatusChanged();
  }

  @override
  Future<void> stop() async {
    _isListening = false;
    currentStatusCallback?.call();
  }

  void simulateSpeech(String text, {double confidence = 1.0}) {
    currentResultCallback?.call(text, confidence);
  }
}
