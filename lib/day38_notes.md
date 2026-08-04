# Day 38 Developer Notes: Lichess Profile — Full Stats

## What Changed & Why

To provide a richer online play dashboard, we extended our Lichess integration to display the player's lifetime game counts:
- Total Games Played
- Lifetime Wins
- Lifetime Losses
- Lifetime Draws

## Endpoint & Fields Used

- **Endpoint called**: `GET https://lichess.org/api/account`
- **Fields extracted**:
  - `count.all` -> Total games played.
  - `count.win` -> Games won.
  - `count.loss` -> Games lost.
  - `count.draw` -> Games drawn.

---

## Technical Implementations

1. **OAuth Scopes Conservation**:
   - Our research validated that the Lichess `/api/account` profile endpoint (which we already call to fetch username and rating details) **already returns the `count` nested statistics block**.
   - No new scopes were requested (preserving existing scopes: `board:play challenge:write challenge:read`). Therefore, existing authenticated sessions remain valid and users will not be forced to log in again.
2. **Local Caching (Offline First)**:
   - To adhere to our offline-first core architecture, stats are cached inside `SharedPreferences` keys:
     - `lichess_games_played`
     - `lichess_wins`
     - `lichess_losses`
     - `lichess_draws`
   - When the app is opened, these values are loaded instantly from the cache to avoid empty layout layout jumps, then refreshed asynchronously when the background API call resolves.
3. **UI Layout Updates**:
   - Extended the Lichess Companion container card on the home screen to display:
     - `Games: {count}`
     - `Record: {win}W / {loss}L / {draw}D`
4. **Mock Testing**:
   - Added unit tests validating statistics parsing, caching persistence, and cached startup checks.
