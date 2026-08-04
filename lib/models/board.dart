import 'chess_piece.dart';

/// [Why we wrap raw data structures in a dedicated class]
/// In production software, raw data types (like List of Lists) are wrapped in specialized model classes
/// (like `Board`). This abstracts away the internal storage mechanism. If we ever decide to change the
/// underlying representation (e.g. representing the board as a single flat 1D list of 64 elements, or a Bitboard),
/// we only have to update the internal class code, and none of our UI files will break.
///
/// [Encapsulation]
/// Encapsulation is the practice of hiding the internal state of an object and requiring all interactions
/// to go through public methods/getters. Here, `_squares` starts with an underscore `_`, making it private
/// to this file. Screens cannot bypass validation or mutate the grid directly; they must interact via public APIs.
///
/// [Why the Board class should not know about UI or perspective]
/// The `Board` class represents the domain data model (the mathematical reality of the chess game).
/// It does not know about container sizes, screen offsets, text fonts, or player view perspectives.
/// Decoupling layout logic from domain logic keeps components modular, simple, and clean.
///
/// [How this prepares the project for a future GameState class]
/// By wrapping the board state in its own model, we can later compose it inside a larger `GameState` class
/// that manages turn tracking, move logs, check/checkmate flags, and timer constraints, without polluting
/// the grid rendering widgets.
class Board {
  // The private matrix containing the chess pieces. Private because of the leading underscore.
  final List<List<ChessPiece?>> _squares;

  /// Generative constructor.
  const Board(this._squares);

  /// [Factory constructors]
  /// A factory constructor is a special constructor that can perform calculation logic before returning
  /// an instance of the class. It can decide to return a cached instance, a subclass instance, or instantiate
  /// a new object with pre-configured parameters (like the starting chess pieces arrangement below).
  factory Board.initial() {
    final startingSquares = [
      const [
        ChessPiece(pieceType: PieceType.rook, pieceColor: PieceColor.black),
        ChessPiece(pieceType: PieceType.knight, pieceColor: PieceColor.black),
        ChessPiece(pieceType: PieceType.bishop, pieceColor: PieceColor.black),
        ChessPiece(pieceType: PieceType.queen, pieceColor: PieceColor.black),
        ChessPiece(pieceType: PieceType.king, pieceColor: PieceColor.black),
        ChessPiece(pieceType: PieceType.bishop, pieceColor: PieceColor.black),
        ChessPiece(pieceType: PieceType.knight, pieceColor: PieceColor.black),
        ChessPiece(pieceType: PieceType.rook, pieceColor: PieceColor.black),
      ],
      const [
        ChessPiece(pieceType: PieceType.pawn, pieceColor: PieceColor.black),
        ChessPiece(pieceType: PieceType.pawn, pieceColor: PieceColor.black),
        ChessPiece(pieceType: PieceType.pawn, pieceColor: PieceColor.black),
        ChessPiece(pieceType: PieceType.pawn, pieceColor: PieceColor.black),
        ChessPiece(pieceType: PieceType.pawn, pieceColor: PieceColor.black),
        ChessPiece(pieceType: PieceType.pawn, pieceColor: PieceColor.black),
        ChessPiece(pieceType: PieceType.pawn, pieceColor: PieceColor.black),
        ChessPiece(pieceType: PieceType.pawn, pieceColor: PieceColor.black),
      ],
      const [null, null, null, null, null, null, null, null],
      const [null, null, null, null, null, null, null, null],
      const [null, null, null, null, null, null, null, null],
      const [null, null, null, null, null, null, null, null],
      const [
        ChessPiece(pieceType: PieceType.pawn, pieceColor: PieceColor.white),
        ChessPiece(pieceType: PieceType.pawn, pieceColor: PieceColor.white),
        ChessPiece(pieceType: PieceType.pawn, pieceColor: PieceColor.white),
        ChessPiece(pieceType: PieceType.pawn, pieceColor: PieceColor.white),
        ChessPiece(pieceType: PieceType.pawn, pieceColor: PieceColor.white),
        ChessPiece(pieceType: PieceType.pawn, pieceColor: PieceColor.white),
        ChessPiece(pieceType: PieceType.pawn, pieceColor: PieceColor.white),
        ChessPiece(pieceType: PieceType.pawn, pieceColor: PieceColor.white),
      ],
      const [
        ChessPiece(pieceType: PieceType.rook, pieceColor: PieceColor.white),
        ChessPiece(pieceType: PieceType.knight, pieceColor: PieceColor.white),
        ChessPiece(pieceType: PieceType.bishop, pieceColor: PieceColor.white),
        ChessPiece(pieceType: PieceType.queen, pieceColor: PieceColor.white),
        ChessPiece(pieceType: PieceType.king, pieceColor: PieceColor.white),
        ChessPiece(pieceType: PieceType.bishop, pieceColor: PieceColor.white),
        ChessPiece(pieceType: PieceType.knight, pieceColor: PieceColor.white),
        ChessPiece(pieceType: PieceType.rook, pieceColor: PieceColor.white),
      ],
    ];

    return Board(startingSquares);
  }

  /// Returns the piece at the specified row and column coordinate.
  ChessPiece? pieceAt(int row, int column) {
    return _squares[row][column];
  }

  // Row and Column count getters.
  int get rowCount => 8;
  int get columnCount => 8;
}
