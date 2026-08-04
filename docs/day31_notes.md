# Day 31 Design Notes: Daily Streak & Achievement Badges

## Local Date vs UTC for Streak Calculations

### The Decision: Local Date
For a Daily Streak retention hook, comparing dates using UTC time can result in unexpected resets. For example, if a player in a timezone like GMT+10 plays a game in their morning (e.g., 9:00 AM local time, which is 11:00 PM UTC of the previous day) and then plays a game the next local day in their evening (e.g., 8:00 PM local time, which is 10:00 AM UTC of the same local day), the UTC dates would match or jump unexpectedly.

Using the **device's local calendar date** matches the player's cognitive definition of a "day." They expects the streak to continue if they play a game on consecutive calendar dates in their local timezone.

### DST Offset Mitigation
Subtracting local date-times directly (`DateTime.difference()`) calculates raw 24-hour durations. When a Daylight Saving Time (DST) change occurs, a calendar day might be 23 or 25 hours long, causing a difference check on consecutive local days to yield `inDays == 0` or `inDays == 2` respectively.
To prevent this:
1. We construct local midnight `DateTime` objects for today and the last played date:
   `DateTime today = DateTime(now.year, now.month, now.day);`
2. We map both dates to UTC:
   `final utcToday = DateTime.utc(today.year, today.month, today.day);`
   `final utcLast = DateTime.utc(lastDate.year, lastDate.month, lastDate.day);`
3. We take the difference in UTC days:
   `final diffDays = utcToday.difference(utcLast).inDays;`

Since UTC has no DST rules, this is guaranteed to return exactly `1` day on consecutive calendar dates, protecting players from clock offsets.

---

## Achievement Badges

We implemented 7 badges derived dynamically from local stats:

| ID | Title | Description | Condition |
| --- | --- | --- | --- |
| `first_win` | First Win | Win your first local game. | `whiteWins + blackWins >= 1` |
| `minds_eye` | Mind's Eye | Win a game with Blindfold active. | `blindfoldWins >= 1` |
| `speed_demon` | Speed Demon | Win a game in 10 half-moves or fewer. | `fastestWinHalfMoves != null && fastestWinHalfMoves <= 10` |
| `perfectionist` | Perfectionist | Complete a Blindfold game with 100% memory accuracy. | `highestMemoryScore == 100 && totalBlindfoldGamesPlayed >= 1` |
| `marathoner` | Marathoner | Play 10 or more total games. | `totalGamesPlayed >= 10` |
| `consistent` | Consistent | Reach a daily streak of 3 or more days. | `currentStreak >= 3` |
| `both_sides` | Both Sides | Record at least one win for White and one win for Black. | `whiteWins >= 1 && blackWins >= 1` |
