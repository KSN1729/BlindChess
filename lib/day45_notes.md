# Day 45: Resign, Draw & Abort Actions Specifications

This document outlines the API endpoints, rules, and UI integration details for resigning, draw offers/responses, and aborting a live game.

---

## 1. Confirmed Lichess Board API Endpoints

All actions are triggered using standard HTTP `POST` requests and require a valid OAuth2 token:
*   **Resign**: `POST /api/board/game/{gameId}/resign`
    *   Forfeits the game immediately, resulting in a loss.
*   **Abort**: `POST /api/board/game/{gameId}/abort`
    *   Cancels the game without any result (no rating change).
*   **Draw Offer/Response**: `POST /api/board/game/{gameId}/draw/{accept}`
    *   `{accept}` parameter in the URL path is **`yes`** or **`no`**:
        *   `yes` is used to send a draw offer or to accept a pending offer from the opponent.
        *   `no` is used to decline a pending draw offer.

---

## 2. Abort Validity Condition

*   **Rule**: Aborting a game is only valid before the game has fully started. On Lichess, once Black makes their first move, the game is started and aborting is no longer valid (must either resign or draw).
*   **Implementation**: The actions menu only displays/enables the **Abort Game** option if `_moveCount < 2`. Once Black plays their first move (`_moveCount >= 2`), the Abort option is completely removed from the action items.

---

## 3. Draw Offer vs. Response UI Distinction

We monitor the live NDJSON stream for standing draw offers:
*   **Stream Flags**: We parse `wdraw` and `bdraw` boolean fields (from `gameFull`'s nested `state` or top-level properties on `gameState` packets).
*   **Evaluation**: If the opponent has offered a draw (e.g. `bdraw == true` when playing as White), `_opponentDrawOffered` becomes `true`.
*   **UI Presentation**:
    *   If `_opponentDrawOffered` is `false`: the options menu shows a single option: **Offer Draw** (calls `/draw/yes`).
    *   If `_opponentDrawOffered` is `true`: the options menu switches to show two options: **Accept Draw** (calls `/draw/yes`) and **Decline Draw** (calls `/draw/no`).
