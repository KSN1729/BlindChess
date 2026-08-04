# Day 39 - Lichess Recent Games List & PGN Viewer Specifications

## Endpoint and Query Parameters Used
1. **Recent Games Export Endpoint**:
   - **Method**: `GET`
   - **URL**: `https://lichess.org/api/games/user/{username}`
   - **Query Parameters**:
     - `max=15` (to retrieve only the most recent 15 games).
   - **Headers**:
     - `Accept: application/x-ndjson` (to request Newline Delimited JSON).
     - `Authorization: Bearer <access_token>` (for authenticated user limits).
     - `User-Agent: BlindChess/1.0.0 (contact: support@blindchess.org)`

2. **Single Game Export Endpoint (PGN)**:
   - **Method**: `GET`
   - **URL**: `https://lichess.org/api/game/{gameId}`
   - **Headers**:
     - `Accept: application/x-chess-pgn` (to export the raw PGN text directly).
     - `Authorization: Bearer <access_token>` (for authenticated user limits).
     - `User-Agent: BlindChess/1.0.0 (contact: support@blindchess.org)`

---

## Response Format & Parsing Strategy
- **Format**: The export user games endpoint returns **NDJSON (Newline Delimited JSON)** by default when requesting `application/x-ndjson`.
- **Parsing**:
  - We did not use a simple `jsonDecode()` on the entire response body, as that would throw a formatting error (since NDJSON contains multiple JSON objects separated by newlines instead of an enclosing array).
  - Instead, the raw response text is split on `\n` (newlines).
  - Every non-empty line is parsed individually as its own JSON map (`json.decode(line)`), and passed to the model factory `LichessGame.fromJson(gameJson, currentUsername)`.

---

## Lazy vs. Inline PGN Decision
- **Decision**: **Lazy Loading (On-Demand)**.
- **Rationale**:
  - A game's PGN contains long lines of move records, clocks, names, and variations.
  - Eagerly fetching PGNs inline for 15 games on the initial screen load increases payload size significantly and wastes mobile data.
  - Staggering queries or requesting heavy objects beforehand is less performant and runs a risk of triggering Lichess API rate-limiting blocks.
  - **Implementation**:
    - The initial games list request only fetches basic info (opponent, date, result, color, game ID) without PGN data.
    - When a user taps on a game tile in the list, the app retrieves the PGN string lazily using `GET /api/game/{gameId}` with `Accept: application/x-chess-pgn`.
    - Once loaded, the PGN is cached in the `LichessGame.pgn` memory reference. Subsequent taps display the cached PGN instantly without refetching from the network, providing an optimal rate-limit safe user experience.
