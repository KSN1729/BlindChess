# Day 27: Blindfold Mode Tap-to-Guess & Scoring Notes

Welcome to Day 27! Today, we added **interactive tap-to-guess scoring feedback overlays and a temporary Reveal button with move-based cooldowns**.

---

## 1. What Counts as a "Guess Attempt"?

To prevent score distortion, we defined a **guess attempt** as any tap on the board when pieces are visually hidden, **EXCEPT**:
1. Taps on a highlighted legal destination square (which executes a move).
2. Taps on the currently selected square (which deselects it).

Every valid guess attempt checks if the tapped square contains a piece belonging to the active player:
- **Correct Guess**: Tapped square holds a piece matching the current turn's color. Score increments (attempts + 1, correct + 1). A green checkmark overlay flashes.
- **Incorrect Guess**: Tapped square is empty or holds an opponent's piece. Score increments (attempts + 1, correct + 0). A red cross overlay flashes.

---

## 2. Non-Blocking Feedback Flash Overlays

To give visual reinforcement without pausing gameplay, we store overlays in a map `_flashStates` and schedule automatic removal after 450 milliseconds:
```dart
void _triggerFlash(int row, int col, String color) {
  setState(() {
    _flashStates[(row, col)] = color;
  });
  Future.delayed(const Duration(milliseconds: 450), () {
    if (mounted) {
      setState(() {
        _flashStates.remove((row, col));
      });
    }
  });
}
```
In the `ChessSquare` widget, we overlay this colored container inside a `Stack` widget. This is completely non-blocking!

---

## 3. Asynchronous Timers (Dart Timer)

The Reveal button lets the player sneak a peek at the board. Tapping it sets `_isRevealed = true` and schedules a timer:
```dart
_revealTimer = Timer(const Duration(seconds: 3), () {
  setState(() {
    _isRevealed = false;
  });
});
```
This temporarily suspends piece hiding for exactly 3 seconds, after which pieces fade out again.

---

## 4. Move-Based Cooldowns

Instead of wall-clock timers (which can be bypassed by waiting), we enforce a cooldown based on game moves:
```dart
int get revealCooldownRemaining {
  if (_revealLastUsedMoveCount == null) return 0;
  final currentMoves = chessEngineService.getHistory().length;
  final movesPlayedSince = currentMoves - _revealLastUsedMoveCount!;
  final remaining = 10 - movesPlayedSince;
  return remaining > 0 ? remaining : 0;
}
```
This ensures the player must play 10 additional moves before using the Reveal button again.
