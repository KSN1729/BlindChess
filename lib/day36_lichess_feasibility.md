# Lichess API Feasibility Research Report

This report evaluates the technical feasibility of integrating Lichess as an online play companion for BlindChess, detailing authentication, gameplay interfaces, compliance constraints, and scope recommendations.

---

## 1. Authentication (OAuth2 with PKCE)

### OAuth2 Flow for Mobile Apps
Lichess does not support client secrets for public clients like mobile applications because a secret cannot be kept confidential in compiled client binaries. Therefore, a secure **OAuth2 with PKCE (Proof Key for Code Exchange)** flow is required:

1. **Generate Cryptographic Keys**:
   - The app generates a cryptographically secure random string called the `code_verifier` (between 43 and 128 characters).
   - The app hashes this verifier using SHA-256 and base64url-encodes the output to create a `code_challenge`.
2. **Authorize via System Browser**:
   - The app directs the user to the Lichess authorization page (`https://lichess.org/oauth`) using the device's system browser (e.g. Custom Tabs on Android, `ASWebAuthenticationSession` on iOS). Embedded webviews are not recommended.
   - The query parameters include:
     - `response_type=code`
     - `client_id=blindchess` (an identifier we choose)
     - `redirect_uri=blindchess://oauth-callback` (our custom URL scheme)
     - `scope=board:play challenge:write challenge:read`
     - `code_challenge_method=S256`
     - `code_challenge=YOUR_CODE_CHALLENGE`
     - `state=RANDOM_STATE_STRING` (to prevent CSRF attacks)
3. **App Redirect & Interception**:
   - Once the user grants permissions on Lichess, the browser redirects back to `blindchess://oauth-callback?code=AUTH_CODE&state=STATE`.
   - The app intercepts this custom URL scheme and retrieves the authorization `code`.
4. **Token Exchange**:
   - The app sends a `POST` request to Lichess (`https://lichess.org/api/token`) with the `code`, `client_id`, `redirect_uri`, `grant_type=authorization_code`, and the raw `code_verifier` in the request body.
   - Lichess hashes the `code_verifier`, checks if it matches the `code_challenge` sent in step 2, and returns a Bearer access token.

### Scopes Required
- `board:play`: Enables reading game streams and submitting moves using the Board API (intended for physical boards and third-party custom chess clients).
- `challenge:read`: Enables checking incoming game invites and challenge states.
- `challenge:write`: Enables sending, accepting, or declining challenges.
- `profile:read` (Optional/Implicit): To get basic user profiles, though public profile endpoints do not require scopes.

### App Registration
- **No Pre-Registration Needed**: Lichess allows public clients (like mobile apps) to use the OAuth2 flow with PKCE without registering beforehand or generating credentials on a developer console. You can freely choose your `client_id` (e.g. `blindchess`) and redirect URI, as long as you execute the flow with PKCE.

---

## 2. Playing Real Games (Board API)

### Matchmaking & Seeks
- **Direct Challenges**: The app can send direct invites to specific users or bot accounts via `POST /api/challenge/{username}`.
- **Bot Play**: Players can challenge any registered Lichess BOT account (e.g. `POST /api/challenge/LeelaChessZero`). Because bots are automated, they accept challenges programmatically and instantly.
- **Lobby Seeks**: The app can create a public "seek" (game offer) via `POST /api/board/seek`. This adds an entry in the open challenge lobby list on lichess.org where other human players can browse and click to accept it.
- **Matchmaking Pools (No Support)**: **Lichess does not allow third-party clients to join the official Quick Pairing pools** (e.g. the 3+0 blitz or 10+0 rapid queues). This pool matchmaking is restricted strictly to the official Lichess web/mobile clients to prevent bot abuse and coordinate pool fair play.

