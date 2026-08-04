# Day 48 Documentation: Online Game Statistics & Achievements Integration

This document outlines the changes made to integrate online blindfold games against Lichess bots with the existing local Statistics and Achievements systems.

## 1. Statistics Model Extensions
The existing `StatisticsService` has been extended to track online statistics side-by-side with local stats:
* **SharedPreferences Keys**:
  * `stats_online_games`: Number of online games played.
  * `stats_online_blindfold_games`: Number of online blindfold games played.
* **Fields & Methods**:
  * Track variables loaded from persistence during `loadStats()`.
  * Clean up and reset online variables inside `clearStats()`.
  * `recordGame` signature updated to accept an `isOnline` flag. When `isOnline` is true, both total stats (wins, draws, blindfold wins, highest accuracy, fastest wins) and online-specific counts are updated and persisted to `SharedPreferences`.

## 2. Stream-Level End Detection & Abort Filtering
In `LiveGameScreen`, game outcomes are parsed dynamically from the Lichess game stream:
* **Event Handlers**:
  * Listens to the `gameFull` and `gameState` stream payloads.
  * Extracts the terminal `status` and, if available, `winner`.
* **State Gating**:
  * Introduces `_isGameStatsRecorded` boolean flag to ensure stats are logged exactly once per unique game session.
  * Excludes `aborted` or `noStart` events as game completions.
  * Safe-guards against screen exits: navigating away or popping the screen mid-game does not count as a completed game, and does not record stats.

## 3. UI Presentation
In `StatsScreen`, two new display tiles are added under the "Memory Performance" section:
* **Online Games Played**: Displays total online bot games played.
* **Online Blindfold Games**: Displays total online bot games played specifically in blindfold mode.

## 4. Test Suite Additions
A comprehensive set of unit and integration tests was added to `test/lichess_test.dart` to verify the new behaviors:
1. **Completed Checkmate Event**: Asserts that a checkmate stream payload correctly updates and increments all local, online, and blindfold stats.
2. **Aborted Game Exclusion**: Asserts that aborted game events do not alter statistics in any way.
3. **Mid-Game Exit Exclusion**: Asserts that navigating away or popping the screen before game completion does not write stats.
4. **Achievements Integration**: Asserts that a perfect online blindfold game unlocks achievements (e.g. `Perfectionist` and `Mind's Eye`) and registers them dynamically on the Stats/Achievements UI screen.
5. **Local-Online Isolation**: Asserts that recording local and online games side-by-side works correctly and updates both statistics namespaces without collision.
