import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blind_chess/services/accessibility_settings_service.dart';
import 'package:blind_chess/services/tts_service.dart';
import 'package:blind_chess/screens/accessibility_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AccessibilitySettingsService Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AccessibilitySettingsService.instance.resetToDefaults();
    });

    test('Loads default values correctly', () async {
      final service = AccessibilitySettingsService.instance;
      expect(service.speechEnabled, true);
      expect(service.speechRate, 0.5);
      expect(service.pitch, 1.0);
      expect(service.volume, 1.0);
      expect(service.verbosity, VerbosityLevel.standard);
      expect(service.audioFeedbackEnabled, true);
      expect(service.hapticFeedbackEnabled, true);
    });

    test('Persists options inside SharedPreferences', () async {
      final service = AccessibilitySettingsService.instance;
      await service.setSpeechEnabled(false);
      await service.setSpeechRate(0.85);
      await service.setPitch(1.2);
      await service.setVolume(0.9);
      await service.setVerbosity(VerbosityLevel.detailed);
      await service.setAudioFeedbackEnabled(false);
      await service.setHapticFeedbackEnabled(false);

      expect(service.speechEnabled, false);
      expect(service.speechRate, 0.85);
      expect(service.pitch, 1.2);
      expect(service.volume, 0.9);
      expect(service.verbosity, VerbosityLevel.detailed);
      expect(service.audioFeedbackEnabled, false);
      expect(service.hapticFeedbackEnabled, false);

      // Load into a new service state to verify SharedPreferences reading
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('settings_accessibility_speech_enabled'), false);
      expect(prefs.getDouble('settings_accessibility_speech_rate'), 0.85);
    });
  });

  group('TtsService and Queueing System Unit Tests', () {
    late TtsService ttsService;
    late DummyTtsEngine testEngine;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AccessibilitySettingsService.instance.resetToDefaults();
      ttsService = TtsService.instance;
      ttsService.reset();
      testEngine = DummyTtsEngine();
      ttsService.setEngine(testEngine);
    });

    test('Announcements history tracking holds up to 20 texts', () async {
      await ttsService.stop();
      for (int i = 1; i <= 25; i++) {
        await ttsService.speak('Test $i', priority: AnnouncementPriority.normal);
      }
      expect(ttsService.announcementHistory.length, 20);
      expect(ttsService.lastAnnouncement, 'Test 25');
    });

    test('Repeat last announcement command functions correctly', () async {
      await ttsService.stop();
      await ttsService.speak('Unique announcement text', priority: AnnouncementPriority.normal);
      
      final lastAnn = ttsService.lastAnnouncement;
      expect(lastAnn, 'Unique announcement text');
      
      // Repeating should add another text instance to history
      await ttsService.repeatLastAnnouncement();
      expect(ttsService.announcementHistory.length, 2);
      expect(ttsService.announcementHistory.last, 'Unique announcement text');
    });

    test('FIFO ordering for same priority announcements', () async {
      await ttsService.stop();
      final List<String> spokenTexts = [];
      testEngine.onSpeak = (text) => spokenTexts.add(text);

      final f1 = ttsService.speak('First', priority: AnnouncementPriority.normal);
      final f2 = ttsService.speak('Second', priority: AnnouncementPriority.normal);
      final f3 = ttsService.speak('Third', priority: AnnouncementPriority.normal);

      await Future.wait([f1, f2, f3]);
      expect(spokenTexts, ['First', 'Second', 'Third']);
    });

    test('High priority interrupts active speech immediately', () async {
      await ttsService.stop();
      final List<String> spokenTexts = [];
      testEngine.onSpeak = (text) => spokenTexts.add(text);

      // Start normal speak, which will take time to complete
      testEngine.autoComplete = false;
      
      final f1 = ttsService.speak('Low priority normal text', priority: AnnouncementPriority.normal);
      
      // Allow speech to initialize
      await Future.delayed(const Duration(milliseconds: 5));
      
      // Speak a high priority one which should immediately interrupt
      final f2 = ttsService.speak('Urgent checkmate announcement!', priority: AnnouncementPriority.high);
      
      testEngine.completeActiveSpeech();
      await Future.wait([f1, f2]);

      expect(spokenTexts, ['Low priority normal text', 'Urgent checkmate announcement!']);
    });
  });

  group('AccessibilitySettingsScreen Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      AccessibilitySettingsService.instance.resetToDefaults();
    });

    testWidgets('AccessibilitySettingsScreen UI renders all sliders, dropdowns and toggles', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: AccessibilitySettingsScreen(),
      ));

      // Assert basic section headers and labels exist
      expect(find.text('Accessibility Settings'), findsOneWidget);
      expect(find.text('Speech Settings'), findsOneWidget);
      expect(find.text('Speech Output Enabled'), findsOneWidget);
      expect(find.text('Audio Feedback'), findsOneWidget);
      expect(find.text('Haptic Feedback'), findsOneWidget);

      // Verify Repeat Last Announcement button renders
      expect(find.text('Repeat Last Announcement'), findsOneWidget);

      // Verify that changing the switch updates the service
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsAtLeastNWidgets(3)); // Speech, Audio, Haptic

      final service = AccessibilitySettingsService.instance;
      expect(service.speechEnabled, true);

      // Toggle Speech Enabled switch
      await tester.tap(switchFinder.first);
      await tester.pumpAndSettle();
      expect(service.speechEnabled, false);
    });
  });
}

class DummyTtsEngine implements TtsEngine {
  VoidCallback? _startHandler;
  VoidCallback? _completionHandler;

  bool autoComplete = true;
  Function(String)? onSpeak;

  @override
  void setStartHandler(VoidCallback callback) => _startHandler = callback;

  @override
  void setCompletionHandler(VoidCallback callback) => _completionHandler = callback;

  @override
  void setErrorHandler(Function(String) callback) {}

  @override
  Future<void> speak(String text, {double rate = 0.5, double pitch = 1.0, double volume = 1.0}) async {
    onSpeak?.call(text);
    _startHandler?.call();
    if (autoComplete) {
      scheduleMicrotask(() => _completionHandler?.call());
    }
  }

  void completeActiveSpeech() {
    _completionHandler?.call();
  }

  @override
  Future<void> stop() async {
    _completionHandler?.call();
  }

  @override
  Future<void> dispose() async {}
}