### Game Types and Ratings
- **Rated Games**: Board API matches can be configured as rated or casual (using the `rated` boolean query parameter on challenges/seeks).
- **Time Controls**: Standard real-time formats (Blitz, Rapid, Classical) and Correspondence are fully supported.
- **Variants**: Standard chess and variants (like Chess960 or King of the Hill) are supported.

### Real-Time Streaming & Moves
- **Streaming State**: During a game, the client connects to a persistent connection via `GET /api/board/game/stream/{gameId}`.
  - The stream uses Newline Delimited JSON (NDJSON).
  - The first chunk contains a `gameFull` object detailing the starting state, clocks, and moves history.
  - Subsequent updates are pushed in real-time as `gameState` objects whenever a move is played. It includes remaining clock values (`wc` and `bc` in seconds).
  - **No Delay for Players**: The player stream is real-time with zero delay (unlike the public observer stream `/api/stream/game/{id}` which is delayed by 3 moves to prevent cheating).
- **Move Submission**: Moves are submitted via `POST /api/board/game/{gameId}/move/{move}` using Standard Algebraic Notation or UCI coordinates (e.g. `e2e4` or `e7e8q` for promotion).

### Forbidden Behavior (Fair Play Policy)
- **Engine/Cheat Assistance**: Providing engine analysis, evaluation bars, move recommendations, or hints during an active game is strictly forbidden by the Lichess Fair Play Policy.
- **Detection**: Lichess employs automated statistical algorithms analyzing move correlation, timing metrics, and browser/app tab switching. Violating these rules will result in a permanent ban of the user's account.

---

## 3. Data Access

- **Fetch Profiles**: We can fetch public user ratings, game counts, and win/loss records using `GET /api/user/{username}`. No authentication or scopes are required for public profile lookups.
- **Fetch Game History**: We can export full game history, PGNs, and moves lists using `GET /api/games/user/{username}`. This is a public stream and does not require credentials.

---

## 4. Compliance & Constraints

- **Branding & Naming**:
  - The name "Lichess" cannot be used in a way that implies the app is an official client.
  - Naming the app "BlindChess for Lichess" is acceptable provided we include a prominent disclaimer: *"This is an unofficial third-party companion app for Lichess, not affiliated with or endorsed by Lichess.org."*
- **Rate Limiting**:
  - Lichess REST APIs are limited to approximately **1 request per second**.
  - Exceeding the rate limit returns an HTTP `429 Too Many Requests` status code.
  - Streaming APIs do not count against this REST limit, but are capped at **8 concurrent connections per IP address**.
- **User-Agent Identification**:
  - All HTTP requests to Lichess MUST include a descriptive `User-Agent` header (e.g. `BlindChess/1.0.0 (contact: support@blindchess.org)`) so that Lichess administrators can identify our app and contact us if rate limits or technical issues arise.

---

## 5. Recommended Scope for Milestone 7 Onward

Given that Lichess does not support Quick Pairing pool matchmaking for third-party clients, a realistic and compliant "online" feature set for BlindChess is proposed as follows:

1. **Play Against Lichess Bots**:
   - Present a curated list of active Lichess BOT accounts classified by difficulty rating.
   - The user selects a bot and time control, and the app programmatically challenges the bot and launches the real-time gameplay screen.
2. **Challenge a Friend**:
   - Let the user enter a Lichess username to send a direct challenge (with configurable time control and rating type).
   - Provide a basic interface to view active incoming invites, letting players accept them and join games.
3. **Lobby Seeks (Custom Public Games)**:
   - Allow the user to "Create a Public Seek" specifying time control, variant, and rated options.
   - The user waits on a lobby screen while the seek is published to Lichess. Once another human accepts the seek, the match starts.
4. **Blindfold Mode Overlay**:
   - The game screen will operate identically to our local v1 match: pieces hide based on the threshold move, and guesses/reveals are mapped to local memory states.
   - Guesses will only check local visualization memory states (revealing/guessing locally) without sending move coordinates to Lichess until the user commits their actual turn.
