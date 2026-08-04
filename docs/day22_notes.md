# Day 22: Chess Engine Move Execution Notes

Welcome to Day 22! Today, we brought the chessboard to life by implementing **interactive move execution, turn enforcement, and last-move highlights**.

---

## 1. Turn-Taking and Enforcement

We now enforce the standard turn taking rules of chess:
- **Starting Turn**: The game always starts as White's turn (`w`).
- **Active Turn Check**: The UI prevents selecting pieces out of turn:
  ```dart
  final isCurrentPlayersPiece = tappedPiece != null &&
      (tappedPiece.pieceColor == chessEngineService.activeTurn);
  ```
  Tapping an opponent's piece when it is not your turn does nothing (no selection, no highlights).
- **Turn Alternation**: As soon as a successful move is dispatched to the rules engine, the active turn alternates. Only the opposite player's pieces can then be selected.

---

## 2. Choosing Reselection Behavior

When the player has a piece selected and taps a different, non-destination square:
1. **Option A (Strict Deselection)**: Clear the current selection, forcing the user to tap again.
2. **Option B (Reselection / Changing Mind)**: If the new square contains another piece belonging to the active player, select that piece immediately instead of deselecting.

**Our Choice: Option B (Reselection)**.
This behavior is standard in modern chess user interfaces (such as Lichess and Chess.com) because it feels extremely fluid, premium, and saves players from unnecessary clicks. Tapping empty squares or enemy pieces still triggers clean deselection.

---

## 3. Dispatched Move Execution

When a highlighted legal destination square is tapped, we dispatch the move coordinates to the rules engine:
1. **Coordinate Conversion**: We convert screen row/column indices for source and target cells into algebraic coordinate pairs (e.g. `(fromRow: 6, fromCol: 4)` $\rightarrow$ `"e2"`, `(toRow: 4, toCol: 4)` $\rightarrow$ `"e4"`).
2. **Auto-Promotion**: If a pawn is moving to the promotion row (row 0 for White, row 7 for Black), we append `'promotion': 'q'` to the move map so the rules engine automatically executes a Queen promotion.
3. **Execution**: We call `_chess.move({'from': fromSquare, 'to': toSquare, ...})`.
4. **State Synchrony**: The rules engine returns a boolean indicating success. On success, we record the move for the last-move highlights and clear active selections.

---

## 4. Visual Last-Move Highlights

To help players track the last action made on the board, we highlight both the starting (source) and ending (destination) squares of the last move.
* **Background Blending**: We apply a subtle yellow tint by blending it with the base checkboard background color:
  `Color.lerp(baseColor, Colors.yellow, 0.15)`
* **Consistency**: Tapping or flipping the board correctly preserves these highlights since their indexes are checked using perspective-adjusted screen coordinates.

---

Congratulations on completing Day 22! Tapping, moving, capturing, and turn-alternating are now fully active!
