import 'package:shared_preferences/shared_preferences.dart';

/// Service responsible for local game autosave persistence and state restoration.
class GamePersistenceService {
  static final GamePersistenceService instance = GamePersistenceService._internal();
  GamePersistenceService._internal();

  static const String _keyGameActive = 'persistence_game_active';
  static const String _keyFen = 'persistence_game_fen';
  static const String _keyUciMoves = 'persistence_game_uci_moves';
  static const String _keySanMoves = 'persistence_game_san_moves';
  static const String _keyWhiteTime = 'persistence_game_white_time_ms';
  static const String _keyBlackTime = 'persistence_game_black_time_ms';
  static const String _keyClockLabel = 'persistence_game_clock_label';
  static const String _keyClockBaseSeconds = 'persistence_game_clock_base_seconds';
  static const String _keyClockIncrementSeconds = 'persistence_game_clock_increment_seconds';
  static const String _keyClockHasTimer = 'persistence_game_clock_has_timer';
  static const String _keyCurrentMoveIndex = 'persistence_game_current_move_index';

  /// Saves the active game session to local storage.
  Future<void> saveGame({
    required String fen,
    required List<String> uciMoves,
    required List<String> sanMoves,
    required int whiteTimeMs,
    required int blackTimeMs,
    required String clockLabel,
    required int clockBaseSeconds,
    required int clockIncrementSeconds,
    required bool clockHasTimer,
    required int currentMoveIndex,
    required bool gameActive,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyGameActive, gameActive);
    await prefs.setString(_keyFen, fen);
    await prefs.setStringList(_keyUciMoves, uciMoves);
    await prefs.setStringList(_keySanMoves, sanMoves);
    await prefs.setInt(_keyWhiteTime, whiteTimeMs);
    await prefs.setInt(_keyBlackTime, blackTimeMs);
    await prefs.setString(_keyClockLabel, clockLabel);
    await prefs.setInt(_keyClockBaseSeconds, clockBaseSeconds);
    await prefs.setInt(_keyClockIncrementSeconds, clockIncrementSeconds);
    await prefs.setBool(_keyClockHasTimer, clockHasTimer);
    await prefs.setInt(_keyCurrentMoveIndex, currentMoveIndex);
  }

  /// Clears the saved game session.
  Future<void> clearSavedGame() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyGameActive);
    await prefs.remove(_keyFen);
    await prefs.remove(_keyUciMoves);
    await prefs.remove(_keySanMoves);
    await prefs.remove(_keyWhiteTime);
    await prefs.remove(_keyBlackTime);
    await prefs.remove(_keyClockLabel);
    await prefs.remove(_keyClockBaseSeconds);
    await prefs.remove(_keyClockIncrementSeconds);
    await prefs.remove(_keyClockHasTimer);
    await prefs.remove(_keyCurrentMoveIndex);
  }

  /// Checks if there is an active unfinished game session saved.
  Future<bool> hasSavedGame() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyGameActive) ?? false;
  }

  /// Restores the saved game session. Returns a map of saved configurations.
  Future<Map<String, dynamic>?> restoreGame() async {
    final prefs = await SharedPreferences.getInstance();
    final gameActive = prefs.getBool(_keyGameActive) ?? false;
    if (!gameActive) return null;

    final fen = prefs.getString(_keyFen) ?? '';
    final uciMoves = prefs.getStringList(_keyUciMoves) ?? [];
    final sanMoves = prefs.getStringList(_keySanMoves) ?? [];
    final whiteTimeMs = prefs.getInt(_keyWhiteTime) ?? 0;
    final blackTimeMs = prefs.getInt(_keyBlackTime) ?? 0;
    final clockLabel = prefs.getString(_keyClockLabel) ?? '';
    final clockBaseSeconds = prefs.getInt(_keyClockBaseSeconds) ?? 0;
    final clockIncrementSeconds = prefs.getInt(_keyClockIncrementSeconds) ?? 0;
    final clockHasTimer = prefs.getBool(_keyClockHasTimer) ?? false;
    final currentMoveIndex = prefs.getInt(_keyCurrentMoveIndex) ?? -1;

    return {
      'fen': fen,
      'uciMoves': uciMoves,
      'sanMoves': sanMoves,
      'whiteTimeMs': whiteTimeMs,
      'blackTimeMs': blackTimeMs,
      'clockLabel': clockLabel,
      'clockBaseSeconds': clockBaseSeconds,
      'clockIncrementSeconds': clockIncrementSeconds,
      'clockHasTimer': clockHasTimer,
      'currentMoveIndex': currentMoveIndex,
    };
  }
}
