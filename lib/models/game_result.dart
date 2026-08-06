import '../models/chess_piece.dart';

/// Types of results possible at the end of a chess match.
enum ResultType {
  checkmate,
  stalemate,
  drawAgreement,
  fiftyMoves,
  threefoldRepetition,
  insufficientMaterial,
  timeout,
}

/// Unified model representing the outcome of a chess match.
class GameResult {
  final ResultType type;
  final PieceColor? winnerColor; // Null represents a draw
  final String description;

  const GameResult({
    required this.type,
    this.winnerColor,
    required this.description,
  });

  /// Standard algebraic notation representing the result (e.g. "1-0", "0-1", "1/2-1/2").
  String get shortResultString {
    if (winnerColor == null) return '1/2-1/2';
    return winnerColor == PieceColor.white ? '1-0' : '0-1';
  }
}
