import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Difficulty level definitions for Blindfold Mode hiding.
enum BlindfoldDifficulty { easy, medium, hard }

/// Helper extension to map the hide threshold moves for each difficulty.
extension BlindfoldDifficultyExtension on BlindfoldDifficulty {
  int get hideThreshold {
    switch (this) {
      case BlindfoldDifficulty.easy:
        return 10;
      case BlindfoldDifficulty.medium:
        return 5;
      case BlindfoldDifficulty.hard:
        return 0;
    }
  }
}

/// Service in charge of storing and loading user settings.
class SettingsService {
  // Singleton pattern instantiation
  static final SettingsService instance = SettingsService._internal();
  SettingsService._internal();

  // Storage keys constants
  static const String _keyIsDarkMode = 'settings_is_dark_mode';
  static const String _keyBoardTheme = 'settings_board_theme';
  static const String _keyIsMuted = 'settings_is_muted';
  static const String _keyIsBlindfoldMode = 'settings_is_blindfold_mode';
  static const String _keyBlindfoldDifficulty = 'settings_blindfold_difficulty';
  static const String _keyIsVoiceDebugMode = 'settings_is_voice_debug_mode';

  // Board preferences keys
  static const String _keyFlipBoard = 'settings_board_flip_board';
  static const String _keyAutoRotate = 'settings_board_auto_rotate';
  static const String _keyShowCoordinates = 'settings_board_show_coordinates';
  static const String _keyShowLegalHints = 'settings_board_show_legal_hints';
  static const String _keyShowLastMoveHighlight = 'settings_board_show_last_move_highlight';

  // State notifier to trigger theme/settings rebuilds across the app
  final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> boardThemeNotifier = ValueNotifier<String>(
    'classic_wood',
  );
  final ValueNotifier<bool> isMutedNotifier = ValueNotifier<bool>(false);

  // Blindfold mode settings notifiers
  final ValueNotifier<bool> isBlindfoldModeNotifier = ValueNotifier<bool>(
    false,
  );
  final ValueNotifier<BlindfoldDifficulty> blindfoldDifficultyNotifier =
      ValueNotifier<BlindfoldDifficulty>(BlindfoldDifficulty.medium);
  final ValueNotifier<bool> isVoiceDebugModeNotifier = ValueNotifier<bool>(
    kDebugMode,
  );

  // Board preference notifiers
  final ValueNotifier<bool> flipBoardNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> autoRotateNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> showCoordinatesNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> showLegalHintsNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> showLastMoveHighlightNotifier = ValueNotifier<bool>(true);

  bool get isDarkMode => isDarkModeNotifier.value;
  String get boardTheme => boardThemeNotifier.value;
  bool get isMuted => isMutedNotifier.value;

  bool get isBlindfoldMode => isBlindfoldModeNotifier.value;
  BlindfoldDifficulty get blindfoldDifficulty =>
      blindfoldDifficultyNotifier.value;
  bool get isVoiceDebugMode => isVoiceDebugModeNotifier.value;

  // Board preference getters
  bool get flipBoard => flipBoardNotifier.value;
  bool get autoRotate => autoRotateNotifier.value;
  bool get showCoordinates => showCoordinatesNotifier.value;
  bool get showLegalHints => showLegalHintsNotifier.value;
  bool get showLastMoveHighlight => showLastMoveHighlightNotifier.value;

  /// Loads all settings from local SharedPreferences storage.
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    isDarkModeNotifier.value = prefs.getBool(_keyIsDarkMode) ?? false;
    boardThemeNotifier.value =
        prefs.getString(_keyBoardTheme) ?? 'classic_wood';
    isMutedNotifier.value = prefs.getBool(_keyIsMuted) ?? false;
    isBlindfoldModeNotifier.value = prefs.getBool(_keyIsBlindfoldMode) ?? false;
    isVoiceDebugModeNotifier.value =
        prefs.getBool(_keyIsVoiceDebugMode) ?? kDebugMode;

    final diffStr = prefs.getString(_keyBlindfoldDifficulty) ?? 'medium';
    blindfoldDifficultyNotifier.value = BlindfoldDifficulty.values.firstWhere(
      (e) => e.name == diffStr,
      orElse: () => BlindfoldDifficulty.medium,
    );

    // Load board preferences
    flipBoardNotifier.value = prefs.getBool(_keyFlipBoard) ?? false;
    autoRotateNotifier.value = prefs.getBool(_keyAutoRotate) ?? false;
    showCoordinatesNotifier.value = prefs.getBool(_keyShowCoordinates) ?? true;
    showLegalHintsNotifier.value = prefs.getBool(_keyShowLegalHints) ?? true;
    showLastMoveHighlightNotifier.value = prefs.getBool(_keyShowLastMoveHighlight) ?? true;
  }

  /// Toggles Dark Mode setting and commits to local storage.
  Future<void> toggleDarkMode() async {
    isDarkModeNotifier.value = !isDarkModeNotifier.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsDarkMode, isDarkModeNotifier.value);
  }

  /// Sets a new Board Theme choice and commits to local storage.
  Future<void> setBoardTheme(String theme) async {
    boardThemeNotifier.value = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBoardTheme, theme);
  }

  /// Toggles Muted state setting and commits to local storage.
  Future<void> toggleMute() async {
    isMutedNotifier.value = !isMutedNotifier.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsMuted, isMutedNotifier.value);
  }

  /// Sets Blindfold Mode toggle and commits to local storage.
  Future<void> setBlindfoldMode(bool value) async {
    isBlindfoldModeNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsBlindfoldMode, value);
  }

  /// Sets Blindfold Difficulty and commits to local storage.
  Future<void> setBlindfoldDifficulty(BlindfoldDifficulty difficulty) async {
    blindfoldDifficultyNotifier.value = difficulty;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBlindfoldDifficulty, difficulty.name);
  }

  /// Sets Voice Debug Mode and commits to local storage.
  Future<void> setVoiceDebugMode(bool value) async {
    isVoiceDebugModeNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsVoiceDebugMode, value);
  }

  /// Sets Flip Board preference.
  Future<void> setFlipBoard(bool value) async {
    flipBoardNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFlipBoard, value);
  }

  /// Sets Auto Rotate preference.
  Future<void> setAutoRotate(bool value) async {
    autoRotateNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoRotate, value);
  }

  /// Sets Coordinates ON/OFF preference.
  Future<void> setShowCoordinates(bool value) async {
    showCoordinatesNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowCoordinates, value);
  }

  /// Sets Legal Move Hints ON/OFF preference.
  Future<void> setShowLegalHints(bool value) async {
    showLegalHintsNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowLegalHints, value);
  }

  /// Sets Last Move Highlight preference.
  Future<void> setShowLastMoveHighlight(bool value) async {
    showLastMoveHighlightNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowLastMoveHighlight, value);
  }

  /// Resets settings to default values for test isolation.
  void resetToDefaults() {
    isDarkModeNotifier.value = false;
    boardThemeNotifier.value = 'classic_wood';
    isMutedNotifier.value = false;
    isBlindfoldModeNotifier.value = false;
    blindfoldDifficultyNotifier.value = BlindfoldDifficulty.medium;
    isVoiceDebugModeNotifier.value = kDebugMode;

    flipBoardNotifier.value = false;
    autoRotateNotifier.value = false;
    showCoordinatesNotifier.value = true;
    showLegalHintsNotifier.value = true;
    showLastMoveHighlightNotifier.value = true;
  }
}
