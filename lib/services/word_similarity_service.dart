import '../utils/phonetic_encoder.dart';
import '../config/voice_confidence_config.dart';

class SimilarityResult {
  final String candidate;
  final double score;
  final double phoneticScore;
  final double editDistanceScore;
  final double overallScore;

  SimilarityResult({
    required this.candidate,
    required this.score,
    required this.phoneticScore,
    required this.editDistanceScore,
    required this.overallScore,
  });
}

/// A service providing phonetic matching and Levenshtein similarity scoring offline.
class WordSimilarityService {
  /// Core Levenshtein similarity calculations.
  static double levenshteinDistance(String s1, String s2) {
    final clean1 = s1.toLowerCase().trim();
    final clean2 = s2.toLowerCase().trim();
    if (clean1 == clean2) return 1.0;
    if (clean1.isEmpty || clean2.isEmpty) return 0.0;

    final len1 = clean1.length;
    final len2 = clean2.length;
    final dp = List.generate(len1 + 1, (_) => List<int>.filled(len2 + 1, 0));

    for (int i = 0; i <= len1; i++) {
      dp[i][0] = i;
    }
    for (int j = 0; j <= len2; j++) {
      dp[0][j] = j;
    }

    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        final cost = (clean1[i - 1] == clean2[j - 1]) ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1, // deletion
          dp[i][j - 1] + 1, // insertion
          dp[i - 1][j - 1] + cost, // substitution
        ].reduce((curr, next) => curr < next ? curr : next);
      }
    }

    final distance = dp[len1][len2];
    final maxLength = len1 > len2 ? len1 : len2;
    return 1.0 - (distance / maxLength);
  }

  /// Evaluates an input against a candidate using weighted phonetic, edit distance, and exact match checks.
  static SimilarityResult evaluateSimilarity(String input, String candidate) {
    final cleanInput = input.toLowerCase().trim();
    final cleanCandidate = candidate.toLowerCase().trim();

    // 1. Exact Match
    final isExact = cleanInput == cleanCandidate;
    final double exactMatchScore = isExact ? 1.0 : 0.0;

    // 2. Phonetic Match
    final String encInput = PhoneticEncoder.instance.encode(cleanInput);
    final String encCandidate = PhoneticEncoder.instance.encode(cleanCandidate);
    final bool isPhoneticExact = encInput == encCandidate;
    final double phoneticScore = isPhoneticExact
        ? 1.0
        : levenshteinDistance(encInput, encCandidate);

    // 3. Edit Distance Score
    final double editDistanceScore = levenshteinDistance(
      cleanInput,
      cleanCandidate,
    );

    // 4. Combined Overall Score using configurable weights
    final double rawOverallScore =
        (exactMatchScore * VoiceConfidenceConfig.weightExactMatch) +
        (phoneticScore * VoiceConfidenceConfig.weightPhonetic) +
        (editDistanceScore * VoiceConfidenceConfig.weightEditDistance);

    final overallScore = rawOverallScore.clamp(0.0, 1.0);

    return SimilarityResult(
      candidate: candidate,
      score: overallScore,
      phoneticScore: phoneticScore,
      editDistanceScore: editDistanceScore,
      overallScore: overallScore,
    );
  }

  /// Kept for backward compatibility. Returns the overall score.
  static double similarity(String s1, String s2) {
    return evaluateSimilarity(s1, s2).overallScore;
  }

  /// Evaluates an input against multiple candidates and returns them sorted by overall score descending.
  static List<SimilarityResult> rankedCandidates(
    String input,
    Iterable<String> candidates,
  ) {
    final results = <SimilarityResult>[];
    for (final cand in candidates) {
      results.add(evaluateSimilarity(input, cand));
    }
    results.sort((a, b) => b.overallScore.compareTo(a.overallScore));
    return results;
  }
}
