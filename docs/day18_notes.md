# Day 18: Encapsulated Board Model Classes Notes

Welcome to Day 18! Today, we completed a crucial refactoring step by wrapping our two-dimensional list structure inside a dedicated **`Board` class model**.

---

## 1. What is Encapsulation?

**Encapsulation** is an OOP principle that involves grouping data (properties) and methods (behaviors) together inside a single unit (a class), and hiding internal representation details from direct outside access.

In `board.dart`:
- We declared `final List<List<ChessPiece?>> _squares;`.
- The leading underscore `_` makes the variable **private** to `board.dart`.
- The outside screens (like `learning_screen.dart`) cannot see or directly manipulate the `_squares` array.
- Instead, they query the public interface: `board.pieceAt(row, column)`.

### Why this is powerful:
If we decide to change the internal structure of the board in the future (e.g. optimizing it into a single-dimensional list `List<ChessPiece?>` of size 64, or using compact Bitboards), we only need to edit `board.dart`. The UI rendering files will require zero modifications since they continue calling the same `pieceAt(row, col)` interface.

---

## 2. What is a Factory Constructor?

A **factory constructor** in Dart allows custom logic to run before producing an instance of a class. Unlike standard generative constructors, a factory constructor:
- Does not automatically create a new instance of the class.
- Can return cached objects or instances of subclasses.
- Can set up complex initialization structures (like our standard starting layout).

```dart
factory Board.initial() {
  final startingSquares = [ ... ];
  return Board(startingSquares);
}
```

This encapsulates the configuration of standard starting setups in a single place.

---

## 3. Separating "Board Data" from "Board Display Logic"

We decoupled our grid data representation from visual presentation:
* **The `Board` Model**: Focuses purely on storing piece locations. It has no concept of color schemes (brown vs white), margins, sizes, perspectives, or coordinate text labels.
* **The `LearningScreen` (UI)**: Focuses purely on rendering. It handles the `isWhitePerspective` flag, coordinates math (`files[actualColIndex]`), and tap handlers.

---

## 4. Scalability for Future Features

By putting the grid data inside a dedicated model, implementing advanced gameplay features becomes straightforward:
1. **Move History & Undo**: We can store a stack of `Board` states. Undoing a move is as simple as popping the previous `Board` object off the history stack and calling `setState()`.
2. **Legal Move Calculation**: We can write pure unit tests to calculate valid paths directly on the `Board` class (`board.getLegalMovesFor(row, col)`) without needing to load or simulate tap gestures on heavy UI widgets.
3. **Blindfold Mode**: We can easily swap out the visual chessboard rendering tree completely while using the exact same underlying `Board` class to feed data into text-to-speech audio players.

---

Congratulations on completing Day 18! You have successfully mastered object encapsulation, factory builders, and decoupled domain models in Flutter.
