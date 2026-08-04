import 'package:flutter/foundation.dart';
import 'package:chess/chess.dart' as chess;
import '../models/chess_piece.dart';

/// [What an "adapter" or "translation layer" is and why we're using one]
/// An Adapter is a design pattern that translates the interface of one class into another interface
/// that clients expect.
///
/// In our project, the external `chess` package represents pieces using its own internal `Piece` class
/// and `PieceType` constants. However, our UI expects our own custom `ChessPiece` class and `PieceType` enums.
///
/// Instead of rewriting our entire codebase to depend directly on the external package (which makes the code
/// harder to read and tightly couples us to this specific library), we write `ChessEngineService` as an adapter.
/// It translates the library's types into our custom domain types seamlessly behind the scenes.
class ChessEngineService {
  // Private instance of the chess engine. It is the single source of truth for the game logic.
  final chess.Chess _chess;

  /// Constructor initializes the chess engine to the standard starting position.
  ChessEngineService() : _chess = chess.Chess();

  /// [FEN (Forsyth-Edwards Notation)]
  /// FEN is a standard, single-line text string format used to represent the exact layout of a chessboard
  /// at any given moment in time (e.g. piece locations, whose turn it is, castling rights, en passant targets).
  ///
  /// For the starting position, it looks like:
  /// `rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1`
  ///
  /// Having a `fen` getter makes it extremely easy to debug layouts or write clean tests.
  String get fen => _chess.fen;

  /// Exposes which player's active turn it is (White or Black).
  PieceColor get activeTurn {
    return (_chess.turn == chess.Color.WHITE)
        ? PieceColor.white
        : PieceColor.black;
  }

  /// Retrieves the piece at a given row and column coordinate by translating the indices to a chess square name
  /// and mapping the resulting engine piece to our custom ChessPiece model.
  ChessPiece? pieceAt(int row, int column) {
    // 1. Map row index (0..7) to chess rank (8..1)
    final rank = 8 - row;

    // 2. Map column index (0..7) to chess file letter ('a'..'h')
    final filesList = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    final file = filesList[column];

    // 3. Construct the standard algebraic coordinate name (e.g. "e4", "a1")
    final square = '$file$rank';

    // 4. Retrieve the piece from the chess rules engine
    final enginePiece = _chess.get(square);

    // 5. If no piece exists on this square, return null (empty square)
    if (enginePiece == null) {
      return null;
    }

    // 6. Map the engine piece color to our PieceColor enum
    final pieceColor = (enginePiece.color == chess.Color.WHITE)
        ? PieceColor.white
        : PieceColor.black;

    // 7. Map the engine piece type to our PieceType enum
    PieceType pieceType;
    if (enginePiece.type == chess.PieceType.PAWN) {
      pieceType = PieceType.pawn;
    } else if (enginePiece.type == chess.PieceType.KNIGHT) {
      pieceType = PieceType.knight;
    } else if (enginePiece.type == chess.PieceType.BISHOP) {
      pieceType = PieceType.bishop;
    } else if (enginePiece.type == chess.PieceType.ROOK) {
      pieceType = PieceType.rook;
    } else if (enginePiece.type == chess.PieceType.QUEEN) {
      pieceType = PieceType.queen;
    } else if (enginePiece.type == chess.PieceType.KING) {
      pieceType = PieceType.king;
    } else {
      // Fallback
      pieceType = PieceType.pawn;
    }

    // 8. Return our custom ChessPiece object
    return ChessPiece(pieceType: pieceType, pieceColor: pieceColor);
  }

  /// [What legal move generation returns and how we translate it back into screen coordinates]
  /// The chess engine's `moves` method returns verbose map objects containing the origin and target
  /// squares in algebraic notation (like "e4").
  ///
  /// Since the UI works with standard 0-indexed grid coordinates, we parse these target squares,
  /// map the file character ('a'-'h') back to a column index (0-7), and map the rank number (1-8)
  /// back to a row index (0-7).
  ///
  /// This mapping remains independent of board flipping/perspectives. The visual repositioning of coordinates
  /// and highlight circles is done dynamically in the UI layer.
  List<(int row, int col)> legalDestinationsFrom(int row, int col) {
    // 1. Map row index (0..7) to chess rank (8..1)
    final rank = 8 - row;

    // 2. Map column index (0..7) to chess file letter ('a'..'h')
    final filesList = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    final file = filesList[col];

    // 3. Construct algebraic square coordinate (e.g. "e2")
    final square = '$file$rank';

    // 4. Query the engine for legal moves starting from this square in verbose mode (returning maps)
    final verboseMoves = _chess.moves({'square': square, 'verbose': true});

    final List<(int row, int col)> destinations = [];

    // 5. Parse each verbose move map to extract the target algebraic coordinate (e.g. "e4")
    for (final move in verboseMoves) {
      if (move is Map) {
        final toSquare = move['to'] as String;

        // 6. Map algebraic coordinate back to 0-indexed row and column
        if (toSquare.length == 2) {
          final targetFileChar = toSquare[0];
          final targetRankChar = toSquare[1];

          final targetCol = targetFileChar.codeUnitAt(0) - 'a'.codeUnitAt(0);
          final targetRow = 8 - int.parse(targetRankChar);

          destinations.add((targetRow, targetCol));
        }
      }
    }

    return destinations;
  }

