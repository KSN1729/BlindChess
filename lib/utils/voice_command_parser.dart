import 'package:flutter/foundation.dart';
import '../services/word_similarity_service.dart';
import '../services/diagnostic_recorder.dart';
import '../services/voice_regression_service.dart';
import '../services/settings_service.dart';
import '../config/piece_dictionary.dart';
import '../config/square_dictionary.dart';
import '../config/number_dictionary.dart';
import '../config/voice_confidence_config.dart';
import 'phonetic_encoder.dart';

/// Cleans the raw spoken string by converting to lowercase, trimming,
/// collapsing whitespace, and removing standard punctuation.
class TextNormalizer {
  static String normalize(String text) {
    debugPrint('TextNormalizer INPUT: $text');
    var clean = text.toLowerCase().replaceAll(RegExp(r'[.,!?\-]'), ' ').trim();

    // Clean king side / queen side spaces and format castling
    clean = clean
        .replaceAll(RegExp(r'\bking\s+side\b'), 'kingside')
        .replaceAll(RegExp(r'\bqueen\s+side\b'), 'queenside')
        .replaceAll('o o o', 'o-o-o')
        .replaceAll('o o', 'o-o');

    // Normalize spelling alphabet / phonetic letters to standard A-H letters
    final Map<String, String> fileSynonyms = {};
    for (final entry in fileDictionary.entries) {
      final canonical = entry.key;
      for (final synonym in entry.value) {
        if (synonym != canonical) {
          fileSynonyms[synonym] = canonical;
        }
      }
    }
    fileSynonyms.forEach((syn, canonical) {
      clean = clean.replaceAll(RegExp('\\b$syn\\b'), canonical);
    });

    // Merge file letters [a-h] + connector + rank synonyms (e.g. "e to 4" -> "e4", "e on four" -> "e4")
    final Map<String, String> rankMapping = {};
    for (final entry in rankDictionary.entries) {
      final canonical = entry.key;
      for (final synonym in entry.value) {
        rankMapping[synonym] = canonical;
      }
    }

    clean = clean.replaceAllMapped(
      RegExp(r'\b([a-h])\s+(to|on|at|for|takes|take|captures|capture)\s+(one|won|first|wun|two|too|to|tu|three|third|tree|four|fore|for|fourth|foar|five|fifth|fiv|six|sixth|sicks|seven|seventh|sevn|eight|ate|eighth|eit|[1-8])\b', caseSensitive: false),
      (m) {
        final file = m.group(1)!;
        final rankWord = m.group(3)!.toLowerCase();
        final rankDigit = rankMapping[rankWord] ?? rankWord;
        return '$file$rankDigit';
      },
    );

    // Merge file letters [a-h] with adjacent rank synonyms (e.g. "e 4" -> "e4", "e to" -> "e2")
    // Rank 1
    clean = clean.replaceAllMapped(
      RegExp(r'\b([a-h])\s+(one|won|first|wun|1)\b', caseSensitive: false),
      (m) => '${m.group(1)}1',
    );
    // Rank 2
    clean = clean.replaceAllMapped(
      RegExp(r'\b([a-h])\s+(to|too|two|tu|2)\b', caseSensitive: false),
      (m) => '${m.group(1)}2',
    );
    // Rank 3
    clean = clean.replaceAllMapped(
      RegExp(r'\b([a-h])\s+(three|third|tree|3)\b', caseSensitive: false),
      (m) => '${m.group(1)}3',
    );
    // Rank 4
    clean = clean.replaceAllMapped(
      RegExp(r'\b([a-h])\s+(for|fore|four|fourth|foar|4)\b', caseSensitive: false),
      (m) => '${m.group(1)}4',
    );
    // Rank 5
    clean = clean.replaceAllMapped(
      RegExp(r'\b([a-h])\s+(five|fifth|fiv|5)\b', caseSensitive: false),
      (m) => '${m.group(1)}5',
    );
    // Rank 6
    clean = clean.replaceAllMapped(
      RegExp(r'\b([a-h])\s+(six|sixth|sicks|6)\b', caseSensitive: false),
      (m) => '${m.group(1)}6',
    );
    // Rank 7
    clean = clean.replaceAllMapped(
      RegExp(r'\b([a-h])\s+(seven|seventh|sevn|7)\b', caseSensitive: false),
      (m) => '${m.group(1)}7',
    );
    // Rank 8
    clean = clean.replaceAllMapped(
      RegExp(r'\b([a-h])\s+(eight|ate|eighth|eit|8)\b', caseSensitive: false),
      (m) => '${m.group(1)}8',
    );

    // Remove optional/filler words that are not part of the core chess intent
    clean = clean
        .replaceAll(RegExp(r'\b(move|to|on|at|for)\b'), ' ')
        .replaceAll(RegExp(r'\b(takes|take|captures|capture|x)\b'), ' ')
        .replaceAll(RegExp(r'\b(promote to|promotion|promote|promoting|promotes)\b'), ' ')
        .replaceAll(RegExp(r'\b(checkmate|check|mate)\b'), ' ');

    // Clean up spacing in coordinates:
    // e.g. "e 4" -> "e4"
    clean = clean.replaceAllMapped(
      RegExp(r'\b([a-h])\s+([1-8])\b', caseSensitive: false),
      (m) => '${m.group(1)}${m.group(2)}',
    );

    final result = clean.replaceAll(RegExp(r'\s+'), ' ').trim();
    debugPrint('TextNormalizer OUTPUT: $result');
    return result;
  }
}

class PieceCandidate {
  final String piece; // 'n', 'r', etc.
  final String name; // 'knight', etc.
  final double score;

  PieceCandidate({
    required this.piece,
    required this.name,
    required this.score,
  });
}

/// Normalizes spoken chess piece names and phonetic spelling mistakes
/// into standard piece type characters ('n', 'r', 'q', 'b', 'k', 'p').
class PieceNormalizer {
  static List<PieceCandidate> rankedCandidates(String word) {
    if (RegExp(r'^[a-h][1-8]$', caseSensitive: false).hasMatch(word)) return [];

    final allList = <PieceCandidate>[];
    final pieceCharMap = {
      'knight': 'n',
      'rook': 'r',
      'queen': 'q',
      'bishop': 'b',
      'king': 'k',
      'pawn': 'p',
    };

    for (final entry in pieceDictionary.entries) {
      final name = entry.key;
      final piece = pieceCharMap[name]!;
      double maxSim = 0.0;
      for (final synonym in entry.value) {
        final sim = WordSimilarityService.similarity(word, synonym);
        if (sim > maxSim) {
          maxSim = sim;
        }
      }
      allList.add(PieceCandidate(piece: piece, name: name, score: maxSim));
    }

    allList.sort((a, b) => b.score.compareTo(a.score));

    final String encWord = PhoneticEncoder.instance.encode(word);
    debugPrint('Piece Ranking');
    debugPrint('INPUT');
    debugPrint(word);
    debugPrint('↓');
    debugPrint('Encoded');
    debugPrint(encWord);
    debugPrint('↓');
    debugPrint('Candidates');
    for (final pc in allList) {
      debugPrint('${pc.name} ${(pc.score * 100).toStringAsFixed(0)}%');
    }

    return allList
        .where((pc) => pc.score >= VoiceConfidenceConfig.pieceThreshold)
        .toList();
  }

  static Map<String, dynamic>? normalize(String word) {
    debugPrint('PieceNormalizer INPUT: $word');
    final list = rankedCandidates(word);
    if (list.isEmpty) {
      debugPrint('PieceNormalizer OUTPUT: null');
      return null;
    }
    final best = list.first;
    final result = {
      'piece': best.piece,
      'confidence': best.score,
      'name': best.name,
    };
    debugPrint('PieceNormalizer OUTPUT: $result');
    return result;
  }

  static Map<String, double> getScores(String word) {
    final scores = <String, double>{};
    for (final entry in pieceDictionary.entries) {
      double maxSim = 0.0;
      for (final syn in entry.value) {
        final sim = WordSimilarityService.similarity(word, syn);
        if (sim > maxSim) maxSim = sim;
      }
      scores[entry.key] = maxSim;
    }
    return scores;
  }
}

class FileCandidate {
  final String file;
  final double score;
  FileCandidate(this.file, this.score);
}

class RankCandidate {
  final String rank;
  final double score;
  RankCandidate(this.rank, this.score);
}

class SquareCandidate {
  final String square;
  final double score;
  SquareCandidate({required this.square, required this.score});
}

