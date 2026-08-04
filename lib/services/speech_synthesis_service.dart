import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:audioplayers/audioplayers.dart';

/// Service in charge of synthesizing and playing offline chess spoken commands.
abstract class SpeechSynthesisService {
  static SpeechSynthesisService instance = RealSpeechSynthesisService();

  /// Generates a speech file asynchronously for the given text.
  /// Returns the absolute path of the generated WAV file, or null on failure.
  Future<String?> generateSpeech(String text, {String boardId = 'default', String category = 'move'});

  /// Plays the WAV file located at the specified absolute path.
  Future<void> play(String path);

  /// Generates and plays the synthesized audio.
  Future<void> speak(String text, {String boardId = 'default', String category = 'move'});
}

/// Production implementation spawning the Python speech pipeline subprocess.
class RealSpeechSynthesisService implements SpeechSynthesisService {
  AudioPlayer? _player;

  bool get _isTesting =>
      WidgetsBinding.instance.toString().contains('TestWidgetsFlutterBinding');

  void _initPlayer() {
    if (_isTesting) return;
    _player ??= AudioPlayer();
  }

  String _getScriptPath() {
    var dir = Directory.current;
    for (int i = 0; i < 4; i++) {
      final target = Directory('${dir.path}/chess_voice_intel');
      if (target.existsSync()) {
        return '${target.path}/generate_single.py';
      }
      if (dir.path == dir.parent.path) break;
      dir = dir.parent;
    }
    return 'chess_voice_intel/generate_single.py';
  }

  String _getPythonCommand() {
    return Platform.isWindows ? 'python' : 'python3';
  }

  @override
  Future<String?> generateSpeech(String text, {String boardId = 'default', String category = 'move'}) async {
    try {
      final script = _getScriptPath();
      final cmd = _getPythonCommand();
      
      final result = await Process.run(
        cmd,
        [script, text, boardId, category],
        runInShell: true,
      );
      
      if (result.exitCode != 0) {
        debugPrint('Subprocess exited with code ${result.exitCode}: ${result.stderr}');
        return null;
      }
      
      final output = result.stdout.toString().trim();
      final data = jsonDecode(output) as Map<String, dynamic>;
      
      if (data['success'] == true) {
        final meta = data['metadata'] as Map<String, dynamic>;
        return meta['audioPath'] as String;
      } else {
        debugPrint('Script error: ${data['error']}');
        return null;
      }
    } catch (e) {
      debugPrint('Speech generation exception: $e');
      return null;
    }
  }

  @override
  Future<void> play(String path) async {
    if (_isTesting) return;
    try {
      _initPlayer();
      await _player?.stop();
      await _player?.play(DeviceFileSource(path));
    } catch (e) {
      debugPrint('Playback error: $e');
    }
  }

  @override
  Future<void> speak(String text, {String boardId = 'default', String category = 'move'}) async {
    final path = await generateSpeech(text, boardId: boardId, category: category);
    if (path != null) {
      await play(path);
    }
  }
}

/// Simulated mock implementation used for automated widget/unit tests.
class MockSpeechSynthesisService implements SpeechSynthesisService {
  final List<String> generatedTexts = [];
  bool lastGenerationSuccess = true;

  @override
  Future<String?> generateSpeech(String text, {String boardId = 'default', String category = 'move'}) async {
    generatedTexts.add(text);
    if (!lastGenerationSuccess) return null;
    return 'mock_speech_path.wav';
  }

  @override
  Future<void> play(String path) async {}

  @override
  Future<void> speak(String text, {String boardId = 'default', String category = 'move'}) async {
    await generateSpeech(text, boardId: boardId, category: category);
  }
}
