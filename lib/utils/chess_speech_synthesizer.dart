import '../services/accessibility_settings_service.dart';
import '../models/chess_piece.dart';

/// Helper utility to translate chess moves and states into natural spoken English.
class ChessSpeechSynthesizer {
  /// Translates a move map into a readable text sentence based on verbosity.
  static String translateMove({
    required Map<String, dynamic> move,
    required VerbosityLevel verbosity,
    required PieceColor moverColor,
    required bool isCheck,
    required bool isCheckmate,
    required bool isStalemate,
  }) {
    final piece = move['piece']?.toString() ?? 'p';
    final fromSq = move['from']?.toString() ?? '';
    final toSq = move['to']?.toString() ?? '';
    final flags = move['flags']?.toString() ?? '';
    final captured = move['captured']?.toString();
    final promotion = move['promotion']?.toString();

    final isCapture = flags.contains('c') || flags.contains('e');
    final isKingsideCastle = flags.contains('k');
    final isQueensideCastle = flags.contains('q');

    final colorStr = moverColor == PieceColor.white ? 'White' : 'Black';

    // 1. Get piece name
    final pieceName = _getPieceName(piece);
    final capPieceName = captured != null ? _getPieceName(captured) : 'piece';

    // Check for castling
    if (isKingsideCastle) {
      if (verbosity == VerbosityLevel.minimal) return 'Castle kingside';
      if (verbosity == VerbosityLevel.standard) return 'Castling kingside';
      return '$colorStr castled kingside';
    }
    if (isQueensideCastle) {
      if (verbosity == VerbosityLevel.minimal) return 'Castle queenside';
      if (verbosity == VerbosityLevel.standard) return 'Castling queenside';
      return '$colorStr castled queenside';
    }

    String announcement = '';

    switch (verbosity) {
      case VerbosityLevel.minimal:
        // e.g. "e4", "N f3", "B takes f7"
        if (piece == 'p') {
          if (isCapture) {
            announcement = '${fromSq[0]} takes $toSq';
          } else {
            announcement = toSq;
          }
        } else {
          final pieceLetter = _getPieceLetter(piece);
          if (isCapture) {
            announcement = '$pieceLetter takes $toSq';
          } else {
            announcement = '$pieceLetter $toSq';
          }
        }
        if (promotion != null) {
          announcement += ' promote ${_getPieceName(promotion)}';
        }
        break;

      case VerbosityLevel.standard:
        // e.g. "Pawn to e4", "Knight to f3", "Bishop takes Knight"
        if (isCapture) {
          announcement = '$pieceName takes $capPieceName on $toSq';
        } else {
          announcement = '$pieceName to $toSq';
        }
        if (promotion != null) {
          announcement += ', promoting to ${_getPieceName(promotion)}';
        }
        break;

      case VerbosityLevel.detailed:
        // e.g. "White pawn moved from e2 to e4"
        if (isCapture) {
          announcement = '$colorStr $pieceName on $fromSq captured $capPieceName on $toSq';
        } else {
          announcement = '$colorStr $pieceName moved from $fromSq to $toSq';
        }
        if (promotion != null) {
          announcement += ', promoting to a ${_getPieceName(promotion)}';
        }
        break;
    }

    if (isCheckmate) {
      announcement += '. Checkmate!';
    } else if (isStalemate) {
      announcement += '. Stalemate!';
    } else if (isCheck) {
      announcement += '. Check!';
    }

    return announcement;
  }

  static String _getPieceName(String piece) {
    switch (piece.toLowerCase()) {
      case 'p': return 'pawn';
      case 'n': return 'knight';
      case 'b': return 'bishop';
      case 'r': return 'rook';
      case 'q': return 'queen';
      case 'k': return 'king';
      default: return 'pawn';
    }
  }

  static String _getPieceLetter(String piece) {
    switch (piece.toLowerCase()) {
      case 'p': return 'pawn';
      case 'n': return 'Knight';
      case 'b': return 'Bishop';
      case 'r': return 'Rook';
      case 'q': return 'Queen';
      case 'k': return 'King';
      default: return 'pawn';
    }
  }
}