/// Converts spoken file letters and rank numbers (separated or collapsed)
/// into a standard 2-character algebraic square (e.g. 'd5', 'b8').
class SquareNormalizer {
  static List<FileCandidate> rankedFiles(String token) {
    if (RegExp(r'^[a-h][1-8]$', caseSensitive: false).hasMatch(token)) {
      return [];
    }

    final list = <FileCandidate>[];
    for (final entry in fileDictionary.entries) {
      double maxSim = 0.0;
      for (final syn in entry.value) {
        final sim = WordSimilarityService.similarity(token, syn);
        if (sim > maxSim) maxSim = sim;
      }
      if (maxSim >= VoiceConfidenceConfig.squareThreshold) {
        list.add(FileCandidate(entry.key, maxSim));
      }
    }
    list.sort((a, b) => b.score.compareTo(a.score));
    return list;
  }

  static List<RankCandidate> rankedRanks(String token) {
    if (RegExp(r'^[a-h][1-8]$', caseSensitive: false).hasMatch(token)) {
      return [];
    }

    final list = <RankCandidate>[];
    for (final entry in rankDictionary.entries) {
      double maxSim = 0.0;
      for (final syn in entry.value) {
        final sim = WordSimilarityService.similarity(token, syn);
        if (sim > maxSim) maxSim = sim;
      }
      if (maxSim >= VoiceConfidenceConfig.squareThreshold) {
        list.add(RankCandidate(entry.key, maxSim));
      }
    }
    list.sort((a, b) => b.score.compareTo(a.score));
    return list;
  }

  static List<SquareCandidate> rankedSquaresFromTwoTokens(
    String fileToken,
    String rankToken,
  ) {
    final files = rankedFiles(fileToken);
    final ranks = rankedRanks(rankToken);
    final list = <SquareCandidate>[];
    for (final f in files) {
      for (final r in ranks) {
        final score = f.score < r.score ? f.score : r.score;
        list.add(SquareCandidate(square: '${f.file}${r.rank}', score: score));
      }
    }
    list.sort((a, b) => b.score.compareTo(a.score));
    return list.take(5).toList();
  }

  static List<SquareCandidate> rankedSquaresFromSingleToken(String token) {
    final list = <SquareCandidate>[];
    if (RegExp(r'^[a-h][1-8]$').hasMatch(token)) {
      list.add(SquareCandidate(square: token, score: 1.0));
      return list;
    }

    for (final fEntry in fileDictionary.entries) {
      final fLetter = fEntry.key;
      for (final fSyn in fEntry.value) {
        if (token.startsWith(fSyn)) {
          final fSim = WordSimilarityService.similarity(
            token.substring(0, fSyn.length),
            fSyn,
          );
          if (fSim < VoiceConfidenceConfig.squareThreshold) continue;
          final suffix = token.substring(fSyn.length);
          for (final rEntry in rankDictionary.entries) {
            final rDigit = rEntry.key;
            for (final rSyn in rEntry.value) {
              final rSim = WordSimilarityService.similarity(suffix, rSyn);
              if (rSim < VoiceConfidenceConfig.squareThreshold) continue;
              final combined = fSim < rSim ? fSim : rSim;
              list.add(
                SquareCandidate(square: '$fLetter$rDigit', score: combined),
              );
            }
          }
        }
      }
    }

    list.sort((a, b) => b.score.compareTo(a.score));
    final unique = <String, SquareCandidate>{};
    for (final item in list) {
      if (!unique.containsKey(item.square) ||
          unique[item.square]!.score < item.score) {
        unique[item.square] = item;
      }
    }
    final sortedUnique = unique.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return sortedUnique.take(5).toList();
  }

  static List<SquareCandidate> rankedCandidates(String input) {
    final clean = input.toLowerCase().trim();
    if (clean.isEmpty) return [];
    final tokens = clean.split(RegExp(r'\s+'));
    if (tokens.length == 2) {
      final is0Sq = RegExp(r'^[a-h][1-8]$').hasMatch(tokens[0]);
      final is1Sq = RegExp(r'^[a-h][1-8]$').hasMatch(tokens[1]);
      if (is0Sq || is1Sq) return [];
      return rankedSquaresFromTwoTokens(tokens[0], tokens[1]);
    } else if (tokens.length == 1) {
      return rankedSquaresFromSingleToken(tokens[0]);
    }
    return [];
  }

  static Map<String, dynamic>? normalizeFile(String token) {
    if (RegExp(r'^[a-h][1-8]$', caseSensitive: false).hasMatch(token)) {
      return null;
    }
    final list = rankedFiles(token);
    if (list.isEmpty) return null;
    return {'file': list.first.file, 'confidence': list.first.score};
  }

  static Map<String, dynamic>? normalizeRank(String token) {
    if (RegExp(r'^[a-h][1-8]$', caseSensitive: false).hasMatch(token)) {
      return null;
    }
    final list = rankedRanks(token);
    if (list.isEmpty) return null;
    return {'rank': list.first.rank, 'confidence': list.first.score};
  }

  static Map<String, dynamic>? normalize(String input) {
    debugPrint('SquareNormalizer INPUT: $input');
    final list = rankedCandidates(input);
    if (list.isEmpty) {
      debugPrint('SquareNormalizer OUTPUT: null');
      return null;
    }
    final best = list.first;
    final result = {'square': best.square, 'confidence': best.score};
    debugPrint('SquareNormalizer OUTPUT: $result');
    return result;
  }

  static Map<String, double> getFileScores(String token) {
    final scores = <String, double>{};
    for (final entry in fileDictionary.entries) {
      double maxSim = 0.0;
      for (final syn in entry.value) {
        final sim = WordSimilarityService.similarity(token, syn);
        if (sim > maxSim) maxSim = sim;
      }
      scores[entry.key] = maxSim;
    }
    return scores;
  }

  static Map<String, double> getRankScores(String token) {
    final scores = <String, double>{};
    for (final entry in rankDictionary.entries) {
      double maxSim = 0.0;
      for (final syn in entry.value) {
        final sim = WordSimilarityService.similarity(token, syn);
        if (sim > maxSim) maxSim = sim;
      }
      scores[entry.key] = maxSim;
    }
    return scores;
  }
}

/// Represents the extracted semantic components of a spoken chess move command.
class VoiceIntent {
  final String? piece;
  final String? originFile;
  final String? originRank;
  final String? originSquare;
  final String? destinationSquare;
  final bool isKingsideCastling;
  final bool isQueensideCastling;
  final double confidence;
  final bool isCapture;
  final bool isCheck;
  final bool isCheckmate;
  final bool isPromotion;
  final String? promotionPiece;
  final List<String> synonymsUsed;

  VoiceIntent({
    this.piece,
    this.originFile,
    this.originRank,
    this.originSquare,
    this.destinationSquare,
    this.isKingsideCastling = false,
    this.isQueensideCastling = false,
    this.confidence = 1.0,
    this.isCapture = false,
    this.isCheck = false,
    this.isCheckmate = false,
    this.isPromotion = false,
    this.promotionPiece,
    this.synonymsUsed = const [],
  });

