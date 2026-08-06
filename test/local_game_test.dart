import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blind_chess/models/chess_clock_config.dart';
import 'package:blind_chess/models/game_result.dart';
import 'package:blind_chess/models/chess_piece.dart';
import 'package:blind_chess/utils/pgn_processor.dart';
import 'package:blind_chess/services/game_persistence_service.dart';
import 'package:blind_chess/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Chess Clock Config Tests', () {
    test('Clock presets initialization', () {
      expect(ChessClockConfig.presets.length, greaterThan(1));
      final bullet1 = ChessClockConfig.bullet1;
      expect(bullet1.baseSeconds, 60);
      expect(bullet1.incrementSeconds, 0);
      expect(bullet1.hasTimer, isTrue);

      final blitz3Inc = ChessClockConfig.blitz3Increment;
      expect(blitz3Inc.baseSeconds, 180);
      expect(blitz3Inc.incrementSeconds, 2);

      final noTimer = ChessClockConfig.noTimer;
      expect(noTimer.hasTimer, isFalse);
    });
  });

  group('Game Result Tests', () {
    test('Checkmate result values', () {
      final res = GameResult(
        type: ResultType.checkmate,
        winnerColor: PieceColor.white,
        description: 'Checkmate — White wins.',
      );
      expect(res.type, ResultType.checkmate);
      expect(res.winnerColor, PieceColor.white);
      expect(res.shortResultString, '1-0');
    });

    test('Stalemate draw values', () {
      final res = GameResult(
        type: ResultType.stalemate,
        description: 'Stalemate — Draw.',
      );
      expect(res.type, ResultType.stalemate);
      expect(res.winnerColor, isNull);
      expect(res.shortResultString, '1/2-1/2');
    });

    test('Timeout result values', () {
      final res = GameResult(
        type: ResultType.timeout,
        winnerColor: PieceColor.black,
        description: 'Timeout — Black wins.',
      );
      expect(res.type, ResultType.timeout);
      expect(res.winnerColor, PieceColor.black);
      expect(res.shortResultString, '0-1');
    });
  });

  group('PGN Processor Tests', () {
    test('Export PGN basic formatting', () {
      final pgn = PgnProcessor.exportPgn(
        sanHistory: ['e4', 'e5', 'Nf3', 'Nc6'],
        result: '1/2-1/2',
      );
      expect(pgn, contains('[Event "Local Game"]'));
      expect(pgn, contains('[Result "1/2-1/2"]'));
      expect(pgn, contains('1. e4 e5 2. Nf3 Nc6 1/2-1/2'));
    });

    test('Import PGN validation - success', () {
      const inputPgn = '''
[Event "Local Game"]
[Result "1-0"]

1. e4 e5 2. Nf3 Nc6 1-0
''';
      final parsed = PgnProcessor.importAndValidatePgn(inputPgn);
      expect(parsed, isNotNull);
      expect(parsed!['sanMoves'], equals(['e4', 'e5', 'Nf3', 'Nc6']));
      expect(parsed['uciMoves'], equals(['e2e4', 'e7e5', 'g1f3', 'b8c6']));
    });

    test('Import PGN validation - failure for invalid format', () {
      const invalidPgn = 'invalid pgn text here';
      final parsed = PgnProcessor.importAndValidatePgn(invalidPgn);
      expect(parsed, isNull);
    });
  });

  group('Game Persistence Service Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('Autosave and restore game state values', () async {
      final service = GamePersistenceService.instance;
      expect(await service.hasSavedGame(), isFalse);

      await service.saveGame(
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        uciMoves: ['e2e4', 'e7e5'],
        sanMoves: ['e4', 'e5'],
        whiteTimeMs: 60000,
        blackTimeMs: 58000,
        clockLabel: 'Bullet 1+0',
        clockBaseSeconds: 60,
        clockIncrementSeconds: 0,
        clockHasTimer: true,
        currentMoveIndex: 1,
        gameActive: true,
      );

      expect(await service.hasSavedGame(), isTrue);

      final restored = await service.restoreGame();
      expect(restored, isNotNull);
      expect(restored!['fen'], 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
      expect(restored['uciMoves'], equals(['e2e4', 'e7e5']));
      expect(restored['whiteTimeMs'], 60000);
      expect(restored['clockLabel'], 'Bullet 1+0');
      expect(restored['currentMoveIndex'], 1);

      await service.clearSavedGame();
      expect(await service.hasSavedGame(), isFalse);
    });
  });

  group('Settings Service Preferences Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      SettingsService.instance.resetToDefaults();
    });

    test('Flip board toggle values', () async {
      final settings = SettingsService.instance;
      expect(settings.flipBoard, isFalse);

      await settings.setFlipBoard(true);
      expect(settings.flipBoard, isTrue);

      settings.resetToDefaults();
      expect(settings.flipBoard, isFalse);
    });

    test('Coordinates and hints toggle values', () async {
      final settings = SettingsService.instance;
      expect(settings.showCoordinates, isTrue);
      expect(settings.showLegalHints, isTrue);

      await settings.setShowCoordinates(false);
      await settings.setShowLegalHints(false);
      expect(settings.showCoordinates, isFalse);
      expect(settings.showLegalHints, isFalse);
    });
  });
}
