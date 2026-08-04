import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blind_chess/services/speech_service.dart';
import 'package:blind_chess/services/settings_service.dart';
import 'package:blind_chess/screens/game_screen.dart';
import 'package:blind_chess/widgets/chess_board.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Voice Undo Widget Tests', () {
    late MockSpeechService mockSpeechService;

    setUp(() {
      SettingsService.instance.resetToDefaults();
      mockSpeechService = MockSpeechService();
      SpeechService.instance = mockSpeechService;
    });

    tearDown(() {
      SpeechService.instance = RealSpeechService();
    });

    testWidgets('Voice Undo - within 3 seconds window instantly reverts', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() async {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await tester.binding.setSurfaceSize(null);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });

      await tester.pumpWidget(const MaterialApp(home: GameScreen()));

      // Tap mic to start listening
      await tester.tap(find.byKey(const ValueKey('mic_button')));
      await tester.pump();

      // Make a move
      mockSpeechService.simulateSpeech('e2 e4');
      await tester.pump(const Duration(milliseconds: 500));

      final boardFinder = find.byType(ChessBoard);
      final boardWidget = tester.widget<ChessBoard>(boardFinder);
      expect(boardWidget.chessEngineService.getHistory().length, 1);

      // Now instantly speak "undo"
      await tester.tap(find.byKey(const ValueKey('mic_button')));
      await tester.pump();
      mockSpeechService.simulateSpeech('undo');
      await tester.pump(const Duration(milliseconds: 500));

      // Move should be reverted instantly
      expect(boardWidget.chessEngineService.getHistory().length, 0);
    });

    testWidgets('Voice Undo - outside 3 seconds window requires confirmation', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() async {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await tester.binding.setSurfaceSize(null);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });

      await tester.pumpWidget(const MaterialApp(home: GameScreen()));

      // Tap mic to start listening
      await tester.tap(find.byKey(const ValueKey('mic_button')));
      await tester.pump();

      // Make a move
      mockSpeechService.simulateSpeech('e2 e4');
      await tester.pump(const Duration(milliseconds: 500));

      final boardFinder = find.byType(ChessBoard);
      final boardWidget = tester.widget<ChessBoard>(boardFinder);
      expect(boardWidget.chessEngineService.getHistory().length, 1);

      // Wait 4 seconds (outside the 3-second window)
      sleep(const Duration(seconds: 4));
      await tester.pump();

      // Speak "undo"
      await tester.tap(find.byKey(const ValueKey('mic_button')));
      await tester.pump();
      mockSpeechService.simulateSpeech('undo');
      await tester.pump(const Duration(milliseconds: 500));

      // Move should NOT be reverted yet (history length still 1)
      expect(boardWidget.chessEngineService.getHistory().length, 1);
      expect(
        find.text('Are you sure you want to undo the last move?'),
        findsOneWidget,
      );

      // Confirm with "yes"
      await tester.tap(find.byKey(const ValueKey('mic_button')));
      await tester.pump();
      mockSpeechService.simulateSpeech('yes');
      await tester.pump(const Duration(milliseconds: 500));

      // Move should be reverted now
      expect(boardWidget.chessEngineService.getHistory().length, 0);
    });
  });
}