  /// Extracts the voice intent components from the normalized text.
  static VoiceIntent parse(String text, {String? rawText}) {
    final cleanRaw = (rawText ?? text).toLowerCase().trim();
    debugPrint('VoiceIntent INPUT: text="$text", rawText="$cleanRaw"');

    final isKingside =
        cleanRaw.contains('kingside') ||
        cleanRaw.contains('short') ||
        cleanRaw == 'castle' ||
        cleanRaw.contains('short castle') ||
        cleanRaw.contains('king side') ||
        cleanRaw == 'o-o';
    final isQueenside =
        cleanRaw.contains('queenside') ||
        cleanRaw.contains('long') ||
        cleanRaw.contains('long castle') ||
        cleanRaw.contains('queen side') ||
        cleanRaw == 'o-o-o';

    final hasCapture = cleanRaw.contains('takes') ||
        cleanRaw.contains('take') ||
        cleanRaw.contains('captures') ||
        cleanRaw.contains('capture') ||
        cleanRaw.split(RegExp(r'\s+')).contains('x');

    final hasPromotion = cleanRaw.contains('promote') ||
        cleanRaw.contains('promotion') ||
        cleanRaw.contains('promoting') ||
        cleanRaw.contains('promotes');

    final hasCheckmate = cleanRaw.contains('checkmate') || cleanRaw.contains('mate');
    final hasCheck = cleanRaw.contains('check') || hasCheckmate;

    String? promotionPiece;
    if (hasPromotion) {
      for (final entry in pieceDictionary.entries) {
        if (entry.key == 'king' || entry.key == 'pawn') continue;
        for (final syn in entry.value) {
          if (cleanRaw.contains(syn)) {
            final pMap = {
              'queen': 'q',
              'rook': 'r',
              'knight': 'n',
              'bishop': 'b',
            };
            promotionPiece = pMap[entry.key];
            break;
          }
        }
        if (promotionPiece != null) break;
      }
    }

    final synonymsUsed = <String>[];
    final wordsForSyn = cleanRaw.split(RegExp(r'\s+'));
    for (final word in wordsForSyn) {
      // Piece synonym check
      for (final entry in pieceDictionary.entries) {
        for (final syn in entry.value) {
          if (word == syn && word != entry.key) {
            synonymsUsed.add('$word -> ${entry.key}');
            break;
          }
        }
      }
      // File synonym check
      for (final entry in fileDictionary.entries) {
        for (final syn in entry.value) {
          if (word == syn && word != entry.key) {
            synonymsUsed.add('$word -> ${entry.key}');
            break;
          }
        }
      }
      // Rank synonym check
      for (final entry in rankDictionary.entries) {
        for (final syn in entry.value) {
          if (word == syn && word != entry.key) {
            synonymsUsed.add('$word -> ${entry.key}');
            break;
          }
        }
      }
    }

    if (isKingside || isQueenside) {
      final intent = VoiceIntent(
        piece: 'k',
        isKingsideCastling: isKingside,
        isQueensideCastling: isQueenside,
        confidence: 1.0,
        isCapture: hasCapture,
        isCheck: hasCheck,
        isCheckmate: hasCheckmate,
        isPromotion: hasPromotion,
        promotionPiece: promotionPiece,
        synonymsUsed: synonymsUsed.toSet().toList(),
      );
      debugPrint(
        'VoiceIntent OUTPUT: piece=${intent.piece}, destinationSquare=${intent.destinationSquare}, isKingside=${intent.isKingsideCastling}, isQueenside=${intent.isQueensideCastling}, confidence=${intent.confidence}',
      );
      return intent;
    }

    final words = text.split(RegExp(r'\s+'));
    final List<Map<String, dynamic>> detectedSquares = [];
    int i = 0;
    while (i < words.length) {
      if (i + 1 < words.length) {
        final is0Sq = RegExp(r'^[a-h][1-8]$').hasMatch(words[i]);
        final is1Sq = RegExp(r'^[a-h][1-8]$').hasMatch(words[i + 1]);
        if (!is0Sq && !is1Sq) {
          final candidate = '${words[i]} ${words[i + 1]}';
          final norm = SquareNormalizer.normalize(candidate);
          if (norm != null) {
            detectedSquares.add(norm);
            i += 2;
            continue;
          }
        }
      }
      final norm = SquareNormalizer.normalize(words[i]);
      if (norm != null) {
        detectedSquares.add(norm);
      }
      i++;
    }

    String? pieceChar;
    double pieceConf = 1.0;
    for (final w in words) {
      final p = PieceNormalizer.normalize(w);
      if (p != null) {
        pieceChar = p['piece'] as String;
        pieceConf = p['confidence'] as double;
        break;
      }
    }

    int firstSqWordIndex = -1;
    for (int idx = 0; idx < words.length; idx++) {
      if (idx + 1 < words.length &&
          SquareNormalizer.normalize('${words[idx]} ${words[idx + 1]}') !=
              null) {
        firstSqWordIndex = idx;
        break;
      }
      if (SquareNormalizer.normalize(words[idx]) != null) {
        firstSqWordIndex = idx;
        break;
      }
    }

    bool hasPieceBeforeFirstSq = false;
    if (firstSqWordIndex != -1) {
      for (int idx = 0; idx < firstSqWordIndex; idx++) {
        if (PieceNormalizer.normalize(words[idx]) != null) {
          hasPieceBeforeFirstSq = true;
          break;
        }
      }
    }

    VoiceIntent intent;
    if (detectedSquares.length == 2) {
      if (pieceChar != null && hasPieceBeforeFirstSq) {
        final targetSq = detectedSquares[1]['square'] as String;
        final targetConf = detectedSquares[1]['confidence'] as double;

        String? originFile;
        String? originRank;
        String? originSquare;
        double originConf = 1.0;

        final excludedKeywords = {'to', 'takes', 'on', 'at', 'for'};
        final remainingWords = <String>[];
        int targetStartIndex = -1;
        int targetEndIndex = -1;
        for (int idx = words.length - 1; idx >= 0; idx--) {
          if (idx - 1 >= 0 &&
              SquareNormalizer.normalize(
                    '${words[idx - 1]} ${words[idx]}',
                  )?['square'] ==
                  targetSq) {
            targetStartIndex = idx - 1;
            targetEndIndex = idx;
            break;
          }
          if (SquareNormalizer.normalize(words[idx])?['square'] == targetSq) {
            targetStartIndex = idx;
            targetEndIndex = idx;
            break;
          }
        }

        for (int idx = 0; idx < words.length; idx++) {
          if (idx >= targetStartIndex && idx <= targetEndIndex) {
            continue;
          }
          final w = words[idx];
          if (PieceNormalizer.normalize(w) != null) {
            continue;
          }
          if (excludedKeywords.contains(w)) {
            continue;
          }
          remainingWords.add(w);
        }

        for (final w in remainingWords) {
          final fNorm = SquareNormalizer.normalizeFile(w);
          final rNorm = SquareNormalizer.normalizeRank(w);

          if (RegExp(r'^[a-h][1-8]$', caseSensitive: false).hasMatch(w)) {
            originSquare = w;
            originFile = w[0];
            originRank = w[1];
            originConf = 1.0;
          } else if (fNorm != null) {
            originFile = fNorm['file'] as String;
            originConf = fNorm['confidence'] as double;
          } else if (rNorm != null) {
            originRank = rNorm['rank'] as String;
            originConf = rNorm['confidence'] as double;
          } else if (RegExp(r'^[a-h]$', caseSensitive: false).hasMatch(w)) {
            originFile = w;
          } else if (RegExp(r'^[1-8]$', caseSensitive: false).hasMatch(w)) {
            originRank = w;
          } else {
            final normSq = SquareNormalizer.normalize(w);
            if (normSq != null) {
              originSquare = normSq['square'] as String;
              originFile = originSquare[0];
              originRank = originSquare[1];
              originConf = normSq['confidence'] as double;
            }
          }
        }

        final confidence = [
          pieceConf,
          targetConf,
          originConf,
        ].reduce((curr, next) => curr < next ? curr : next);
        intent = VoiceIntent(
          piece: pieceChar,
          originFile: originFile,
          originRank: originRank,
          originSquare: originSquare,
          destinationSquare: targetSq,
          confidence: confidence,
          isCapture: hasCapture,
          isCheck: hasCheck,
          isCheckmate: hasCheckmate,
          isPromotion: hasPromotion,
          promotionPiece: promotionPiece,
          synonymsUsed: synonymsUsed.toSet().toList(),
        );
      } else {
        final origin = detectedSquares[0]['square'] as String;
        final dest = detectedSquares[1]['square'] as String;
        final oConf = detectedSquares[0]['confidence'] as double;
        final dConf = detectedSquares[1]['confidence'] as double;
        final confidence = oConf < dConf ? oConf : dConf;

        intent = VoiceIntent(
          originSquare: origin,
          originFile: origin[0],
          originRank: origin[1],
          destinationSquare: dest,
          confidence: confidence,
          isCapture: hasCapture,
          isCheck: hasCheck,
          isCheckmate: hasCheckmate,
          isPromotion: hasPromotion,
          promotionPiece: promotionPiece,
          synonymsUsed: synonymsUsed.toSet().toList(),
        );
      }
    } else if (detectedSquares.length == 1) {
      final targetSq = detectedSquares[0]['square'] as String;
      final targetConf = detectedSquares[0]['confidence'] as double;

      String? originFile;
      String? originRank;
      String? originSquare;
      double originConf = 1.0;

      final excludedKeywords = {'to', 'takes', 'on', 'at', 'for'};
      final remainingWords = <String>[];
      int targetStartIndex = -1;
      int targetEndIndex = -1;
      for (int idx = words.length - 1; idx >= 0; idx--) {
        if (idx - 1 >= 0 &&
            SquareNormalizer.normalize(
                  '${words[idx - 1]} ${words[idx]}',
                )?['square'] ==
                targetSq) {
          targetStartIndex = idx - 1;
          targetEndIndex = idx;
          break;
        }
        if (SquareNormalizer.normalize(words[idx])?['square'] == targetSq) {
          targetStartIndex = idx;
          targetEndIndex = idx;
          break;
        }
      }

      for (int idx = 0; idx < words.length; idx++) {
        if (idx >= targetStartIndex && idx <= targetEndIndex) {
          continue;
        }
        final w = words[idx];
        if (PieceNormalizer.normalize(w) != null) {
          continue;
        }
        if (excludedKeywords.contains(w)) {
          continue;
        }
        remainingWords.add(w);
      }

      for (final w in remainingWords) {
        final fNorm = SquareNormalizer.normalizeFile(w);
        final rNorm = SquareNormalizer.normalizeRank(w);

        if (RegExp(r'^[a-h][1-8]$', caseSensitive: false).hasMatch(w)) {
          originSquare = w;
          originFile = w[0];
          originRank = w[1];
          originConf = 1.0;
        } else if (fNorm != null) {
          originFile = fNorm['file'] as String;
          originConf = fNorm['confidence'] as double;
        } else if (rNorm != null) {
          originRank = rNorm['rank'] as String;
          originConf = rNorm['confidence'] as double;
        } else if (RegExp(r'^[a-h]$', caseSensitive: false).hasMatch(w)) {
          originFile = w;
        } else if (RegExp(r'^[1-8]$', caseSensitive: false).hasMatch(w)) {
          originRank = w;
        } else {
          final normSq = SquareNormalizer.normalize(w);
          if (normSq != null) {
            originSquare = normSq['square'] as String;
            originFile = originSquare[0];
            originRank = originSquare[1];
            originConf = normSq['confidence'] as double;
          }
        }
      }

      final confidence = [
        pieceConf,
        targetConf,
        originConf,
      ].reduce((curr, next) => curr < next ? curr : next);
      intent = VoiceIntent(
        piece: pieceChar,
        originFile: originFile,
        originRank: originRank,
        originSquare: originSquare,
        destinationSquare: targetSq,
        confidence: confidence,
        isCapture: hasCapture,
        isCheck: hasCheck,
        isCheckmate: hasCheckmate,
        isPromotion: hasPromotion,
        promotionPiece: promotionPiece,
        synonymsUsed: synonymsUsed.toSet().toList(),
      );
    } else {
      if (pieceChar != null) {
        intent = VoiceIntent(
          piece: pieceChar,
          confidence: pieceConf,
          isCapture: hasCapture,
          isCheck: hasCheck,
          isCheckmate: hasCheckmate,
          isPromotion: hasPromotion,
          promotionPiece: promotionPiece,
          synonymsUsed: synonymsUsed.toSet().toList(),
        );
      } else {
        intent = VoiceIntent(
          confidence: 0.0,
          isCapture: hasCapture,
          isCheck: hasCheck,
          isCheckmate: hasCheckmate,
          isPromotion: hasPromotion,
          promotionPiece: promotionPiece,
          synonymsUsed: synonymsUsed.toSet().toList(),
        );
      }
    }

    debugPrint(
      'VoiceIntent OUTPUT: piece=${intent.piece}, destinationSquare=${intent.destinationSquare}, originSquare=${intent.originSquare}, confidence=${intent.confidence}',
    );
    return intent;
  }
}

