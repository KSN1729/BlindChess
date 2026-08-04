# Day 46 Implementation Notes: Blindfold Mode on Real Games

We wired the existing blindfold mechanics from local play into the `LiveGameScreen` to let the user play blindfolded against real opponents on Lichess.

## Key Changes
1. **Shared State Integration**: Sourced the Blindfold Mode toggle and Difficulty presets directly from the global `SettingsService.instance` singleton. Toggling settings in one screen automatically synchronizes settings across both local and live screens.
2. **Hiding Logic & Layout**:
   - Pieces are hidden visual-only (using the existing `shouldHidePieces` flag in `ChessBoard`) when blindfold is ON and the move threshold is reached.
   - The move count is dynamically driven by the true stream-parsed move count `_moveCount`.
   - Opponent details, clocks, status banner, connection lost alerts, and game control drawer buttons remain fully visible at all times.
3. **Interactive & Guessing Mechanics**:
   - When pieces are visually hidden, first taps on user's own pieces show legal move highlight destinations.
   - Tapping an empty square or an opponent piece registers a visual memory guess attempt, updating a temporary local Memory Score indicator and playing the incorrect guess feedback sound on error.
   - The **Reveal** button peeks at the true position for 3 seconds and is gated by a 10-move cooldown to preserve challenge integrity.
4. **Test Isolation**:
   - Added a `setUp` block to `widget_test.dart` and `lichess_test.dart` to reset `SettingsService` notifiers to default values before every single test scenario, preventing singleton state pollution.
5. **Widget Tests**:
   - Added 4 brand new integration tests in `test/lichess_test.dart` verifying all blindfold behaviors on `LiveGameScreen`.
   - All 85 tests in the suite pass successfully.
