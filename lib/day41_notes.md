# Lichess AI Challenge API Specification (Day 41 Notes)

This document details the HTTP specifications of the Lichess challenge AI endpoint, which is used to play chess against the Stockfish computer engine.

---

## 1. Request Specification

* **Endpoint**: `POST https://lichess.org/api/challenge/ai`
* **Content-Type**: `application/x-www-form-urlencoded`
* **Authorization Header**: `Authorization: Bearer <OAuth_Access_Token>`

### Request Parameters (URL-Encoded Body)
| Parameter Name | Type | Allowed Values | Description |
| :--- | :--- | :--- | :--- |
| `level` | `int` | `1` to `8` | Stockfish difficulty level. |
| `clock.limit` | `int` | Positive integers (seconds) | Initial time control budget. Required if `clock.increment` is sent. Cannot be sent if `days` is used. |
| `clock.increment` | `int` | Non-negative integers (seconds) | Time increment added per move. Required if `clock.limit` is sent. |
| `color` | `string` | `'white'`, `'black'`, `'random'` | Preference for side color assignment. |
| `variant` | `string` | `'standard'`, etc. | Chess rules variant. Standard is standard chess rules. |
| `fen` | `string` | Valid FEN string | Custom initial position. Only supported for the standard variant. |

*Note: For the scope of our implementation, we enforce `variant=standard`.*

---

## 2. Response Specification

### Successful Response (HTTP 200 OK)
Returns a JSON object detailing the created game/challenge.

#### JSON Body Schema Example
```json
{
  "id": "q7ZvsdUF",
  "rated": false,
  "variant": "standard",
  "speed": "blitz",
  "perf": "blitz",
  "url": "https://lichess.org/q7ZvsdUF",
  "status": "created"
}
```

#### Key Fields to Parse
* `id` (`string`): The unique game ID used to stream board events and send moves in subsequent milestones.
* `url` (`string`): The game URL on lichess.org.
* `speed` (`string`): Categorized speed (e.g. `'bullet'`, `'blitz'`, `'rapid'`, `'classical'`) derived by the server from clock values.
* `perf` (`string`): Performance rating type (e.g. `'blitz'`).

### Failed Response (HTTP 400 Bad Request / 401 Unauthorized)
Returns a JSON object indicating the reason for failure.

#### JSON Body Schema Example (HTTP 400)
```json
{
  "error": "The level parameter must be between 1 and 8."
}
```
