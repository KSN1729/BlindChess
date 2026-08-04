# Day 25: Chess Engine Local 2-Player Polish Notes

Welcome to Day 25! Today, we completed Milestone 2 by adding **Undo capability and a visible Move History list in Standard Algebraic Notation (SAN)**.

---

## 1. Reverting Game States (Undo)

To allow players to take back moves during local 2-player training, we exposed the rules engine's `undo` mechanism:
```dart
Map? undo() {
  return _chess.undo();
}
```
Each call pops the last state from the engine's internal stack, reverting the board layout, active player's turn, castling rights, and check status.

---

## 2. Coordinating Highlight History

While the engine tracks move history internally, it does not keep track of screen row/column coordinates for visual highlights. To ensure that **last-move highlights** are updated correctly when moves are undone, we maintain a custom coordinate stack:
```dart
final List<((int, int), (int, int))> _moveHistoryCoords = [];
```
* **On Move**: Append the origin and target coordinate pairs to the stack.
* **On Undo**: Remove the last entry. If the stack is still not empty, set `lastMoveStart` and `lastMoveEnd` to the new top of the stack. If it is empty (back to the beginning of the game), set them to `null`.

---

## 3. Disabling UI Buttons Dynamically

In Flutter, you can disable an `ElevatedButton` by passing `null` as its `onPressed` parameter:
```dart
ElevatedButton(
  onPressed: !chessEngineService.canUndo
      ? null // Disables and greys out the button
      : () { ... } // Enables and executes logic
)
```
This is a standard declarative pattern that immediately updates the visual state of the button based on the condition `canUndo`.

---

## 4. Standard Algebraic Notation (SAN) Move History

The rules engine generates SAN strings for us automatically (e.g. `'e4'`, `'Nf3'`). We retrieve this raw list using `getHistory()` and format them into readable pairs for display:
* **White Move**: Element at index `i`.
* **Black Move**: Element at index `i + 1` (if it exists).
We wrap these in list items (e.g. `"1. e4 e5"`, `"2. Nf3 Nc6"`) and display them in a horizontal scrollable row panel.

---

Congratulations on completing Day 25 and Milestone 2! The local 2-player game is now fully playable, polished, and robust!
