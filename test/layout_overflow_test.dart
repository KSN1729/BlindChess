import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blind_chess/widgets/challenge_bot_dialog.dart';
import 'package:blind_chess/screens/stats_screen.dart';
import 'package:blind_chess/screens/recent_games_screen.dart';
import 'package:blind_chess/models/lichess_game.dart';
import 'package:blind_chess/services/settings_service.dart';
import 'package:blind_chess/services/statistics_service.dart';

void main() {
  setUp(() {
    SettingsService.instance.resetToDefaults();
  });

  group('Layout Overflow Tests - Narrow Viewport (320px)', () {
    testWidgets('ChallengeBotDialog does not overflow horizontally at 320px', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      await tester.binding.setSurfaceSize(const Size(320, 640));

      addTearDown(() async {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        await tester.binding.setSurfaceSize(null);
      });

      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ChallengeBotDialog(startWithBlindfold: true)),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the dialog renders without layout exceptions
      expect(find.byType(ChallengeBotDialog), findsOneWidget);
    });

    testWidgets(
      'StatsScreen badge list does not overflow horizontally at 320px',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        await tester.binding.setSurfaceSize(const Size(320, 640));

        addTearDown(() async {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          await tester.binding.setSurfaceSize(null);
        });

        SharedPreferences.setMockInitialValues({
          'stats_white_wins': 5,
          'stats_black_wins': 5,
          'stats_blindfold_wins': 1,
          'stats_highest_memory_score': 100,
          'stats_total_blindfold_games_played': 1,
        });

        await StatisticsService.instance.loadStats();

        await tester.pumpWidget(const MaterialApp(home: StatsScreen()));

        await tester.pumpAndSettle();

        // Verify that StatsScreen is successfully laid out
        expect(find.byType(StatsScreen), findsOneWidget);
      },
    );

    testWidgets(
      'PgnDialog does not overflow horizontally at 320px with long username',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        await tester.binding.setSurfaceSize(const Size(320, 640));

        addTearDown(() async {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          await tester.binding.setSurfaceSize(null);
        });

        SharedPreferences.setMockInitialValues({});

        final longOpponentGame = LichessGame(
          id: 'game123',
          opponentUsername:
              'super_long_username_opponent_that_normally_overflows_unconstrained_layouts_completely',
          result: 'Win',
          colorPlayed: 'White',
          date: DateTime.now(),
          pgn: '1. e4 e5 2. Nf3 Nc6',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: PgnDialog(game: longOpponentGame)),
          ),
        );

        await tester.pumpAndSettle();

        // Verify PgnDialog renders
        expect(find.byType(PgnDialog), findsOneWidget);
      },
    );
  });
}
