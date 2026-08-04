import 'package:shared_preferences/shared_preferences.dart';

/// Service in charge of loading, recording, and updating game statistics.
///
/// [Win/Loss outcome color model]
/// Since both players sit face-to-face and share the device (local 2-player pass-and-play),
/// outcomes are tracked strictly by side colors: White Wins, Black Wins, and Draws.
///
/// [Average Accuracy calculation]
/// We compute a simple average of per-game percentages (sum of accuracies divided by
/// total Blindfold games played) to prevent skewing from long games.
///
/// [Fewest moves checkmate definition]
/// We track fastest checkmate by half-move count (count of total elements in game move history).
class StatisticsService {
  // Singleton pattern instantiation
  static final StatisticsService instance = StatisticsService._internal();
  StatisticsService._internal();

  // Storage keys constants
  static const String _keyTotalGames = 'stats_total_games';
  static const String _keyWhiteWins = 'stats_white_wins';
  static const String _keyBlackWins = 'stats_black_wins';
  static const String _keyDraws = 'stats_draws';
  static const String _keyHighestMemoryScore = 'stats_highest_memory_score';
  static const String _keyTotalBlindfoldGames = 'stats_total_blindfold_games';
  static const String _keySumMemoryAccuracies = 'stats_sum_memory_accuracies';
  static const String _keyFastestWinHalfMoves = 'stats_fastest_win_half_moves';
  static const String _keyCurrentStreak = 'stats_current_streak';
  static const String _keyLastPlayedDate = 'stats_last_played_date';
  static const String _keyBlindfoldWins = 'stats_blindfold_wins';
  static const String _keyOnlineGames = 'stats_online_games';
  static const String _keyOnlineBlindfoldGames = 'stats_online_blindfold_games';

  // In-memory stats cache
  int totalGamesPlayed = 0;
  int whiteWins = 0;
  int blackWins = 0;
  int draws = 0;
  int highestMemoryScore = 0;
  int totalBlindfoldGamesPlayed = 0;
  double sumMemoryAccuracies = 0.0;
  int? fastestWinHalfMoves; // null represents no checkmate achieved yet
  int currentStreak = 0;
  String? lastPlayedDate;
  int blindfoldWins = 0;
  int onlineGamesPlayed = 0;
  int onlineBlindfoldGamesPlayed = 0;

  double get averageMemoryAccuracy {
    if (totalBlindfoldGamesPlayed == 0) return 0.0;
    return sumMemoryAccuracies / totalBlindfoldGamesPlayed;
  }

