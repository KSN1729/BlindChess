# Day 49 Notes: Voice Command Integration

Today we integrated voice commands into both local match and online live Lichess gameplay screens.

---

## 1. Speech Recognition Package
We selected **`speech_to_text: ^7.3.0`** (which resolved to version `7.4.0` in the lockfile) because it is the most popular, stable, and actively-maintained plugin that interfaces with native system-level speech recognition APIs on both Android and iOS.

### Android Permission & Configuration Setup
To grant the application required microphone and package visibility permissions, the following declarations were configured in [AndroidManifest.xml](file:///c:/FlutterProjects/BlindChess/android/app/src/main/AndroidManifest.xml):
* `<uses-permission android:name="android.permission.RECORD_AUDIO" />`
* `<uses-permission android:name="android.permission.INTERNET" />`
* A `<queries>` entry for `android.speech.RecognitionService` to resolve recognition packages on Android 11+.

To isolate native platform channels in testing, we defined `SpeechService` as an abstract class (instantiated with `RealSpeechService` in production and `MockSpeechService` in tests).

---

## 2. Supported Command Vocabulary and Patterns

`VoiceCommandParser` parses natural speech inputs, normalizes spelling/spoken numbers, and queries the rules engine's legal verbose moves list to find the single matching target move. If a command is ambiguous or invalid, it returns `null` to prompt the user for clarification.

### Coordinate-Style Commands
* **Patterns**: `[from square] [to square]`, `[from square] to [to square]`, `[from square] [to square] [promotion piece]`
* **Examples**:
  - *"e2 e4"* -> `e2e4`
  - *"e2 to e4"* -> `e2e4`
  - *"e7 to e8 queen"* -> `e7e8q`

### Piece & Destination Commands
* **Patterns**: `[piece name] [destination square]`, `[piece name] takes [destination square]`, `[piece name] to [destination square]`
* **Pieces supported**: `knight`, `night`, `horse` -> `n`; `bishop` -> `b`; `rook`, `castle` -> `r`; `queen` -> `q`; `king` -> `k`; default to pawn `p`
* **Examples**:
  - *"knight f3"* -> `Nf3`
  - *"bishop takes c4"* -> `Bxc4`
  - *"pawn to e4"* -> `e4`

### Castling Commands
* **Patterns**: `castle kingside`, `short castle`, `castle queenside`, `long castle`
* **Examples**:
  - *"castle kingside"* -> `O-O`
  - *"long castle"* -> `O-O-O`

---

## 3. Integration & Move Routing

* **UI Element**: `VoiceCommandWidget` displays a premium animated circular mic button with a purple pulsing outer circle glow during active listening. It temporarily renders the raw recognized text between quotes inside an `AnimatedSwitcher` to give immediate visual feedback.
* **Turn Gating**: Active in both screens; on the live Lichess screen, the microphone is disabled unless it is the user's active turn.
* **Move Execution**:
  - **Local Match**: Passes matched moves directly to `chessEngineService.makeMove(fromRow, fromFile, toRow, toFile, promotion: promotion)` in [game_screen.dart](file:///c:/FlutterProjects/BlindChess/lib/screens/game_screen.dart).
  - **Live Lichess Match**: Submits matched moves directly to `_transmitMove(fromRow, fromFile, toRow, toFile, promotion: promotion)` in [live_game_screen.dart](file:///c:/FlutterProjects/BlindChess/lib/screens/live_game_screen.dart), using the exact same Optimistic UI updates and error handling as tapped moves.
