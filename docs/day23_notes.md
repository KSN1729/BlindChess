# Day 23: Chess Engine Check, Checkmate, and Stalemate Notes

Welcome to Day 23! Today, we completed another key milestone by adding **Check, Checkmate, and Stalemate detection** to our application.

---

## 1. Game Status Terms in Chess

* **Check**: The active side's King is under immediate attack by an opponent's piece. The player *must* resolve this check on their very next move.
* **Checkmate**: The active side's King is in check, and there are absolutely *no legal moves* available to escape the threat. This ends the game, resulting in a win for the other player.
* **Stalemate**: The active side is *not* in check, but has *no legal moves* remaining on their turn. This results in a draw (tie).
* **Draw**: Other tie conditions, including threefold repetition of positions or insufficient mating material (e.g. King vs. King).

---

## 2. Leveraging the Rules Engine

Instead of writing complex and bug-prone math to track check vectors ourselves, we utilize the external rules engine getters:
```dart
bool get inCheck => _chess.in_check;
bool get inCheckmate => _chess.in_checkmate;
bool get inStalemate => _chess.in_stalemate;
bool get inDraw => _chess.in_draw;
```
These properties are evaluated instantly by the engine after every move.

---

## 3. Visual Highlights with BoxShadow Glow

To make the checked King immediately stand out without cluttering the screen or conflicting with the red selection borders, we added a premium **red neon glow** around the King's cell using a customized `boxShadow` inside the square's decoration:
```dart
boxShadow: isCheck
    ? [
        const BoxShadow(
          color: Colors.redAccent,
          blurRadius: 12.0,
          spreadRadius: 3.0,
        ),
      ]
    : null,
```
This is a standard design trick in modern, high-fidelity Web and Mobile UIs to highlight elements dynamically.

---

## 4. Flutter Post-Frame Callbacks

When displaying a dialog overlay right after a move, we must avoid triggering the dialog *during* the layout/build phase of the widget. Doing so would crash the Flutter framework.

To handle this cleanly, we use **`WidgetsBinding.instance.addPostFrameCallback`**:
```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  _showGameEndDialog(...);
});
```
This registers a callback that runs immediately *after* the board finishes rendering. The user sees their piece slide to the target cell, and *then* the dialog pops up gracefully, offering a polished, production-quality experience.

---

Congratulations on completing Day 23! Game status alerts and checks are now fully operational!
