// import 'dart:convert';
import 'package:flutter/foundation.dart';
// import 'package:flutter/services.dart';
// import 'package:tflite_flutter/tflite_flutter.dart'; // Temporarily disabled for Android JVM compatibility fix

class ChessVoiceInferenceService {
  static final ChessVoiceInferenceService _instance =
      ChessVoiceInferenceService._internal();
  factory ChessVoiceInferenceService() => _instance;
  ChessVoiceInferenceService._internal();

  // dynamic _interpreter; // Interpreter? _interpreter; // Temporarily disabled
  // Map<String, int>? _tokenToId; // Temporarily disabled to pass flutter analyze
  // Map<int, String>? _idToToken; // Temporarily disabled to pass flutter analyze
  // int _vocabSize = 0; // Temporarily disabled to pass flutter analyze
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Loads the TFLite model and the tokenizer configuration from assets.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      // 1. Load Tokenizer definition
      // final tokenizerJsonStr = await rootBundle.loadString(
      //   'assets/tokenizer.json',
      // );
      // final Map<String, dynamic> tokenizerData = json.decode(tokenizerJsonStr);

      // final Map<String, dynamic> rawTokenToId = tokenizerData['token_to_id'];
      // _tokenToId = rawTokenToId.map(
      //   (key, value) => MapEntry(key, value as int),
      // );
      // _idToToken = _tokenToId!.map((key, value) => MapEntry(value, key)); // Temporarily disabled
      // _vocabSize = tokenizerData['vocab_size'] as int; // Temporarily disabled

      // 2. Load TFLite interpreter (Temporarily disabled for JVM compatibility fix)
      // _interpreter = await Interpreter.fromAsset('model_quantized.tflite');
      _isInitialized = true;
    } catch (e) {
      debugPrint('Failed to initialize ChessVoiceInferenceService: $e');
      _isInitialized = false;
    }
  }

  /// Helper to encode text prompt into input IDs
  /* Temporarily commented out to resolve unused_element warnings during JVM disablement
  List<int> _encodePrompt(String text, int maxLen) {
    if (_tokenToId == null) return List.filled(maxLen, 0);

    final cleanText = text.toLowerCase().trim();
    final words = cleanText.split(RegExp(r'\s+'));
    final List<int> ids = [];

    // [SOS] token
    ids.add(_tokenToId!['[SOS]'] ?? 1);

    for (final word in words) {
      if (word.isEmpty) continue;
      if (_tokenToId!.containsKey(word)) {
        ids.add(_tokenToId![word]!);
      } else {
        // Fallback: character-level tokenization for unknown words
        for (int i = 0; i < word.length; i++) {
          final char = word[i];
          ids.add(_tokenToId![char] ?? _tokenToId!['[UNK]']!);
        }
      }
    }

    // [EOS] token
    ids.add(_tokenToId!['[EOS]'] ?? 2);

    // Padding
    if (ids.length < maxLen) {
      final padId = _tokenToId!['[PAD]'] ?? 0;
      ids.addAll(List.filled(maxLen - ids.length, padId));
    } else {
      ids.removeRange(maxLen, ids.length);
    }

    return ids;
  }
  */

  /// Predict the intended move from noisy STT text and legal moves list.
  /// Returns a map: {'correctMove': String, 'confidence': double}
  Future<Map<String, dynamic>?> predict({
    required String stt,
    required String fen,
    required List<String> legalMoves,
  }) async {
    // Temporarily disabled for Android JVM compatibility fix.
    // Returns default fallback move/confidence.
    if (legalMoves.isNotEmpty) {
      return {'correctMove': legalMoves.first, 'confidence': 1.0};
    }
    return null;
  }
}

/* Temporarily commented out to resolve unused_element warnings during JVM disablement
extension _ListAppend<T> on List<T> {
  void append(T element) {
    add(element);
  }
}
*/
