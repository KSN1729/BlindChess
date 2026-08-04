class VoiceConfidenceConfig {
  static const double pieceThreshold = 0.50;
  static const double squareThreshold = 0.50;
  static const double executeThreshold = 0.85;
  static const double suggestionThreshold = 0.70;

  // Weights for WordSimilarityService matching
  static const double weightExactMatch = 0.40;
  static const double weightPhonetic = 0.40;
  static const double weightEditDistance = 0.20;

  // Weights for final combined move execution confidence
  static const double weightSimilarity = 0.60;
  static const double weightSttConfidence = 0.20;
  static const double weightBoardContext = 0.20;

  // Confidence Gap & Voice Undo Configurations
  static const double minAbsoluteConfidence = 0.70;
  static const double minConfidenceGap = 0.10;
  static const double undoWindowSeconds = 3.0;
}
