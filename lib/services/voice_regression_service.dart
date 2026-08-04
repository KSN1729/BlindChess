import 'dart:io';
import 'package:flutter/foundation.dart';
import '../utils/voice_command_parser.dart';

class VoiceRegressionService {
  static bool? _overrideEnableGeneration;

  static bool get enableGeneration {
    if (_overrideEnableGeneration != null) {
      return _overrideEnableGeneration!;
    }
    if (kIsWeb) return false;
    final isDesktop =
        Platform.isWindows || Platform.isMacOS || Platform.isLinux;
    if (!isDesktop) return false;
    return !Platform.environment.containsKey('FLUTTER_TEST');
  }

  static set enableGeneration(bool value) {
    _overrideEnableGeneration = value;
  }

  static void handleFailure({
    required String rawSpeech,
    required String boardFen,
    required List<Map<String, dynamic>> legalMoves,
    required String failureReason,
    required double sttConfidence,
    required VoiceIntent intent,
  }) {
    final expectedMove = _guessExpectedMove(rawSpeech, legalMoves, intent);
    final suggestedFix = _getSuggestedFix(failureReason);

    // 1. Print Diagnostic Summary
    _printDiagnosticSummary(
      expectedMove: expectedMove,
      rawSpeech: rawSpeech,
      pieceConfidence: intent.piece != null ? intent.confidence : 0.0,
      squareConfidence: intent.destinationSquare != null
          ? intent.confidence
          : 0.0,
      legalMoves: legalMoves,
      failureReason: failureReason,
      suggestedFix: suggestedFix,
    );

    // 2. Generate Test Code
    final filename = _sanitizeFilename(rawSpeech);
    final testCode = _generateTestCode(
      rawSpeech: rawSpeech,
      boardFen: boardFen,
      legalMoves: legalMoves,
      failureReason: failureReason,
      sttConfidence: sttConfidence,
      expectedMove: expectedMove,
    );

    // 3. Save to file if running on a VM and enabled
    if (enableGeneration && !kIsWeb) {
      try {
        final dir = Directory('test/voice_regressions');
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        final file = File('test/voice_regressions/$filename');
        file.writeAsStringSync(testCode);
        debugPrint(
          'Generated voice regression test: test/voice_regressions/$filename',
        );
      } catch (e) {
        debugPrint('Failed to save voice regression test: $e');
      }
    } else if (kIsWeb) {
      debugPrint(
        'Web fallback: Outputting generated voice regression test code:\n$testCode',
      );
    }
  }

  static String _guessExpectedMove(
    String rawSpeech,
    List<Map<String, dynamic>> legalMoves,
    VoiceIntent intent,
  ) {
    final dest = intent.destinationSquare;
    final piece = intent.piece;

    if (dest != null) {
      final matches = legalMoves
          .where(
            (m) => m['to'] == dest && (piece == null || m['piece'] == piece),
          )
          .toList();
      if (matches.length == 1) {
        return matches.first['san'] as String;
      }
      if (matches.length > 1) {
        if (intent.originFile != null) {
          final fileMatch = matches
              .where(
                (m) => (m['from'] as String).startsWith(intent.originFile!),
              )
              .toList();
          if (fileMatch.isNotEmpty) return fileMatch.first['san'] as String;
        }
        if (intent.originRank != null) {
          final rankMatch = matches
              .where((m) => (m['from'] as String).endsWith(intent.originRank!))
              .toList();
          if (rankMatch.isNotEmpty) return rankMatch.first['san'] as String;
        }
        return matches.first['san'] as String;
      }
    }

    final words = rawSpeech.toLowerCase().split(RegExp(r'\s+'));
    for (final w in words) {
      if (RegExp(r'^[a-h][1-8]$').hasMatch(w)) {
        final matches = legalMoves.where((m) => m['to'] == w).toList();
        if (matches.isNotEmpty) {
          return matches.first['san'] as String;
        }
      }
    }

    if (legalMoves.isNotEmpty) {
      return legalMoves.first['san'] as String;
    }
    return 'none';
  }