/// Matches the VoiceIntent against the currently available legal moves.
class CandidateInterpretation {
  final String? piece;
  final String? destinationSquare;
  final String? originFile;
  final String? originRank;
  final String? originSquare;
  final String? promotion;
  final bool isKingsideCastling;
  final bool isQueensideCastling;
  final double similarityScore;
  final double score;

  CandidateInterpretation({
    this.piece,
    this.destinationSquare,
    this.originFile,
    this.originRank,
    this.originSquare,
    this.promotion,
    this.isKingsideCastling = false,
    this.isQueensideCastling = false,
    required this.similarityScore,
    required this.score,
  });

  @override
  String toString() {
    if (isKingsideCastling) return 'Kingside Castle';
    if (isQueensideCastling) return 'Queenside Castle';
    final sb = StringBuffer();
    final pMap = {
      'n': 'Knight',
      'r': 'Rook',
      'q': 'Queen',
      'b': 'Bishop',
      'k': 'King',
      'p': 'Pawn',
    };
    final pieceName = pMap[piece] ?? 'Pawn';
    sb.write('$pieceName to $destinationSquare');
    if (originSquare != null) {
      sb.write(' (from $originSquare)');
    } else if (originFile != null || originRank != null) {
      sb.write(' (from ');
      if (originFile != null) {
        sb.write('file $originFile');
      }
      if (originRank != null) {
        sb.write('${originFile != null ? " " : ""}rank $originRank');
      }
      sb.write(')');
    }
    if (promotion != null) {
      sb.write(' promotion $promotion');
    }
    return sb.toString();
  }
}

