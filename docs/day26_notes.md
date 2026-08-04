# Day 26: Blindfold Mode Toggle & Hiding Notes

Welcome to Day 26! Today, we began Milestone 3 by implementing **Blindfold Mode toggles and a relative piece-hiding countdown**.

---

## 1. User Interface: Switch Widget

We added a standard Material Design `Switch` toggle between "Normal" and "Blindfold" labels. The switch is bound to a state variable:
```dart
Switch(
  value: isBlindfoldMode,
  onChanged: _toggleBlindfoldMode,
)
```

---

## 2. Counting Down Move Thresholds Mid-Game

To prevent weird visual behaviors when toggling Blindfold Mode mid-game, the piece-hiding rule is computed relative to the move count at the moment the switch is turned ON:
```dart
bool get shouldHidePieces {
  if (!isBlindfoldMode) return false;
  final currentMoves = chessEngineService.getHistory().length;
  return currentMoves >= (_blindfoldToggleMoveCount + blindfoldMoveThreshold);
}
```
* If a player starts the game with Blindfold Mode ON, `_blindfoldToggleMoveCount` is `0`, so pieces hide at move `5` (since `currentMoves >= 5`).
* If a player plays `3` moves in Normal mode, then switches Blindfold ON, `_blindfoldToggleMoveCount` becomes `3`, so pieces hide at move `8` (since `3 + 5 = 8`). This guarantees a full 5-move countdown from the moment they toggle the mode.

---

## 3. Smooth Fade Transitions (AnimatedOpacity)

Instead of instantly erasing pieces, we wrap the piece's text character in an `AnimatedOpacity` widget:
```dart
AnimatedOpacity(
  opacity: isPieceHidden ? 0.0 : 1.0,
  duration: const Duration(milliseconds: 250),
  child: Text(symbolText, style: ...),
)
```
Flutter handles the interpolation between opacity `1.0` (fully visible) and `0.0` (invisible) smoothly over 250 milliseconds. The widget remains in the tree, so taps and layout constraints behave identically.

---

## 4. Preventing Tooltip Cheating

To prevent players from hovering over invisible squares to discover pieces, we dynamically switch the `Tooltip` message based on the piece hiding state:
```dart
message: isPieceHidden
    ? 'Square $label'
    : (pieceName == 'Empty' ? 'Empty Square' : '${isWhitePiece ? 'White' : 'Black'} $pieceName')
```

---

Congratulations on starting Milestone 3! You can now test your visualization skills by keeping track of the pieces mentally!
