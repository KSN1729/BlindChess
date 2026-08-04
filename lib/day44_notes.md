# Day 44: Live Game Clock Sync Specifications

This document outlines the technical details and specifications for Day 44's chess clock synchronization implementation.

---

## 1. Stream Clock Fields

The Lichess NDJSON stream exposes player clock values inside two main event types. We extract remaining time using these fields:
* **`gameFull` Event (nested inside the `state` field)**:
  * `state['wtime']` (White's remaining time in milliseconds)
  * `state['btime']` (Black's remaining time in milliseconds)
* **`gameState` Event (top-level properties)**:
  * `event['wtime']` (White's remaining time in milliseconds)
  * `event['btime']` (Black's remaining time in milliseconds)

*Note: Increment values are also included in the Lichess API (e.g. `winc`/`binc`), but we do not apply them manually since the server handles the clock calculations and pushes the post-move increments authoritatively.*

---

## 2. Reconciling Local Ticking with Server Updates

Because Lichess pushes clock snapshots periodically (usually only on moves or status transitions), the client implements a hybrid approach to ensure smooth ticking:

* **Cosmetic Local Ticking**: A periodic timer (`Timer.periodic` running every 100 milliseconds) actively decrements the remaining time of the player whose turn it currently is. The inactive player's time stays completely static.
* **Snap-to-Server Resync**: When a new `gameFull` or `gameState` event arrives with fresh clock states, the local variables (`_whiteTimeMs` and `_blackTimeMs`) immediately snap to the authoritative values sent by the server. This design completely eliminates time drift between server updates while keeping the UI responsive.
* **Disconnection Pauses**: When the NDJSON stream loses connection or enters a reconnect state (`_connectionLost = true`), the clock ticking is immediately paused, showing a grayed-out `"Paused"` message rather than ticking down on stale data.

---

## 3. Low-Time Warning Threshold

* **Threshold**: 30 seconds (`30000` milliseconds).
* **Rationale**: 30 seconds is the standard competitive threshold in blitz and rapid formats. When either player's remaining time drops below 30 seconds, their clock container changes to high-contrast red alert styling (red borders, red text color) to draw immediate attention.
