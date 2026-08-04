import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class ChessVoiceInferenceService {
  static final ChessVoiceInferenceService _instance =
      ChessVoiceInferenceService._internal();
  factory ChessVoiceInferenceService() => _instance;
  ChessVoiceInferenceService._internal();

  Interpreter? _interpreter;
  Map<String, int>? _tokenToId;
  Map<int, String>? _idToToken;
  int _vocabSize = 0;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Loads the TFLite model and the tokenizer configuration from assets.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      // 1. Load Tokenizer definition
      final tokenizerJsonStr = await rootBundle.loadString(
        'assets/tokenizer.json',
      );
      final Map<String, dynamic> tokenizerData = json.decode(tokenizerJsonStr);

      final Map<String, dynamic> rawTokenToId = tokenizerData['token_to_id'];
      _tokenToId = rawTokenToId.map(
        (key, value) => MapEntry(key, value as int),
      );
      _idToToken = _tokenToId!.map((key, value) => MapEntry(value, key));
      _vocabSize = tokenizerData['vocab_size'] as int;

      // 2. Load TFLite interpreter
      _interpreter = await Interpreter.fromAsset('model_quantized.tflite');
      _isInitialized = true;
    } catch (e) {
      debugPrint('Failed to initialize ChessVoiceInferenceService: $e');
      _isInitialized = false;
    }
  }

  /// Helper to encode text prompt into input IDs
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

  /// Predict the intended move from noisy STT text and legal moves list.
  /// Returns a map: {'correctMove': String, 'confidence': double}
  Future<Map<String, dynamic>?> predict({
    required String stt,
    required String fen,
    required List<String> legalMoves,
  }) async {
    if (!_isInitialized ||
        _interpreter == null ||
        _tokenToId == null ||
        _idToToken == null) {
      await init();
      if (!_isInitialized) return null;
    }

    // 1. Format input prompt
    final prompt = '$stt [SEP] $fen [SEP] ${legalMoves.join(',')}';
    final List<int> encInput = _encodePrompt(prompt, 256);

    // 2. Prepare 2D list inputs for Interpreter
    final encoderInputsList = [encInput]; // Shape: [1, 256]
    final decoderInputsList = List.generate(
      1,
      (i) => List.filled(10, 0),
    ); // Shape: [1, 10]
    decoderInputsList[0][0] = _tokenToId!['[SOS]'] ?? 1;

    final List<String> predictedChars = [];
    double finalConfidenceProduct = 1.0;

    // Output buffer definition: shape [1, 10, vocabSize]
    final outputBuffer = List.generate(
      1,
      (i) => List.generate(10, (j) => List.filled(_vocabSize, 0.0)),
    );

    // 3. Autoregressive decoding loop
    for (int t = 1; t < 10; t++) {
      final inputs = [encoderInputsList, decoderInputsList];
      final outputs = {0: outputBuffer};

      try {
        _interpreter!.runForMultipleInputs(inputs, outputs);
      } catch (e) {
        debugPrint('Error executing TFLite inference step: $e');
        return null;
      }

      // Read logits for timestep t - 1
      final logits = outputBuffer[0][t - 1];

      // Find ArgMax index and value
      int nextId = 0;
      double maxLogitVal = -999.0;
      for (int i = 0; i < logits.length; i++) {
        if (logits[i] > maxLogitVal) {
          maxLogitVal = logits[i];
          nextId = i;
        }
      }

      final nextToken = _idToToken![nextId] ?? '[UNK]';
      if (nextToken == '[EOS]' || nextToken == '[PAD]') {
        break;
      }

      predictedChars.append(nextToken);
      finalConfidenceProduct *= maxLogitVal.clamp(0.0, 1.0);

      if (t < 9) {
        decoderInputsList[0][t] = nextId;
      }
    }

    final predMoveStr = predictedChars.join('').trim();

    // 4. Constrained Alignment mapping to legal moves list
    if (legalMoves.contains(predMoveStr)) {
      return {'correctMove': predMoveStr, 'confidence': finalConfidenceProduct};
    }

    // Match closest legal move using Levenshtein distance
    String bestMatch = legalMoves.isNotEmpty ? legalMoves.first : '';
    int minDistance = 999;
    for (final m in legalMoves) {
      final distance = _levenshteinDistance(predMoveStr, m);
      if (distance < minDistance) {
        minDistance = distance;
        bestMatch = m;
      }
    }

    return {'correctMove': bestMatch, 'confidence': finalConfidenceProduct};
  }

  /// Levenshtein Distance calculation to align malformed predictions to legal moves
  static int _levenshteinDistance(String s1, String s2) {
    if (s1.length < s2.length) return _levenshteinDistance(s2, s1);
    if (s2.isEmpty) return s1.length;

    List<int> previousRow = List<int>.generate(s2.length + 1, (i) => i);
    for (int i = 0; i < s1.length; i++) {
      List<int> currentRow = [i + 1];
      for (int j = 0; j < s2.length; j++) {
        int insertions = previousRow[j + 1] + 1;
        int deletions = currentRow[j] + 1;
        int substitutions = previousRow[j] + (s1[i] == s2[j] ? 0 : 1);
        currentRow.add(
          [
            insertions,
            deletions,
            substitutions,
          ].reduce((a, b) => a < b ? a : b),
        );
      }
      previousRow = currentRow;
    }
    return previousRow.last;
  }
}

extension _ListAppend<T> on List<T> {
  void append(T element) {
    add(element);
  }
}