  /// Loads all statistics from local SharedPreferences storage.
  Future<void> loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    totalGamesPlayed = prefs.getInt(_keyTotalGames) ?? 0;
    whiteWins = prefs.getInt(_keyWhiteWins) ?? 0;
    blackWins = prefs.getInt(_keyBlackWins) ?? 0;
    draws = prefs.getInt(_keyDraws) ?? 0;
    highestMemoryScore = prefs.getInt(_keyHighestMemoryScore) ?? 0;
    totalBlindfoldGamesPlayed = prefs.getInt(_keyTotalBlindfoldGames) ?? 0;
    sumMemoryAccuracies = prefs.getDouble(_keySumMemoryAccuracies) ?? 0.0;
    fastestWinHalfMoves = prefs.getInt(_keyFastestWinHalfMoves);
    if (fastestWinHalfMoves == 0) {
      fastestWinHalfMoves = null; // Guard zero values
    }
    currentStreak = prefs.getInt(_keyCurrentStreak) ?? 0;
    lastPlayedDate = prefs.getString(_keyLastPlayedDate);
    blindfoldWins = prefs.getInt(_keyBlindfoldWins) ?? 0;
    onlineGamesPlayed = prefs.getInt(_keyOnlineGames) ?? 0;
    onlineBlindfoldGamesPlayed = prefs.getInt(_keyOnlineBlindfoldGames) ?? 0;
  }

  /// Records a completed game outcome and commits changes immediately to storage.
  Future<void> recordGame({
    required bool isDraw,
    String? winningColor, // 'white', 'black', or null if draw
    bool isCheckmate = false,
    int halfMoves = 0,
    bool isBlindfoldModeActive = false,
    int? memoryScorePercentage, // 0 to 100, or null
    bool isOnline = false,
  }) async {
    totalGamesPlayed++;

    if (isOnline) {
      onlineGamesPlayed++;
    }

    if (isDraw) {
      draws++;
    } else if (winningColor == 'white') {
      whiteWins++;
    } else if (winningColor == 'black') {
      blackWins++;
    }

    if (isCheckmate && halfMoves > 0) {
      if (fastestWinHalfMoves == null || halfMoves < fastestWinHalfMoves!) {
        fastestWinHalfMoves = halfMoves;
      }
    }

    if (isBlindfoldModeActive && memoryScorePercentage != null) {
      totalBlindfoldGamesPlayed++;
      sumMemoryAccuracies += memoryScorePercentage;
      if (memoryScorePercentage > highestMemoryScore) {
        highestMemoryScore = memoryScorePercentage;
      }
      if (winningColor != null) {
        blindfoldWins++;
      }
      if (isOnline) {
        onlineBlindfoldGamesPlayed++;
      }
    }

    // Daily Streak update logic using local device midnights converted to UTC (bypassing DST offsets)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    if (lastPlayedDate == null) {
      currentStreak = 1;
    } else {
      final lastDate = DateTime.tryParse(lastPlayedDate!);
      if (lastDate != null) {
        final utcToday = DateTime.utc(today.year, today.month, today.day);
        final utcLast = DateTime.utc(
          lastDate.year,
          lastDate.month,
          lastDate.day,
        );
        final diffDays = utcToday.difference(utcLast).inDays;

        if (diffDays == 1) {
          currentStreak++;
        } else if (diffDays > 1) {
          currentStreak = 1;
        }
        // if diffDays == 0 (same day), streak remains unchanged
      } else {
        currentStreak = 1;
      }
    }
    lastPlayedDate = todayStr;

    // Persist to local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTotalGames, totalGamesPlayed);
    await prefs.setInt(_keyWhiteWins, whiteWins);
    await prefs.setInt(_keyBlackWins, blackWins);
    await prefs.setInt(_keyDraws, draws);
    await prefs.setInt(_keyHighestMemoryScore, highestMemoryScore);
    await prefs.setInt(_keyTotalBlindfoldGames, totalBlindfoldGamesPlayed);
    await prefs.setDouble(_keySumMemoryAccuracies, sumMemoryAccuracies);
    await prefs.setInt(_keyCurrentStreak, currentStreak);
    if (lastPlayedDate != null) {
      await prefs.setString(_keyLastPlayedDate, lastPlayedDate!);
    }
    await prefs.setInt(_keyBlindfoldWins, blindfoldWins);
    if (fastestWinHalfMoves != null) {
      await prefs.setInt(_keyFastestWinHalfMoves, fastestWinHalfMoves!);
    }
    await prefs.setInt(_keyOnlineGames, onlineGamesPlayed);
    await prefs.setInt(_keyOnlineBlindfoldGames, onlineBlindfoldGamesPlayed);
  }

  /// Reset all stored statistics (useful for tests and user cleanup).
  Future<void> clearStats() async {
    totalGamesPlayed = 0;
    whiteWins = 0;
    blackWins = 0;
    draws = 0;
    highestMemoryScore = 0;
    totalBlindfoldGamesPlayed = 0;
    sumMemoryAccuracies = 0.0;
    fastestWinHalfMoves = null;
    currentStreak = 0;
    lastPlayedDate = null;
    blindfoldWins = 0;
    onlineGamesPlayed = 0;
    onlineBlindfoldGamesPlayed = 0;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyTotalGames);
    await prefs.remove(_keyWhiteWins);
    await prefs.remove(_keyBlackWins);
    await prefs.remove(_keyDraws);
    await prefs.remove(_keyHighestMemoryScore);
    await prefs.remove(_keyTotalBlindfoldGames);
    await prefs.remove(_keySumMemoryAccuracies);
    await prefs.remove(_keyFastestWinHalfMoves);
    await prefs.remove(_keyCurrentStreak);
    await prefs.remove(_keyLastPlayedDate);
    await prefs.remove(_keyBlindfoldWins);
    await prefs.remove(_keyOnlineGames);
    await prefs.remove(_keyOnlineBlindfoldGames);
  }
}
