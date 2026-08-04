# Day 24: Chess Engine Special Moves Notes

Welcome to Day 24! Today, we verified that **castling and en passant** work seamlessly in our UI, and we implemented a proper **pawn promotion** selection dialog.

---

## 1. Castling and En Passant

* **Castling**: A special move involving the King and a Rook. The King moves two squares toward a Rook, and the Rook hops over the King to the adjacent square. Because our board sync rebuilds the entire UI board from the rules engine's state after every move, moving two pieces (King and Rook) works automatically!
* **En Passant**: A special pawn capture. If a player moves their pawn two squares forward, and lands adjacent to an opponent's pawn, the opponent can capture it "in passing" by moving diagonally behind it. The captured pawn is on the adjacent square, not the destination. Our board sync correctly removes this adjacent pawn from the board.

---

## 2. Pawn Promotion Flow

Pawn promotion occurs when a pawn reaches the opposite end of the board (rank 8 for White, rank 1 for Black). It must be promoted to a Queen, Rook, Bishop, or Knight.

Instead of auto-promoting to Queen, we intercept the move and show a dialog:
```dart
if (isPawn && isPromotionRow) {
  _showPromotionDialog(movingColor).then((choice) {
    if (choice != null) {
      chessEngineService.makeMove(..., promotion: choice);
    }
  });
}
```

---

## 3. Asynchronous Flow in Flutter

Showing a dialog in Flutter is an **asynchronous operation**. The `showDialog` function returns a `Future`, which resolves once the user selects a choice and the dialog closes.

* **Blocking**: Because the move execution code is placed inside the `.then(...)` callback, the game board's state is not updated immediately when the user taps the promotion square. The move is effectively "blocked" until a choice is resolved.
* **Resuming**: Once a button is tapped, `Navigator.of(context).pop(choice)` is triggered. This resolves the `Future`, firing the `.then(...)` callback, which resumes the move execution by calling `makeMove` with the selected piece code (`'q'`, `'r'`, `'b'`, `'n'`).

---

Congratulations on completing Day 24! Special moves are now fully supported with interactive selection!
