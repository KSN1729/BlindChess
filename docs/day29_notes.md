# Day 29: Statistics Screen, Out-of-the-Box Local Persistence Notes

Welcome to Day 29! Today, we built local statistics persistence and a beautiful Statistics dashboard screen using the `shared_preferences` package.

---

## 1. Important Design Decision: Outcome Tracking by Color

Because this is a pass-and-play local 2-player game sharing a single device and save file, "Wins/Losses" are tracked by color side (**White Wins**, **Black Wins**, **Draws**). We do not record standard "user wins/losses" since there is no concept of a single logged-in user.

---

## 2. Average Accuracy Calculation

We compute the average memory accuracy across games as a **simple average of per-game percentages** rather than a weighted average of guesses:
- **Sum of Accuracies**: We store the total sum of all per-game percentages.
- **Completed Games**: We track the total number of completed Blindfold games.
- **Formula**: `averageMemoryAccuracy = sumMemoryAccuracies / totalBlindfoldGamesPlayed`.
This avoids a single long game (e.g. 50 moves with many guesses) skewing the accuracy disproportionately over a short game (e.g. 10 moves).

---

## 3. Fastest Win Definition

Since there is no game clock in this app, we define the "fastest" win by the **fewest total half-moves** (total length of the game move history list) to reach checkmate. This is a single overall record shared by either color.

---

## 4. Local Persistence Key Layout

We store statistics inside `shared_preferences` using key-value pairs:
* `stats_total_games` (int): Total completed games.
* `stats_white_wins` (int): Games won by White.
* `stats_black_wins` (int): Games won by Black.
* `stats_draws` (int): Games ending in stalemates or other draws.
* `stats_highest_memory_score` (int): Highest accuracy percentage recorded.
* `stats_total_blindfold_games` (int): Count of completed Blindfold games.
* `stats_sum_memory_accuracies` (double): Sum of memory accuracy percentages.
* `stats_fastest_win_half_moves` (int): Minimum move count to reach checkmate.

Writing updates to the disk is triggered **only at game completion** (not on every move) to prevent excessive disk read/write overhead.

---

## 5. Mocking Persistence in Flutter Tests

In Flutter tests, `shared_preferences` cannot read/write to the physical disk. We mock it in unit/widget tests by calling:
```dart
SharedPreferences.setMockInitialValues({
  'stats_total_games': 5,
  'stats_white_wins': 3,
  'stats_black_wins': 2,
});
```
This primes the cache with preset values so our services load them immediately.