class LegalMoveMatcher {
  static List<Map<String, dynamic>> lastRatedMoves = [];
  static double lastConfidenceGap = 0.0;
  static double lastMinAbsoluteConfidence = 0.70;
  static double lastMinConfidenceGap = 0.10;
  static List<CandidateInterpretation> generateCandidateInterpretations(
    String normalizedText,
    double sttConfidence, {
    VoiceIntent? intent,
    bool limitToTop5 = true,
  }) {
    final List<CandidateInterpretation> candidates = [];
    final cleanText = normalizedText.toLowerCase().trim();

    final isKingside =
        cleanText.contains('kingside') ||
        cleanText.contains('short') ||
        cleanText == 'castle' ||
        cleanText.contains('short castle');
    final isQueenside =
        cleanText.contains('queenside') ||
        cleanText.contains('long') ||
        cleanText.contains('long castle');

    if (isKingside || isQueenside) {
      final intentConf = intent?.confidence ?? 1.0;
      candidates.add(
        CandidateInterpretation(
          piece: 'k',
          isKingsideCastling: isKingside,
          isQueensideCastling: isQueenside,
          similarityScore: intentConf,
          score:
              (intentConf * VoiceConfidenceConfig.weightSimilarity) +
              (sttConfidence * VoiceConfidenceConfig.weightSttConfidence) +
              VoiceConfidenceConfig.weightBoardContext,
        ),
      );
      return candidates;
    }

    final words = cleanText.split(RegExp(r'\s+'));
    final List<SquareCandidate> squareOptions = [];
    for (int i = 0; i < words.length; i++) {
      final single = SquareNormalizer.rankedCandidates(words[i]);
      for (final sc in single) {
        if (!squareOptions.any((opt) => opt.square == sc.square)) {
          squareOptions.add(sc);
        }
      }
      if (i + 1 < words.length) {
        final pair = SquareNormalizer.rankedCandidates(
          '${words[i]} ${words[i + 1]}',
        );
        for (final sc in pair) {
          if (!squareOptions.any((opt) => opt.square == sc.square)) {
            squareOptions.add(sc);
          }
        }
      }
    }

    if (squareOptions.isEmpty) {
      for (final w in words) {
        if (RegExp(r'^[a-h][1-8]$').hasMatch(w)) {
          squareOptions.add(SquareCandidate(square: w, score: 1.0));
        }
      }
    }

    // 2. Get piece candidates
    final List<Map<String, dynamic>> pieceOptions = [];
    double maxPieceScore = 0.0;

    final pMap = {
      'knight': 'n',
      'rook': 'r',
      'queen': 'q',
      'bishop': 'b',
      'king': 'k',
    };
    for (final entry in pMap.entries) {
      final pName = entry.key;
      final pChar = entry.value;
      double maxSim = 0.0;
      for (final synonym in pieceDictionary[pName]!) {
        for (final w in words) {
          final sim = WordSimilarityService.similarity(w, synonym);
          if (sim > maxSim) maxSim = sim;
        }
      }
      if (maxSim > maxPieceScore) maxPieceScore = maxSim;
      pieceOptions.add({'piece': pChar, 'score': maxSim, 'name': pName});
    }

    // Add pawn option (piece-agnostic / default pawn)
    double pawnDictScore = 0.0;
    for (final synonym in pieceDictionary['pawn']!) {
      for (final w in words) {
        final sim = WordSimilarityService.similarity(w, synonym);
        if (sim > pawnDictScore) pawnDictScore = sim;
      }
    }
    final defaultPawnScore = (1.0 - maxPieceScore).clamp(0.0, 1.0);
    final finalPawnScore = pawnDictScore > defaultPawnScore
        ? pawnDictScore
        : defaultPawnScore;

    pieceOptions.add({'piece': null, 'score': finalPawnScore, 'name': 'pawn'});

    // 3. Generate combinations
    for (final pOpt in pieceOptions) {
      final pChar = pOpt['piece'] as String?;
      var pScore = pOpt['score'] as double;

      for (final sOpt in squareOptions) {
        final destSq = sOpt.square;
        final sScore = sOpt.score;

        // Resolve destIdx of destSq in words
        int destIdx = -1;
        for (int idx = words.length - 1; idx >= 0; idx--) {
          if (idx - 1 >= 0 &&
              SquareNormalizer.normalize(
                    '${words[idx - 1]} ${words[idx]}',
                  )?['square'] ==
                  destSq) {
            destIdx = idx;
            break;
          }
          if (SquareNormalizer.normalize(words[idx])?['square'] == destSq) {
            destIdx = idx;
            break;
          }
        }

        // Promotion check: only if destSq is on rank 8 or 1 and promotion word occurs after destSq
        String? promotion;
        final isPromotionRank = destSq.endsWith('8') || destSq.endsWith('1');
        if (isPromotionRank && destIdx != -1 && destIdx < words.length - 1) {
          final postWords = words.sublist(destIdx + 1);
          final postStr = postWords.join(' ');
          if (postStr.contains('queen')) {
            promotion = 'q';
          } else if (postStr.contains('rook')) {
            promotion = 'r';
          } else if (postStr.contains('bishop')) {
            promotion = 'b';
          } else if (postStr.contains('knight')) {
            promotion = 'n';
          }
        }

        if (promotion != null) {
          if (pChar != null) {
            continue; // Non-pawns cannot promote
          }
          pScore = 1.0; // Pawn matches perfectly as the promoting piece
        }

        // Resolve origin details for this destination choice
        String? originFile;
        String? originRank;
        String? originSquare;
        double originConf = 1.0;

        int targetStartIndex = -1;
        int targetEndIndex = -1;
        for (int idx = words.length - 1; idx >= 0; idx--) {
          if (idx - 1 >= 0 &&
              SquareNormalizer.normalize(
                    '${words[idx - 1]} ${words[idx]}',
                  )?['square'] ==
                  destSq) {
            targetStartIndex = idx - 1;
            targetEndIndex = idx;
            break;
          }
          if (SquareNormalizer.normalize(words[idx])?['square'] == destSq) {
            targetStartIndex = idx;
            targetEndIndex = idx;
            break;
          }
        }

        final excludedKeywords = {'to', 'takes', 'on', 'at', 'for'};
        final remainingWords = <String>[];
        for (int idx = 0; idx < words.length; idx++) {
          if (idx >= targetStartIndex && idx <= targetEndIndex) {
            continue;
          }
          final w = words[idx];
          if (PieceNormalizer.normalize(w) != null) {
            continue;
          }
          if (excludedKeywords.contains(w)) {
            continue;
          }
          remainingWords.add(w);
        }

        for (final w in remainingWords) {
          final fNorm = SquareNormalizer.normalizeFile(w);
          final rNorm = SquareNormalizer.normalizeRank(w);

          if (RegExp(r'^[a-h][1-8]$', caseSensitive: false).hasMatch(w)) {
            originSquare = w;
            originFile = w[0];
            originRank = w[1];
            originConf = 1.0;
          } else if (fNorm != null) {
            originFile = fNorm['file'] as String;
            originConf = fNorm['confidence'] as double;
          } else if (rNorm != null) {
            originRank = rNorm['rank'] as String;
            originConf = rNorm['confidence'] as double;
          } else if (RegExp(r'^[a-h]$', caseSensitive: false).hasMatch(w)) {
            originFile = w;
          } else if (RegExp(r'^[1-8]$', caseSensitive: false).hasMatch(w)) {
            originRank = w;
          } else {
            final normSq = SquareNormalizer.normalize(w);
            if (normSq != null) {
              originSquare = normSq['square'] as String;
              originFile = originSquare[0];
              originRank = originSquare[1];
              originConf = normSq['confidence'] as double;
            }
          }
        }

        final intentConf = intent?.confidence ?? 1.0;
        final similarityScore = [
          pScore,
          sScore,
          originConf,
          intentConf,
        ].reduce((a, b) => a < b ? a : b);
        final score =
            (similarityScore * VoiceConfidenceConfig.weightSimilarity) +
            (sttConfidence * VoiceConfidenceConfig.weightSttConfidence) +
            VoiceConfidenceConfig.weightBoardContext;

        candidates.add(
          CandidateInterpretation(
            piece: pChar,
            destinationSquare: destSq,
            originFile: originFile,
            originRank: originRank,
            originSquare: originSquare,
            promotion: promotion,
            similarityScore: similarityScore,
            score: score,
          ),
        );
      }
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    return limitToTop5 ? candidates.take(5).toList() : candidates;
  }

  static bool matchesMove(Map<String, dynamic> m, CandidateInterpretation c) {
    if (c.isKingsideCastling) {
      final san = m['san'] as String? ?? '';
      return san.startsWith('O-O') && !san.startsWith('O-O-O');
    }
    if (c.isQueensideCastling) {
      final san = m['san'] as String? ?? '';
      return san.startsWith('O-O-O');
    }

    if (c.piece != null && m['piece'] != c.piece) {
      return false;
    }

    if (m['to'] != c.destinationSquare) {
      return false;
    }

    if (c.originSquare != null && m['from'] != c.originSquare) {
      return false;
    }
    if (c.originFile != null &&
        !(m['from'] as String).startsWith(c.originFile!)) {
      return false;
    }
    if (c.originRank != null &&
        !(m['from'] as String).endsWith(c.originRank!)) {
      return false;
    }

    if (c.promotion != null && m['promotion'] != c.promotion) {
      return false;
    }

    return true;
  }

  static String formatMove(
    Map<String, dynamic> move,
    CandidateInterpretation? candidate,
  ) {
    final pMap = {
      'n': 'knight',
      'r': 'rook',
      'q': 'queen',
      'b': 'bishop',
      'k': 'king',
      'p': 'pawn',
    };
    final pieceName = pMap[move['piece']] ?? 'pawn';
    if (pieceName == 'pawn') {
      return move['to'];
    }
    if (candidate != null) {
      if (candidate.originSquare != null) {
        return '$pieceName ${move['from']} ${move['to']}';
      } else if (candidate.originFile != null) {
        return '$pieceName ${move['from'][0]} ${move['to']}';
      } else if (candidate.originRank != null) {
        return '$pieceName ${move['from'][1]} ${move['to']}';
      }
    }
    return '$pieceName ${move['to']}';
  }

  static List<String> getSpokenEquivalents(Map<String, dynamic> move) {
    final String san = move['san'] as String? ?? '';
    if (san.isEmpty) return [];

    final List<String> equivalents = [];

    // Castling
    if (san.startsWith('O-O-O')) {
      return [
        'castle queenside',
        'queenside castling',
        'long castle',
        'long castling',
        'castle long',
      ];
    } else if (san.startsWith('O-O')) {
      return [
        'castle kingside',
        'kingside castling',
        'short castle',
        'short castling',
        'castle short',
        'castle',
      ];
    }

    // Normalize SAN
    // Strip check and mate symbols
    var cleanSan = san.replaceAll(RegExp(r'[+#]'), '');

    // Extract promotion
    String? promotionPiece;
    final promoIndex = cleanSan.indexOf('=');
    if (promoIndex != -1) {
      promotionPiece = cleanSan.substring(promoIndex + 1).toLowerCase();
      cleanSan = cleanSan.substring(0, promoIndex);
    } else if (cleanSan.length > 2 && RegExp(r'[QRBN]$').hasMatch(cleanSan)) {
      promotionPiece = cleanSan[cleanSan.length - 1].toLowerCase();
      cleanSan = cleanSan.substring(0, cleanSan.length - 1);
    }

    // Extract piece
    String pieceName = 'pawn';
    String? pChar = move['piece'] as String?;
    final pMap = {
      'n': 'knight',
      'r': 'rook',
      'q': 'queen',
      'b': 'bishop',
      'k': 'king',
      'p': 'pawn',
    };

    if (cleanSan.isNotEmpty && RegExp(r'^[KQRBN]').hasMatch(cleanSan)) {
      final pLetter = cleanSan[0];
      cleanSan = cleanSan.substring(1);
      final pCharFromSan = pLetter.toLowerCase();
      pChar = pCharFromSan == 'n' ? 'n' : pCharFromSan;
      pieceName = pMap[pChar] ?? 'pawn';
    } else {
      pieceName = 'pawn';
      pChar = 'p';
    }

    // Extract capture
    final isCapture = cleanSan.contains('x');
    cleanSan = cleanSan.replaceAll('x', '');

    // Parse remaining string into orig and dest
    String? orig;
    String dest = '';
    if (cleanSan.length == 2) {
      dest = cleanSan;
    } else if (cleanSan.length == 3) {
      orig = cleanSan[0];
      dest = cleanSan.substring(1);
    } else if (cleanSan.length == 4) {
      orig = cleanSan.substring(0, 2);
      dest = cleanSan.substring(2);
    } else {
      dest = cleanSan;
    }

    // Map numbers to word names for rank/files
    final numNames = {
      '1': 'one',
      '2': 'two',
      '3': 'three',
      '4': 'four',
      '5': 'five',
      '6': 'six',
      '7': 'seven',
      '8': 'eight',
    };

    final destFile = dest.isNotEmpty ? dest[0] : '';
    final destRank = dest.length > 1 ? dest[1] : '';
    final destRankName = numNames[destRank] ?? destRank;

    final origFile = (orig != null && orig.isNotEmpty) ? orig[0] : '';
    final origRank = (orig != null && orig.length > 1) ? orig[1] : '';
    final origRankName = numNames[origRank] ?? origRank;

    // Generate combinations
    final piecePrefixes = pieceName == 'pawn' ? ['pawn', ''] : [pieceName];

    final destSuffixes = ['$destFile$destRank', '$destFile $destRankName'];

    final origStrings = <String>[];
    if (orig == null || orig.isEmpty) {
      origStrings.add('');
    } else {
      if (orig.length == 1) {
        origStrings.add(orig);
        final word = numNames[orig] ?? orig;
        if (word != orig) origStrings.add(word);
      } else {
        origStrings.add(orig);
        origStrings.add('$origFile $origRankName');
      }
    }

    final actions = <String>[];
    if (isCapture) {
      actions.addAll(['takes', 'takes on', 'captures', 'to', '']);
    } else {
      actions.addAll(['to', '']);
    }

    final promoSuffixes = <String>[];
    if (promotionPiece != null) {
      final promoName = pMap[promotionPiece] ?? 'queen';
      promoSuffixes.add('promote to $promoName');
      promoSuffixes.add('promote $promoName');
      promoSuffixes.add('equals $promoName');
      promoSuffixes.add(promoName);
    } else {
      promoSuffixes.add('');
    }

    for (final prefix in piecePrefixes) {
      for (final origStr in origStrings) {
        for (final act in actions) {
          for (final destStr in destSuffixes) {
            for (final promo in promoSuffixes) {
              final parts = <String>[];
              if (prefix.isNotEmpty) parts.add(prefix);
              if (origStr.isNotEmpty) parts.add(origStr);
              if (act.isNotEmpty) parts.add(act);
              parts.add(destStr);
              if (promo.isNotEmpty) parts.add(promo);

              equivalents.add(parts.join(' '));
            }
          }
        }
      }
    }

    return equivalents.toSet().toList();
  }

  static double getIntentSimilarity(
    Map<String, dynamic> m,
    VoiceIntent intent,
    String cleanText,
  ) {
    if (intent.isKingsideCastling) {
      final san = m['san'] as String? ?? '';
      if (san.startsWith('O-O') && !san.startsWith('O-O-O')) {
        return intent.confidence;
      }
      return 0.0;
    }
    if (intent.isQueensideCastling) {
      final san = m['san'] as String? ?? '';
      if (san.startsWith('O-O-O')) {
        return intent.confidence;
      }
      return 0.0;
    }

    if (intent.destinationSquare == null) return 0.0;

    final intentPiece = intent.piece ?? 'p';
    final movePiece = m['piece'] as String? ?? 'p';
    if (intentPiece != movePiece) {
      return 0.0;
    }

    if (m['to'] != intent.destinationSquare) {
      return 0.0;
    }

    // Promotion check
    if (m['promotion'] != null) {
      final hasQueen = cleanText.contains('queen');
      final hasRook = cleanText.contains('rook');
      final hasBishop = cleanText.contains('bishop');
      final hasKnight = cleanText.contains('knight');

      if (hasQueen || hasRook || hasBishop || hasKnight) {
        final pChar = m['promotion'] as String;
        if (pChar == 'q' && !hasQueen) return 0.0;
        if (pChar == 'r' && !hasRook) return 0.0;
        if (pChar == 'b' && !hasBishop) return 0.0;
        if (pChar == 'n' && !hasKnight) return 0.0;
      }
    }

    // Origin constraints check
    bool originMatched = true;
    if (intent.originSquare != null && m['from'] != intent.originSquare) {
      originMatched = false;
    }
    if (intent.originFile != null &&
        !(m['from'] as String).startsWith(intent.originFile!)) {
      originMatched = false;
    }
    if (intent.originRank != null &&
        !(m['from'] as String).endsWith(intent.originRank!)) {
      originMatched = false;
    }

    return originMatched ? intent.confidence : intent.confidence * 0.70;
  }

  static Map<String, dynamic>? match(
    VoiceIntent intent,
    List<Map<String, dynamic>> legalMoves, {
    String normalizedText = '',
    double sttConfidence = 1.0,
  }) {
    debugPrint(
      'LegalMoveMatcher INPUT: intent, moves.length=${legalMoves.length}',
    );

    // Reset debug metrics
    lastRatedMoves = [];
    lastConfidenceGap = 0.0;
    lastMinAbsoluteConfidence = VoiceConfidenceConfig.minAbsoluteConfidence;
    lastMinConfidenceGap = VoiceConfidenceConfig.minConfidenceGap;

    // 1. Missing destination square check
    if (intent.destinationSquare == null &&
        !intent.isKingsideCastling &&
        !intent.isQueensideCastling) {
      if (intent.piece != null) {
        final err = {'error': "I couldn't recognize the destination square."};
        debugPrint('LegalMoveMatcher OUTPUT: $err');
        return err;
      }
      debugPrint('LegalMoveMatcher OUTPUT: null');
      return null;
    }

    var cleanText = normalizedText.toLowerCase().trim();
    if (cleanText.isEmpty) {
      if (intent.isKingsideCastling) {
        cleanText = 'castle kingside';
      } else if (intent.isQueensideCastling) {
        cleanText = 'castle queenside';
      } else {
        final sb = StringBuffer();
        if (intent.piece != null) {
          final pMap = {
            'n': 'knight',
            'r': 'rook',
            'q': 'queen',
            'b': 'bishop',
            'k': 'king',
            'p': 'pawn',
          };
          sb.write(pMap[intent.piece] ?? 'pawn');
          sb.write(' ');
        }
        if (intent.originSquare != null) {
          sb.write(intent.originSquare);
          sb.write(' ');
        } else {
          if (intent.originFile != null) {
            sb.write(intent.originFile);
            sb.write(' ');
          }
          if (intent.originRank != null) {
            sb.write(intent.originRank);
            sb.write(' ');
          }
        }
        if (intent.destinationSquare != null) {
          sb.write('to ');
          sb.write(intent.destinationSquare);
        }
        cleanText = sb.toString().trim();
      }
    }
    if (cleanText.isEmpty) return null;

    // 2. Check if a piece was spoken but not recognized
    final words = cleanText.split(RegExp(r'\s+'));
    if (intent.piece == null && intent.destinationSquare != null) {
      final targetSq = intent.destinationSquare!;
      int targetIdx = words.indexOf(targetSq);
      if (targetIdx > 0) {
        final prefixWords = words.sublist(0, targetIdx);
        final connectors = {'to', 'takes', 'on', 'at', 'for'};
        final hasPotentialPieceWord = prefixWords.any((w) {
          if (connectors.contains(w)) return false;
          if (SquareNormalizer.normalize(w) != null) return false;
          if (SquareNormalizer.normalizeFile(w) != null) return false;
          if (SquareNormalizer.normalizeRank(w) != null) return false;
          return true;
        });
        if (hasPotentialPieceWord) {
          final err = {'error': "I couldn't recognize the piece."};
          debugPrint('LegalMoveMatcher OUTPUT: $err');
          return err;
        }
      }
    }

    final speechCandidates = generateCandidateInterpretations(
      cleanText,
      sttConfidence,
      intent: intent,
      limitToTop5: false,
    );

    if (speechCandidates.isEmpty) {
      final err = {'error': "I couldn't understand that move."};
      debugPrint('LegalMoveMatcher OUTPUT: $err');
      return err;
    }

    final topCandidate = speechCandidates.first;
    final targetSq = topCandidate.destinationSquare;

    // Calculate board plausibility counts
    final samePieceSameTargetCounts = <String, Map<String, int>>{};
    for (final m in legalMoves) {
      final p = m['piece'] as String;
      final dest = m['to'] as String;
      samePieceSameTargetCounts.putIfAbsent(dest, () => {})[p] =
          (samePieceSameTargetCounts[dest]![p] ?? 0) + 1;
    }

    // Score every legal move
    final List<Map<String, dynamic>> ratedMoves = [];
    for (final m in legalMoves) {
      CandidateInterpretation? bestCandidate;
      for (final c in speechCandidates) {
        if (matchesMove(m, c)) {
          if (bestCandidate == null || c.score > bestCandidate.score) {
            bestCandidate = c;
          }
        }
      }

      double spokenSimScore = bestCandidate?.similarityScore ?? 0.0;
      double intentSimScore = getIntentSimilarity(m, intent, cleanText);

      // Task 2: Direct similarity against spoken equivalents
      double maxSpokenSim = 0.0;
      if (normalizedText.isNotEmpty) {
        bool isCorrectDest = false;
        if (intent.isKingsideCastling) {
          final san = m['san'] as String? ?? '';
          isCorrectDest = san.startsWith('O-O') && !san.startsWith('O-O-O');
        } else if (intent.isQueensideCastling) {
          final san = m['san'] as String? ?? '';
          isCorrectDest = san.startsWith('O-O-O');
        } else if (intent.destinationSquare != null) {
          isCorrectDest = m['to'] == intent.destinationSquare;
        }

        if (isCorrectDest) {
          final equivalents = getSpokenEquivalents(m);
          for (final eq in equivalents) {
            final sim = WordSimilarityService.similarity(cleanText, eq);
            if (sim > maxSpokenSim) {
              maxSpokenSim = sim;
            }
          }
          // Scale by sttConfidence to reflect STT recognition uncertainty
          maxSpokenSim = maxSpokenSim * sttConfidence;
        }
      }

      // Print comparisons for Task 1 diagnostic logging
      debugPrint(
        '[Task 1 Diagnostic] Move ${m['san']}: equivalents=${getSpokenEquivalents(m)}, maxSpokenSim=$maxSpokenSim, spokenSimScore=$spokenSimScore, intentSimScore=$intentSimScore',
      );

      // Max-pool the similarity scores
      double similarityScore = maxSpokenSim;
      if (spokenSimScore > similarityScore) similarityScore = spokenSimScore;
      if (intentSimScore > similarityScore) similarityScore = intentSimScore;

      // If matched via intent and bestCandidate is null, construct a fallback candidate from the intent
      if (bestCandidate == null && intentSimScore > 0.0) {
        bestCandidate = CandidateInterpretation(
          piece: intent.piece,
          destinationSquare: intent.destinationSquare,
          originFile: intent.originFile,
          originRank: intent.originRank,
          originSquare: intent.originSquare,
          isKingsideCastling: intent.isKingsideCastling,
          isQueensideCastling: intent.isQueensideCastling,
          similarityScore: intentSimScore,
          score:
              (intentSimScore * VoiceConfidenceConfig.weightSimilarity) +
              (sttConfidence * VoiceConfidenceConfig.weightSttConfidence) +
              VoiceConfidenceConfig.weightBoardContext,
        );
      }

      final String dest = m['to'] as String;
      final String p = m['piece'] as String;
      final count = samePieceSameTargetCounts[dest]?[p] ?? 1;
      final double plausibility = 1.0 / count;

      final double score = similarityScore == 0.0
          ? 0.0
          : (similarityScore * VoiceConfidenceConfig.weightSimilarity) +
                (sttConfidence * VoiceConfidenceConfig.weightSttConfidence) +
                (plausibility * VoiceConfidenceConfig.weightBoardContext);

      ratedMoves.add({
        'move': m,
        'score': score,
        'similarityScore': similarityScore,
        'plausibility': plausibility,
        'candidate': bestCandidate,
      });
    }

    ratedMoves.sort(
      (a, b) => (b['score'] as double).compareTo(a['score'] as double),
    );
    lastRatedMoves = ratedMoves;

    // Handle complete lack of legal moves
    if (ratedMoves.isEmpty || (ratedMoves.first['score'] as double) == 0.0) {
      final err = {'error': "That move isn't legal."};
      debugPrint('LegalMoveMatcher OUTPUT: $err');
      return err;
    }

    final topMove = ratedMoves.first;
    final topMoveMap = topMove['move'] as Map<String, dynamic>;
    final topScore = topMove['score'] as double;
    final bestCandidateForTopMove =
        topMove['candidate'] as CandidateInterpretation?;

    // Task 3: Recognition Noise Bypass / Piece-Mismatch Clarification
    if (intent.piece != null && targetSq != null) {
      final hasSpokenPieceLegalMove = legalMoves.any(
        (m) => m['piece'] == intent.piece && m['to'] == targetSq,
      );
      if (!hasSpokenPieceLegalMove) {
        // Spoken piece type cannot legally reach targetSq
        // Only trigger did you mean if a different piece is the top-ranked legal move
        if (topMoveMap['piece'] != intent.piece &&
            topMoveMap['to'] == targetSq) {
          final pMap = {
            'n': 'knight',
            'r': 'rook',
            'q': 'queen',
            'b': 'bishop',
            'k': 'king',
            'p': 'pawn',
          };
          final spokenPieceName = pMap[intent.piece] ?? 'pawn';
          final altPieceName = pMap[topMoveMap['piece']] ?? 'pawn';
          final errorMsg =
              "I heard '$spokenPieceName' but that can't reach $targetSq. Did you mean $altPieceName to $targetSq?";
          final err = {'error': errorMsg, 'clarificationMove': topMoveMap};
          lastConfidenceGap = 0.0;
          debugPrint('LegalMoveMatcher OUTPUT: $err');
          return err;
        }
      }
    }

    final secondMove = ratedMoves.length > 1 ? ratedMoves[1] : null;
    final secondScore = secondMove != null
        ? secondMove['score'] as double
        : 0.0;
    final double confidenceGap = ratedMoves.length > 1
        ? (topScore - secondScore)
        : topScore;
    lastConfidenceGap = confidenceGap;

    // Task 2: Confidence Gap Decision
    final autoExecute =
        ((topScore >= VoiceConfidenceConfig.minAbsoluteConfidence) &&
        (confidenceGap >= VoiceConfidenceConfig.minConfidenceGap)) ||
        ((topMove['similarityScore'] as double) == 1.0 &&
         topScore >= 0.60 &&
         (ratedMoves.length == 1 || (topScore - secondScore) >= 0.05));

    if (autoExecute) {
      debugPrint('LegalMoveMatcher OUTPUT: ${topMoveMap['san']}');
      return topMoveMap;
    }

    // Clarification Flows
    if (topScore < VoiceConfidenceConfig.minAbsoluteConfidence) {
      final formatMoveStr = formatMove(
        topMoveMap,
        bestCandidateForTopMove ?? topCandidate,
      );
      final errorMsg =
          "I'm only ${(topScore * 100).toStringAsFixed(0)}% confident. Did you mean $formatMoveStr?";
      final err = {'error': errorMsg, 'clarificationMove': topMoveMap};
      debugPrint('LegalMoveMatcher OUTPUT: $err');
      return err;
    }

    // Gap too small -> Ambiguity!
    final topPiece = topMoveMap['piece'] as String;
    final secondMoveMap = secondMove!['move'] as Map<String, dynamic>;
    final secondPiece = secondMoveMap['piece'] as String;

    if (topPiece != secondPiece) {
      final List<String> sans = [];
      for (final rm in ratedMoves) {
        final score = rm['score'] as double;
        if ((topScore - score).abs() <= 0.02 ||
            score >= VoiceConfidenceConfig.minAbsoluteConfidence) {
          sans.add(rm['move']['san'] as String);
        }
      }
      final candidateStr = sans.join(', ');
      final err = {
        'error': 'Ambiguous voice command. Candidates: $candidateStr',
        'clarificationMove': topMoveMap,
      };
      debugPrint('LegalMoveMatcher OUTPUT: $err');
      return err;
    } else {
      final pMapPlural = {
        'n': 'knights',
        'r': 'rooks',
        'q': 'queens',
        'b': 'bishops',
        'k': 'kings',
        'p': 'pawns',
      };
      final pPlural = pMapPlural[topPiece] ?? 'pawns';
      final errorMsg = "Two $pPlural can move there. Please specify which one.";
      final err = {'error': errorMsg, 'clarificationMove': topMoveMap};
      debugPrint('LegalMoveMatcher OUTPUT: $err');
      return err;
    }
  }
}

/// Thin coordination class that maps spoken text to a legal move map.
class VoiceCommandParser {
  static String? classifyFailure(
    Map<String, dynamic>? result,
    String rawText,
    String normalizedText,
  ) {
    if (rawText.trim().isEmpty) {
      return 'Speech recognition failed';
    }
    if (normalizedText.trim().isEmpty) {
      return 'Text normalization failed';
    }
    if (result == null) {
      return 'Piece not recognized';
    }
    if (result.containsKey('error')) {
      final err = result['error'] as String;
      if (err.contains("I couldn't recognize the piece")) {
        return 'Piece not recognized';
      }
      if (err.contains("I couldn't recognize the destination square")) {
        return 'Destination not recognized';
      }
      if (err.contains("confident") || err.contains("%")) {
        return 'Confidence too low';
      }
      if (err.contains("isn't legal")) {
        return 'Move not legal';
      }
      if (err.contains("Ambiguous") ||
          err.contains("Two ") ||
          err.contains("Please specify")) {
        return 'Ambiguous move';
      }
      return 'Piece not recognized'; // Fallback
    }
    return null;
  }

