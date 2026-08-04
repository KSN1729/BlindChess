# Day 47 Implementation Notes: Pre-configured Blindfold Entry Points

We integrated a first-class pre-configured entry path for starting blindfold games vs Lichess bots.

## Entry Points Added
1. **"Blindfold vs Bot" Button**:
   - Added as a clear, discoverable button below the existing "Play Lichess Bot" button on the authenticated Home Screen layout (`home_screen.dart`).
   - Triggering this opens the shared `ChallengeBotDialog` with `startWithBlindfold: true`.
2. **Challenge Dialog Integration**:
   - Extended `ChallengeBotDialog` to conditionally display a "Blindfold Mode" toggle switch (pre-selected to ON if starting from the blindfold button).
   - If checked, the dialog renders the Easy / Medium / Hard difficulty chips, letting the user customize the hide threshold before creation.
   - Successful bot challenge pushes `LiveGameScreen` passing `initialBlindfoldMode` and `initialBlindfoldDifficulty`.
3. **Live Game Synchronization**:
   - The `LiveGameScreen` parses initial constructor arguments and writes them immediately to the global `SettingsService.instance` singleton in `initState()`, causing pieces to hide automatically from the start.
   - The regular "Play Lichess Bot" flow defaults to blindfold OFF.
   - The manual toggle switch inside the live board screen remains fully active for mid-game overrides.

## Honest Status of "vs Online Opponent"
- **Explicitly Deferred / Not Built**: Quick pairing/matchmaking vs online human opponents is **not implemented** in the current service layer because the Lichess API explicitly forbids third-party companion apps from participating in the official human quick pairing lobbies (matchmaking pools) to prevent bot cheating and ensure platform integrity.
- Therefore, we only offer **"Blindfold vs Bot"** challenges. Matchmaking/challenging specific custom user handles is deferred as it requires a dedicated username invite interface and inbound invitation listener inbox, which are outside the scope of current milestone features.
