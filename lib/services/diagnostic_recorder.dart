class DiagnosticRecord {
  final String rawSpeech;
  final String recognizedText;
  final List<Map<String, dynamic>> pieceCandidates;
  final List<Map<String, dynamic>> squareCandidates;
  final Map<String, double> confidenceScores;
  final Map<String, dynamic>? selectedIntent;
  final int legalMoveCount;
  final String finalResult;
  final String? failureReason;
  final DateTime timestamp;
  final double elapsedTimeMs;

  DiagnosticRecord({
    required this.rawSpeech,
    required this.recognizedText,
    required this.pieceCandidates,
    required this.squareCandidates,
    required this.confidenceScores,
    this.selectedIntent,
    required this.legalMoveCount,
    required this.finalResult,
    this.failureReason,
    required this.timestamp,
    required this.elapsedTimeMs,
  });

  Map<String, dynamic> toJson() {
    return {
      'rawSpeech': rawSpeech,
      'recognizedText': recognizedText,
      'pieceCandidates': pieceCandidates,
      'squareCandidates': squareCandidates,
      'confidenceScores': confidenceScores,
      'selectedIntent': selectedIntent,
      'legalMoveCount': legalMoveCount,
      'finalResult': finalResult,
      'failureReason': failureReason,
      'timestamp': timestamp.toIso8601String(),
      'elapsedTimeMs': elapsedTimeMs,
    };
  }
}

class DiagnosticRecorder {
  static final DiagnosticRecorder instance = DiagnosticRecorder._();
  DiagnosticRecorder._();

  final List<DiagnosticRecord> _records = [];

  List<DiagnosticRecord> get records => List.unmodifiable(_records);

  void record({
    required String rawSpeech,
    required String recognizedText,
    required List<Map<String, dynamic>> pieceCandidates,
    required List<Map<String, dynamic>> squareCandidates,
    required Map<String, double> confidenceScores,
    Map<String, dynamic>? selectedIntent,
    required int legalMoveCount,
    required String finalResult,
    String? failureReason,
    required double elapsedTimeMs,
  }) {
    final entry = DiagnosticRecord(
      rawSpeech: rawSpeech,
      recognizedText: recognizedText,
      pieceCandidates: pieceCandidates,
      squareCandidates: squareCandidates,
      confidenceScores: confidenceScores,
      selectedIntent: selectedIntent,
      legalMoveCount: legalMoveCount,
      finalResult: finalResult,
      failureReason: failureReason,
      timestamp: DateTime.now(),
      elapsedTimeMs: elapsedTimeMs,
    );
    _records.add(entry);
    if (_records.length > 100) {
      _records.removeAt(0);
    }
  }

  void updateLastRecordExecution({required bool success, String? error}) {
    if (_records.isNotEmpty) {
      final last = _records.last;
      _records[_records.length - 1] = DiagnosticRecord(
        rawSpeech: last.rawSpeech,
        recognizedText: last.recognizedText,
        pieceCandidates: last.pieceCandidates,
        squareCandidates: last.squareCandidates,
        confidenceScores: last.confidenceScores,
        selectedIntent: last.selectedIntent,
        legalMoveCount: last.legalMoveCount,
        finalResult: success
            ? 'success'
            : (error ?? 'failed: Execution failed'),
        failureReason: success ? null : 'Execution failed',
        timestamp: last.timestamp,
        elapsedTimeMs: last.elapsedTimeMs,
      );
    }
  }

  void clear() {
    _records.clear();
  }
}