  static void printDebugPipeline({
    required String rawSpeech,
    required double sttConfidence,
    required String normalizedText,
    required String encodedTokens,
    required List<Map<String, dynamic>> ratedMoves,
    required double confidenceGap,
    required Map<String, dynamic>? matchedMove,
    required bool executionSuccess,
    required double elapsedTimeMs,
    required double minAbsoluteConfidence,
    required double minConfidenceGap,
    required VoiceIntent intent,
  }) {
    debugPrint('==================================================');
    debugPrint('VOICE DEBUG MODE');
    debugPrint('==================================================');
    debugPrint('RAW SPEECH: $rawSpeech');
    debugPrint('Normalized: $normalizedText');
    debugPrint('Encoded: $encodedTokens');
    debugPrint('Legal Moves Considered: ${ratedMoves.length}');
    debugPrint('Parsed Intent: piece=${intent.piece}, dest=${intent.destinationSquare}, originSq=${intent.originSquare}, originFile=${intent.originFile}, originRank=${intent.originRank}');
    debugPrint('Synonyms Used: ${intent.synonymsUsed.isEmpty ? "none" : intent.synonymsUsed.join(", ")}');
    debugPrint('Capture Detection: ${intent.isCapture ? "Yes" : "No"}');
    debugPrint('Promotion Detection: ${intent.isPromotion ? "Yes (Piece: ${intent.promotionPiece})" : "No"}');
    debugPrint('Castling Detection: ${intent.isKingsideCastling ? "Yes (Kingside)" : (intent.isQueensideCastling ? "Yes (Queenside)" : "No")}');
    debugPrint('Ranked Scores (all):');
    if (ratedMoves.isEmpty) {
      debugPrint('  none');
    } else {
      for (final rm in ratedMoves) {
        final m = rm['move'] as Map<String, dynamic>;
        final score = rm['score'] as double;
        final sim = rm['similarityScore'] as double;
        final plaus = rm['plausibility'] as double;
        debugPrint(
          '  - ${m['san']} (combined: ${(score * 100).toStringAsFixed(1)}%, similarity: ${(sim * 100).toStringAsFixed(1)}%, plausibility: ${(plaus * 100).toStringAsFixed(1)}%)',
        );
      }
    }
    debugPrint(
      'Confidence Gap: ${(confidenceGap * 100).toStringAsFixed(1)}% (Required: ${(minConfidenceGap * 100).toStringAsFixed(1)}%)',
    );

    // Decision (auto-execute / clarify / reject)
    String decision = 'reject';
    if (matchedMove != null) {
      if (matchedMove.containsKey('error')) {
        decision = 'clarify';
      } else {
        decision = 'auto-execute';
      }
    }
    debugPrint('Decision: $decision');

    debugPrint('Reason:');
    if (matchedMove != null) {
      if (matchedMove.containsKey('error')) {
        final err = matchedMove['error'] as String;
        if (err.contains("reach")) {
          debugPrint('  Piece cannot reach square alternative');
        } else if (err.contains("confident")) {
          debugPrint('  Below execution threshold');
        } else if (err.contains("Ambiguous")) {
          debugPrint('  Confidence difference within threshold');
        } else if (err.contains("Two")) {
          debugPrint('  Multiple matching legal moves');
        } else {
          debugPrint('  Clarification prompt');
        }
      } else {
        debugPrint('  Move matched and verified');
      }
    } else {
      debugPrint('  No matching move found');
    }
    debugPrint(
      'Undo availability window: ${VoiceConfidenceConfig.undoWindowSeconds} seconds',
    );
    debugPrint('Pipeline Time: ${elapsedTimeMs.toStringAsFixed(3)} ms');
    debugPrint('==================================================');
  }