  /// Attempts to execute a chess move from `(fromRow, fromCol)` to `(toRow, toCol)`.
  /// Returns `true` if the move is legal and executed successfully, `false` otherwise.
  bool makeMove(
    int fromRow,
    int fromCol,
    int toRow,
    int toCol, {
    String? promotion,
  }) {
    // 1. Map from coordinates to algebraic notation
    final fromRank = 8 - fromRow;
    final filesList = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    final fromFile = filesList[fromCol];
    final fromSquare = '$fromFile$fromRank';

    // 2. Map to coordinates to algebraic notation
    final toRank = 8 - toRow;
    final toFile = filesList[toCol];
    final toSquare = '$toFile$toRank';

    // 3. Assemble move properties
    final moveMap = <String, dynamic>{'from': fromSquare, 'to': toSquare};

    // 4. Handle pawn promotions: use specified piece, or default to Queen if omitted
    if (promotion != null) {
      moveMap['promotion'] = promotion.toLowerCase();
    } else {
      final piece = pieceAt(fromRow, fromCol);
      if (piece?.pieceType == PieceType.pawn) {
        final isPromotionRow =
            (piece?.pieceColor == PieceColor.white && toRow == 0) ||
            (piece?.pieceColor == PieceColor.black && toRow == 7);
        if (isPromotionRow) {
          moveMap['promotion'] = 'q';
        }
      }
    }

    // Step 6: Immediately before executing print 'Executing move: from, to, san'
    String sanStr = 'Unknown';
    final legalMoves = getLegalMoves();
    for (final m in legalMoves) {
      if (m['from'] == fromSquare && m['to'] == toSquare) {
        if (promotion != null) {
          if (m['promotion'] == promotion) {
            sanStr = m['san'] as String? ?? 'Unknown';
            break;
          }
        } else {
          sanStr = m['san'] as String? ?? 'Unknown';
          break;
        }
      }
    }

    debugPrint('--------------------------------------------------');
    debugPrint('STEP 6');
    debugPrint('--------------------------------------------------');
    debugPrint('Executing move:');
    debugPrint('  from: $fromSquare');
    debugPrint('  to: $toSquare');
    debugPrint('  san: $sanStr');

    // 5. Execute the move in the rules engine
    final success = _chess.move(moveMap);

    // Step 7: Immediately AFTER execution print 'Move success? Current FEN, Current turn'
    debugPrint('--------------------------------------------------');
    debugPrint('STEP 7');
    debugPrint('--------------------------------------------------');
    debugPrint('Move success? $success');
    debugPrint('Current FEN: $fen');
    debugPrint('Current turn: $activeTurn');

    if (!success) {
      debugPrint(
        'WHY: Move was rejected by the underlying chess rules engine. Input map was: $moveMap',
      );
    }

    return success;
  }

  /// Returns true if the player to move is currently in check.
  bool get inCheck => _chess.in_check;

  /// Returns true if the player to move is checkmated.
  bool get inCheckmate => _chess.in_checkmate;

  /// Returns true if the game is in a stalemate.
  bool get inStalemate => _chess.in_stalemate;

  /// Returns true if the game is drawn by stalemate, threefold repetition, insufficient material, or 50 moves.
  bool get inDraw => _chess.in_draw;

  /// Returns true if the game is drawn by threefold repetition.
  bool get inThreefoldRepetition => _chess.in_threefold_repetition;

  /// Returns true if the game is drawn due to insufficient mating material.
  bool get insufficientMaterial => _chess.insufficient_material;

  /// Scans the board to find the row/column index coordinate of the King of a specific color.
  /// Returns `(int row, int col)?` or null if not found.
  (int row, int col)? findKing(PieceColor color) {
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final piece = pieceAt(r, c);
        if (piece != null &&
            piece.pieceType == PieceType.king &&
            piece.pieceColor == color) {
          return (r, c);
        }
      }
    }
    return null;
  }

  /// Resets the engine state back to the standard starting layout.
  void reset() {
    _chess.reset();
  }

  /// Makes a move using a UCI coordinate string (e.g. "e2e4", "e7e8q").
  /// Returns true if successful, false otherwise.
  bool makeUciMove(String uci) {
    if (uci.length < 4) return false;
    final fromFile = uci[0];
    final fromRank = uci[1];
    final toFile = uci[2];
    final toRank = uci[3];
    final promotion = uci.length > 4 ? uci[4] : null;

    final fromCol = fromFile.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final fromRow = 8 - int.parse(fromRank);
    final toCol = toFile.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final toRow = 8 - int.parse(toRank);

    return makeMove(fromRow, fromCol, toRow, toCol, promotion: promotion);
  }

  /// Loads a custom position from a FEN string.
  bool load(String fen) {
    return _chess.load(fen);
  }

  /// Reverts the engine state by exactly one move.
  /// Returns the undone move map representation, or null if no moves to undo.
  Map? undo() {
    return _chess.undo();
  }

  /// Returns the raw list of played moves in Standard Algebraic Notation (SAN).
  List<dynamic> getHistory() {
    return _chess.getHistory();
  }

  /// Returns true if there are moves in the history stack that can be undone.
  bool get canUndo => _chess.getHistory().isNotEmpty;

  /// Retrieves all legal moves in the current position as verbose maps.
  List<Map<String, dynamic>> getLegalMoves() {
    final List<dynamic> moves = _chess.moves({'verbose': true});
    return moves.map((m) {
      final map = Map<String, dynamic>.from(m as Map);
      final fromSq = map['from'] as String;
      final piece = _chess.get(fromSq);
      if (piece != null) {
        String typeChar = 'p';
        if (piece.type == chess.PieceType.KNIGHT) {
          typeChar = 'n';
        } else if (piece.type == chess.PieceType.BISHOP) {
          typeChar = 'b';
        } else if (piece.type == chess.PieceType.ROOK) {
          typeChar = 'r';
        } else if (piece.type == chess.PieceType.QUEEN) {
          typeChar = 'q';
        } else if (piece.type == chess.PieceType.KING) {
          typeChar = 'k';
        }
        map['piece'] = typeChar;
      }
      return map;
    }).toList();
  }
}
