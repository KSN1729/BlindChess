# Day 43 Notes: Send Moves to Lichess API

This document details the move-sending implementation for Live Lichess Games in the BlindChess application.

## 1. Move Transmission API

- **Endpoint**: `POST https://lichess.org/api/board/game/{gameId}/move/{move}`
- **Headers**:
  - `Authorization: Bearer <token>`
  - `User-Agent: BlindChess/1.0.0 (contact: support@blindchess.org)`
- **HTTP Success Status Codes**: `200` or `204` represents success.
- **HTTP Failure Status Codes**: Non-2xx codes represent errors (e.g. `400 Bad Request` if illegal move or not the user's turn). These are thrown as Exceptions with the Lichess-provided error string or the HTTP status code, then caught in the UI to notify the user.

## 2. UCI Format & Promotion Suffix

Moves are transmitted in **Universal Chess Interface (UCI)** notation:
- Format: `{fromSquare}{toSquare}[promotion]`
- Examples:
  - Standard move: `"e2e4"`
  - Castling (represented by king move): `"e1g1"` (White kingside castling)
  - Promotion: pawn moves to back rank, appending the chosen piece type symbol in lowercase:
    - `"e7e8q"` (Queen promotion)
    - `"e7e8r"` (Rook promotion)
    - `"e7e8b"` (Bishop promotion)
    - `"e7e8n"` (Knight promotion)

## 3. Turn Gating via Stream State

The user is only allowed to select squares and make moves when it is genuinely their turn. The `isMyTurn` property is calculated dynamically in the UI:
```dart
final isMyTurn = !_isLoading &&
    !_connectionLost &&
    !_gameStatus.startsWith('Game Over') &&
    _chessEngineService.activeTurn == _playerColor;
```
The board is set to `readOnly: !isMyTurn || _isSendingMove`. Tapping squares is disabled during the opponent's turn or when a move is already in flight.

## 4. Client-side Legality Checking

Before making any HTTP request to the Lichess API, the app validates the legality of the move:
1. **Piece Selection**: Only pieces belonging to the current player can be tapped and selected.
2. **Move Highlights**: Selecting a piece calls `_chessEngineService.legalDestinationsFrom(row, col)`, highlighting legal destination coordinates on the board.
3. **Move Execution**: A move is only attempted if the destination square falls within those highlighted destinations. If not, the move is rejected client-side immediately, and no network requests are sent.