  static Map<String, dynamic>? parseCommand(
    String text,
    List<Map<String, dynamic>> legalMoves, {
    double sttConfidence = 1.0,
    String boardFen = '',
  }) {
    final totalStopwatch = Stopwatch()..start();

    try {
      final normStopwatch = Stopwatch()..start();
      final normalized = TextNormalizer.normalize(text);
      normStopwatch.stop();

      final phoneticStopwatch = Stopwatch()..start();
      final tokens = normalized.split(RegExp(r'\s+'));
      final encodedTokens = tokens
          .map((t) => PhoneticEncoder.instance.encode(t))
          .join(' ');
      phoneticStopwatch.stop();

      final similarityStopwatch = Stopwatch()..start();
      for (final t in tokens) {
        WordSimilarityService.evaluateSimilarity(t, 'knight');
      }
      similarityStopwatch.stop();

      final pieceStopwatch = Stopwatch()..start();
      final pieceCandidates = PieceNormalizer.rankedCandidates(normalized);
      pieceStopwatch.stop();

      final squareStopwatch = Stopwatch()..start();
      final squareCandidates = SquareNormalizer.rankedCandidates(normalized);
      squareStopwatch.stop();

      final intentStopwatch = Stopwatch()..start();
      final parsedIntent = VoiceIntent.parse(normalized, rawText: text);
      final intent = VoiceIntent(
        piece: parsedIntent.piece,
        originFile: parsedIntent.originFile,
        originRank: parsedIntent.originRank,
        originSquare: parsedIntent.originSquare,
        destinationSquare: parsedIntent.destinationSquare,
        isKingsideCastling: parsedIntent.isKingsideCastling,
        isQueensideCastling: parsedIntent.isQueensideCastling,
        confidence: parsedIntent.confidence * sttConfidence,
        isCapture: parsedIntent.isCapture,
        isCheck: parsedIntent.isCheck,
        isCheckmate: parsedIntent.isCheckmate,
        isPromotion: parsedIntent.isPromotion,
        promotionPiece: parsedIntent.promotionPiece,
        synonymsUsed: parsedIntent.synonymsUsed,
      );
      intentStopwatch.stop();

      final matchingStopwatch = Stopwatch()..start();
      final chosenMove = LegalMoveMatcher.match(
        intent,
        legalMoves,
        normalizedText: normalized,
        sttConfidence: sttConfidence,
      );
      matchingStopwatch.stop();

      totalStopwatch.stop();

      final failureReason = classifyFailure(chosenMove, text, normalized);
      if (chosenMove == null || chosenMove.containsKey('error')) {
        VoiceRegressionService.handleFailure(
          rawSpeech: text,
          boardFen: boardFen,
          legalMoves: legalMoves,
          failureReason: failureReason ?? 'Unknown error',
          sttConfidence: sttConfidence,
          intent: intent,
        );
      }
      final String finalRes = chosenMove == null
          ? 'failed'
          : (chosenMove.containsKey('error')
                ? 'failed: ${chosenMove['error']}'
                : chosenMove['san'] as String);

      final Map<String, double> confMap = {
        'piece': intent.piece != null ? intent.confidence : 0.0,
        'square': intent.destinationSquare != null ? intent.confidence : 0.0,
        'intent': intent.confidence,
      };

      final pCandidatesList = pieceCandidates
          .map((pc) => {'name': pc.name, 'score': pc.score})
          .toList();

      final sCandidatesList = squareCandidates
          .map((sc) => {'square': sc.square, 'score': sc.score})
          .toList();

      final Map<String, dynamic> selectedIntentMap = {
        'piece': intent.piece,
        'destinationSquare': intent.destinationSquare,
        'originSquare': intent.originSquare,
        'originFile': intent.originFile,
        'originRank': intent.originRank,
        'isKingside': intent.isKingsideCastling,
        'isQueenside': intent.isQueensideCastling,
        'confidence': intent.confidence,
      };

      DiagnosticRecorder.instance.record(
        rawSpeech: text,
        recognizedText: normalized,
        pieceCandidates: pCandidatesList,
        squareCandidates: sCandidatesList,
        confidenceScores: confMap,
        selectedIntent: selectedIntentMap,
        legalMoveCount: legalMoves.length,
        finalResult: finalRes,
        failureReason: failureReason,
        elapsedTimeMs: totalStopwatch.elapsedMicroseconds / 1000.0,
      );

      if (SettingsService.instance.isVoiceDebugMode) {
        final List<Map<String, dynamic>> ratedMoves =
            LegalMoveMatcher.lastRatedMoves;
        final double confidenceGap = LegalMoveMatcher.lastConfidenceGap;
        final double minAbs = LegalMoveMatcher.lastMinAbsoluteConfidence;
        final double minGap = LegalMoveMatcher.lastMinConfidenceGap;

        printDebugPipeline(
          rawSpeech: text,
          sttConfidence: sttConfidence,
          normalizedText: normalized,
          encodedTokens: encodedTokens,
          ratedMoves: ratedMoves,
          confidenceGap: confidenceGap,
          matchedMove: chosenMove,
          executionSuccess:
              chosenMove != null && !chosenMove.containsKey('error'),
          elapsedTimeMs: totalStopwatch.elapsedMicroseconds / 1000.0,
          minAbsoluteConfidence: minAbs,
          minConfidenceGap: minGap,
          intent: intent,
        );
      }

      if (chosenMove != null) {
        chosenMove.remove('_ratedMoves');
        chosenMove.remove('_confidenceGap');
        chosenMove.remove('_minAbsoluteConfidence');
        chosenMove.remove('_minConfidenceGap');
      }
      return chosenMove;
    } catch (e, stackTrace) {
      totalStopwatch.stop();
      debugPrint('Unexpected error in parseCommand: $e\n$stackTrace');
      DiagnosticRecorder.instance.record(
        rawSpeech: text,
        recognizedText: '',
        pieceCandidates: [],
        squareCandidates: [],
        confidenceScores: {},
        legalMoveCount: legalMoves.length,
        finalResult: 'failed: Unexpected internal error: $e',
        failureReason: 'Unexpected internal error',
        elapsedTimeMs: totalStopwatch.elapsedMicroseconds / 1000.0,
      );
      return {'error': 'Unexpected internal error'};
    }
  }
}
