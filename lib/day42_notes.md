# Lichess Live Game Stream Specification (Day 42 Notes)

This document details the HTTP streaming specification and resource lifecycle management for Lichess game state tracking.

---

## 1. Stream Endpoint

* **Endpoint**: `GET https://lichess.org/api/board/game/stream/{gameId}`
* **Authorization**: `Bearer <OAuth_Access_Token>`
* **Accept**: `application/x-ndjson`

---

## 2. Event Types & NDJSON Payload Schema

Lichess streams events as newline-delimited JSON (NDJSON) lines. The server sends a keep-alive empty line (`\n`) every few seconds to prevent proxy timeouts.

### A. First Event: `gameFull`
Pushed immediately upon establishing the HTTP connection. Contains the complete initial layout, settings, and full players status.

```json
{
  "type": "gameFull",
  "id": "q7ZvsdUF",
  "rated": false,
  "variant": {
    "key": "standard",
    "name": "Standard"
  },
  "speed": "blitz",
  "perf": {
    "name": "Blitz"
  },
  "white": {
    "id": "player1",
    "name": "LichessUser",
    "rating": 1650
  },
  "black": {
    "id": "ai",
    "name": "Stockfish level 3",
    "rating": 1500
  },
  "state": {
    "type": "gameState",
    "moves": "e2e4 e7e5",
    "wtime": 180000,
    "btime": 178000,
    "status": "started"
  }
}
```

### B. Subsequent Events: `gameState`
Pushed whenever moves are executed, clock times shift, or status transitions occur.

```json
{
  "type": "gameState",
  "moves": "e2e4 e7e5 g1f3 b8c6",
  "wtime": 175000,
  "btime": 172000,
  "winc": 0,
  "binc": 0,
  "status": "started"
}
```

---

## 3. Stream Lifecycle Management

### A. Open (Lazy Listening)
Using `StreamController` and standard `HttpClient` connections:
1. `LichessService.instance.streamGameState(gameId)` returns a cold stream.
2. The HTTP connection is only established when a subscription begins (`onListen`).
3. It transforms the byte stream utilizing `utf8.decoder` and `LineSplitter()` to process NDJSON lines in real-time.

### B. Cancellation (Disposal & Clean-up)
* When the widget state is disposed, the `StreamSubscription` is explicitly canceled (`_streamSubscription?.cancel()`).
* Under the hood, this triggers the `controller.onCancel` hook which terminates the TCP socket (`HttpClient.close(force: true)`). This prevents background memory and battery leaks.

### C. Reconnection Panel
* Sockets drop on network degradation. The stream catches connection drops (`onError`, `onDone`) and flags `_connectionLost = true`.
* The UI displays a "Connection Lost" card container, prompting the user with a manual "Reconnect" action. Clicking this attempts to re-subscribe and rebuild the NDJSON line pipeline.
