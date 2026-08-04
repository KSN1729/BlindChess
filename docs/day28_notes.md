# Day 28: Blindfold Mode Difficulty Presets Notes

Welcome to Day 28! Today, we completed Milestone 3 by adding **Easy, Medium, and Hard difficulty presets and a Segmented Control selection UI**.

---

## 1. Mapped Configurations using Enums & Getters

Rather than duplicating the piece-hiding or score-tracking logic for each difficulty level, we declared an enum:
```dart
enum BlindfoldDifficulty { easy, medium, hard }
```
And mapped this to our existing `blindfoldMoveThreshold` variable using a dynamic getter:
```dart
int get blindfoldMoveThreshold {
  switch (selectedDifficulty) {
    case BlindfoldDifficulty.easy:
      return 10;
    case BlindfoldDifficulty.medium:
      return 5;
    case BlindfoldDifficulty.hard:
      return 0;
  }
}
```
This is a standard design pattern that separates state declarations from computed configurations.

---

## 2. Segmented Selection (ToggleButtons)

To provide a sleek, segmented control in Flutter, we used the `ToggleButtons` widget:
```dart
ToggleButtons(
  isSelected: [
    selectedDifficulty == BlindfoldDifficulty.easy,
    selectedDifficulty == BlindfoldDifficulty.medium,
    selectedDifficulty == BlindfoldDifficulty.hard,
  ],
  onPressed: (int index) { ... },
  children: const [
    Text('Easy'),
    Text('Medium'),
    Text('Hard'),
  ],
)
```
This widget handles active styling (e.g. background fill color, rounded borders, and selected font weights) and renders when `isBlindfoldMode` is toggled ON.

---

## 3. Session Persistence (Non-Persistent Memory)

When the player starts a "New Game", we want to reset the chessboard, active turns, and scores. However, resetting the difficulty would be frustrating!
To retain settings within a session, we simply omit `selectedDifficulty` from the `resetGame()` cleanups. Tapping New Game retains the previously selected difficulty.

---

## 4. Pre-Game Hiding (Hard Mode)

Hard Mode hides pieces "from move 1" (threshold is `0`).
At move `0` (before any moves are played), `currentMoves (0) >= threshold (0)`. So the pieces are invisible from the start!
Because our `onTap` hit-testing evaluates coordinates against the engine (which is fully populated from move 0), the player can successfully tap hidden squares (like E2 -> E4) to start the game!

---

Congratulations on completing Milestone 3! Blindfold mode is now extremely flexible and fully playable!
