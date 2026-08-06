import 'package:flutter/services.dart';
import 'accessibility_settings_service.dart';

/// Service in charge of triggering platform-safe haptic/vibration feedback.
class HapticService {
  /// Vibrates on successful move (light click).
  static Future<void> triggerSuccessfulMove() async {
    if (!AccessibilitySettingsService.instance.hapticFeedbackEnabled) return;
    await HapticFeedback.lightImpact();
  }

  /// Vibrates on illegal selection or parsed error (standard vibration).
  static Future<void> triggerIllegalMove() async {
    if (!AccessibilitySettingsService.instance.hapticFeedbackEnabled) return;
    await HapticFeedback.vibrate();
  }

  /// Vibrates on check events (medium thump).
  static Future<void> triggerCheck() async {
    if (!AccessibilitySettingsService.instance.hapticFeedbackEnabled) return;
    await HapticFeedback.mediumImpact();
  }

  /// Vibrates on checkmate or game-over alert (heavy impact).
  static Future<void> triggerGameOver() async {
    if (!AccessibilitySettingsService.instance.hapticFeedbackEnabled) return;
    await HapticFeedback.heavyImpact();
  }
}
