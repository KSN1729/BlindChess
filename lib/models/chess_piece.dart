/// [Enums]
/// An enum (short for enumeration) is a special data type used to define a collection of constant values.
/// Using enums prevents developers from typing arbitrary or misspelled strings, catching errors at compile time.
/// Following Dart coding guidelines, we name our enum constants using lowerCamelCase (e.g. king, white).
enum PieceType { king, queen, rook, bishop, knight, pawn }

enum PieceColor { white, black }

/// [Classes]
/// A class is a blueprint or template for creating objects. It defines the properties (fields) and behaviors
/// (methods/getters) that objects of this type will have.
///
/// [Objects]
/// An object is a concrete instance of a class. For example, `ChessPiece(pieceType: PieceType.king, pieceColor: PieceColor.white)`
/// is an object representing a specific White King.
///
/// [Why models improve maintainability]
/// Rather than representing chess pieces as raw strings throughout the application, we bundle their attributes
/// (color, type) into a structured `ChessPiece` model class. This ensures all pieces adhere to the same schema,
/// makes it easy to add future behaviors (like possible move lists), and protects against data inconsistency.
class ChessPiece {
  final PieceType pieceType;
  final PieceColor pieceColor;

  const ChessPiece({required this.pieceType, required this.pieceColor});

  /// [Getters]
  /// A getter is a special method in Dart that allows clients to read properties of an object using property
  /// syntax (`piece.symbol`) instead of function call syntax (`piece.getSymbol()`).
  /// It calculates and returns a value dynamically based on internal fields.
  String get symbol {
    if (pieceColor == PieceColor.white) {
      switch (pieceType) {
        case PieceType.king:
          return '♔';
        case PieceType.queen:
          return '♕';
        case PieceType.rook:
          return '♖';
        case PieceType.bishop:
          return '♗';
        case PieceType.knight:
          return '♘';
        case PieceType.pawn:
          return '♙';
      }
    } else {
      switch (pieceType) {
        case PieceType.king:
          return '♚';
        case PieceType.queen:
          return '♛';
        case PieceType.rook:
          return '♜';
        case PieceType.bishop:
          return '♝';
        case PieceType.knight:
          return '♞';
        case PieceType.pawn:
          return '♟';
      }
    }
  }
}