  static String _getSuggestedFix(String failureReason) {
    switch (failureReason) {
      case 'Speech recognition failed':
        return 'Verify that the microphone is working and transcription is active.';
      case 'Text normalization failed':
        return 'Check TextNormalizer regex patterns for spacing or punctuation issues.';
      case 'Piece not recognized':
        return 'Add new piece phonetic synonyms to pieceDictionary or adjust phonetic weights.';
      case 'Destination not recognized':
        return 'Add new square/file/rank phonetic synonyms to square_dictionary.dart.';
      case 'Confidence too low':
        return 'Check similarity weights or lower the executeThreshold/suggestionThreshold.';
      case 'Move not legal':
        return 'Ensure the intended move is legal in the current board state.';
      case 'Ambiguous move':
        return 'Provide more specific spoken words (e.g. piece name or file/rank of origin).';
      case 'Execution failed':
        return 'Check the chess board state logic or legal move executor implementation.';
      default:
        return 'Inspect the word similarity mappings and phonetic encoder codes.';
    }
  }

  static void _printDiagnosticSummary({
    required String expectedMove,
    required String rawSpeech,
    required double pieceConfidence,
    required double squareConfidence,
    required List<Map<String, dynamic>> legalMoves,
    required String failureReason,
    required String suggestedFix,
  }) {
    final legalSans = legalMoves.map((m) => m['san'] as String).toList();
    debugPrint('==================================================');
    debugPrint('DIAGNOSTIC SUMMARY');
    debugPrint('==================================================');
    debugPrint('Expected Move: $expectedMove');
    debugPrint('Recognized Speech: $rawSpeech');
    debugPrint(
      'Piece Confidence: ${(pieceConfidence * 100).toStringAsFixed(1)}%',
    );
    debugPrint(
      'Square Confidence: ${(squareConfidence * 100).toStringAsFixed(1)}%',
    );
    debugPrint('Legal Moves Available: $legalSans');
    debugPrint('Why the move was rejected: $failureReason');
    debugPrint('Suggested Fix: $suggestedFix');
    debugPrint('==================================================');
  }

  static String _sanitizeFilename(String phrase) {
    var s = phrase
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    if (s.startsWith('_')) s = s.substring(1);
    if (s.endsWith('_')) s = s.substring(0, s.length - 1);
    if (s.isEmpty) s = 'empty';
    return '${s}_test.dart';
  }

  static String _generateTestCode({
    required String rawSpeech,
    required String boardFen,
    required List<Map<String, dynamic>> legalMoves,
    required String failureReason,
    required double sttConfidence,
    required String expectedMove,
  }) {
    final movesBlock = _formatLegalMoves(legalMoves);
    return '''import 'package:flutter_test/flutter_test.dart';
import 'package:blind_chess/utils/voice_command_parser.dart';

void main() {
  test('Voice Regression - $rawSpeech', () {
    final legalMoves = $movesBlock;

    // Board FEN: $boardFen
    // Failure Reason: $failureReason
    // Speech to Text Confidence: $sttConfidence

    final result = VoiceCommandParser.parseCommand(
      '$rawSpeech',
      legalMoves,
      sttConfidence: $sttConfidence,
    );
    expect(result, isNotNull);
    expect(result!['error'], isNull);
    expect(result['san'], equals('$expectedMove'));
  });
}
''';
  }

  static String _formatLegalMoves(List<Map<String, dynamic>> legalMoves) {
    final sb = StringBuffer();
    sb.writeln('<Map<String, dynamic>>[');
    for (final m in legalMoves) {
      sb.writeln('      {');
      for (final entry in m.entries) {
        final val = entry.value;
        if (val is String) {
          sb.writeln("        '${entry.key}': '$val',");
        } else if (val is bool) {
          sb.writeln("        '${entry.key}': $val,");
        } else if (val is int || val is double) {
          sb.writeln("        '${entry.key}': $val,");
        } else {
          sb.writeln("        '${entry.key}': '$val',");
        }
      }
      sb.writeln('      },');
    }
    sb.write('    ]');
    return sb.toString();
  }
}
