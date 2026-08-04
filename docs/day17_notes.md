# Day 17: Object-Oriented Chess Piece Models Notes

Welcome to Day 17! Today, we took our board representation to the next level by transitioning from a 2D array of raw strings to a **two-dimensional array of `ChessPiece` objects** (`List<List<ChessPiece?>>`).

---

## 1. Core Object-Oriented Programming (OOP) Concepts

We introduced three essential OOP concepts to represent chess data:

### What is a Class?
A **class** is a blueprint or template that defines the structure and behavior of data. It specifies what fields (properties) and methods (behaviors) the objects created from it will possess.
```dart
class ChessPiece {
  final PieceType pieceType;
  final PieceColor pieceColor;
}
```

### What is an Object?
An **object** is a concrete instance of a class. The class is the blueprint; the object is the actual building.
```dart
// We instantiated 32 concrete objects from the ChessPiece class:
const blackRook = ChessPiece(pieceType: PieceType.Rook, pieceColor: PieceColor.Black);
const whitePawn = ChessPiece(pieceType: PieceType.Pawn, pieceColor: PieceColor.White);
```

### What is an Enum?
An **enum** (enumeration) is a collection of constant values.
- Enums prevent misspelled strings (e.g. typing `"kng"` or `"King"` by mistake).
- They provide compile-time safety, as the editor immediately flags invalid values.

```dart
enum PieceType { King, Queen, Rook, Bishop, Knight, Pawn }
enum PieceColor { White, Black }
```

---

## 2. Null Safety in Dart

Dart is a **null-safe** language.
- By default, variables cannot hold `null` (representing the absence of a value).
- To allow a variable to be nullable, we append a question mark `?` to its type.

```dart
List<List<ChessPiece?>> board = ...
```
Here, `ChessPiece?` tells Dart that a board cell can either contain a concrete `ChessPiece` object, or it can be `null` (which we use to represent an empty square).

### Safe Navigation & Null-Coalescing:
We use safe navigation (`?.`) and null-coalescing (`??`) to avoid crashes when dealing with nullable types:
```dart
final symbolText = piece?.symbol ?? "";
```
- If `piece` is `null`, `piece?.symbol` returns `null`.
- The `?? ""` operator intercepts the `null` and falls back to an empty string `""`.

---

## 3. What is a Getter?

A **getter** is a special function in Dart that retrieves properties of an object using field syntax (`piece.symbol`) instead of standard method invocation syntax (`piece.getSymbol()`).

In `ChessPiece`, we implemented a getter to dynamically resolve the Unicode piece symbols based on the piece color and type:
```dart
String get symbol {
  // Logic to return correct Unicode character
}
```

---

## 4. Why Production Apps Use Models Instead of Raw Strings

In beginner projects, representing everything as simple strings (e.g. `"white_pawn"`) is common. However, production apps use models because:
1. **Compiling verification**: String comparisons (like `piece == "pawn"`) are prone to silent typos that are hard to debug. Enums and models are checked during compilation.
2. **Schema structure**: Bundling multiple attributes (color, type, coordinates) into a single object prevents out-of-sync states.
3. **Behavior integration**: Classes can encapsulate helper methods (e.g. determining move ranges or validation checks) close to the data they operate on.

---

## 5. Why this Design Makes Future Chess Movement Easier

By using objects and enums:
* When moving a piece, we simply reassign references in our matrix:
  ```dart
  board[targetRow][targetCol] = board[startRow][startCol];
  board[startRow][startCol] = null;
  ```
* Calculating legal moves becomes a clean operation on enums:
  ```dart
  if (piece.pieceType == PieceType.Pawn) {
    // Pawn-specific movement rules
  }
  ```

---

Congratulations on completing Day 17! You have successfully mastered object modeling, custom getters, and nullable architectures in Flutter.
