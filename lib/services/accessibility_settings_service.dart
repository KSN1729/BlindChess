import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verbosity levels for text-to-speech spoken announcements.
enum VerbosityLevel { minimal, standard, detailed }

/// Service in charge of storing, loading, and modifying accessibility settings.
class AccessibilitySettingsService {
  // Singleton pattern instantiation
  static final AccessibilitySettingsService instance = AccessibilitySettingsService._internal();
  AccessibilitySettingsService._internal();

  // Storage keys constants
  static const String _keySpeechEnabled = 'settings_accessibility_speech_enabled';
  static const String _keySpeechRate = 'settings_accessibility_speech_rate';
  static const String _keyPitch = 'settings_accessibility_pitch';
  static const String _keyVolume = 'settings_accessibility_volume';
  static const String _keyVerbosity = 'settings_accessibility_verbosity';
  static const String _keyAudioFeedbackEnabled = 'settings_accessibility_audio_feedback_enabled';
  static const String _keyHapticFeedbackEnabled = 'settings_accessibility_haptic_feedback_enabled';

  // ValueNotifier states to trigger active UI rebuilds
  final ValueNotifier<bool> speechEnabledNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<double> speechRateNotifier = ValueNotifier<double>(0.5);
  final ValueNotifier<double> pitchNotifier = ValueNotifier<double>(1.0);
  final ValueNotifier<double> volumeNotifier = ValueNotifier<double>(1.0);
  final ValueNotifier<VerbosityLevel> verbosityNotifier = ValueNotifier<VerbosityLevel>(VerbosityLevel.standard);
  final ValueNotifier<bool> audioFeedbackEnabledNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> hapticFeedbackEnabledNotifier = ValueNotifier<bool>(true);

  // Getter shortcuts
  bool get speechEnabled => speechEnabledNotifier.value;
  double get speechRate => speechRateNotifier.value;
  double get pitch => pitchNotifier.value;
  double get volume => volumeNotifier.value;
  VerbosityLevel get verbosity => verbosityNotifier.value;
  bool get audioFeedbackEnabled => audioFeedbackEnabledNotifier.value;
  bool get hapticFeedbackEnabled => hapticFeedbackEnabledNotifier.value;

  /// Loads all accessibility settings from local SharedPreferences storage.
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      speechEnabledNotifier.value = prefs.getBool(_keySpeechEnabled) ?? true;
      speechRateNotifier.value = prefs.getDouble(_keySpeechRate) ?? 0.5;
      pitchNotifier.value = prefs.getDouble(_keyPitch) ?? 1.0;
      volumeNotifier.value = prefs.getDouble(_keyVolume) ?? 1.0;
      audioFeedbackEnabledNotifier.value = prefs.getBool(_keyAudioFeedbackEnabled) ?? true;
      hapticFeedbackEnabledNotifier.value = prefs.getBool(_keyHapticFeedbackEnabled) ?? true;

      final verbStr = prefs.getString(_keyVerbosity) ?? 'standard';
      verbosityNotifier.value = VerbosityLevel.values.firstWhere(
        (e) => e.name == verbStr,
        orElse: () => VerbosityLevel.standard,
      );
    } catch (e) {
      debugPrint('Error loading accessibility settings: $e');
    }
  }

  /// Sets whether Speech Output is enabled and commits to storage.
  Future<void> setSpeechEnabled(bool value) async {
    speechEnabledNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySpeechEnabled, value);
  }

  /// Sets the Text-To-Speech speech rate and commits to storage.
  Future<void> setSpeechRate(double value) async {
    speechRateNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySpeechRate, value);
  }

  /// Sets the Text-To-Speech pitch and commits to storage.
  Future<void> setPitch(double value) async {
    pitchNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyPitch, value);
  }

  /// Sets the Text-To-Speech volume and commits to storage.
  Future<void> setVolume(double value) async {
    volumeNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyVolume, value);
  }

  /// Sets the announcement verbosity level and commits to storage.
  Future<void> setVerbosity(VerbosityLevel value) async {
    verbosityNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyVerbosity, value.name);
  }

  /// Sets whether audio feedback sounds are enabled and commits to storage.
  Future<void> setAudioFeedbackEnabled(bool value) async {
    audioFeedbackEnabledNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAudioFeedbackEnabled, value);
  }

  /// Sets whether haptic vibrations are enabled and commits to storage.
  Future<void> setHapticFeedbackEnabled(bool value) async {
    hapticFeedbackEnabledNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHapticFeedbackEnabled, value);
  }

  /// Resets settings to default values for test isolation.
  void resetToDefaults() {
    speechEnabledNotifier.value = true;
    speechRateNotifier.value = 0.5;
    pitchNotifier.value = 1.0;
    volumeNotifier.value = 1.0;
    verbosityNotifier.value = VerbosityLevel.standard;
    audioFeedbackEnabledNotifier.value = true;
    hapticFeedbackEnabledNotifier.value = true;
  }
}
