import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:blind_chess/services/voice_regression_service.dart';
import 'package:blind_chess/services/speech_service.dart';
import 'package:blind_chess/services/settings_service.dart';
import 'package:blind_chess/utils/voice_command_parser.dart';
import 'package:blind_chess/config/piece_dictionary.dart';
import 'package:blind_chess/config/square_dictionary.dart';
import 'package:blind_chess/config/number_dictionary.dart';
import 'package:blind_chess/services/word_similarity_service.dart';
import 'package:blind_chess/screens/game_screen.dart';
import 'package:blind_chess/widgets/voice_command_widget.dart';
import 'package:blind_chess/widgets/chess_square.dart';
import 'package:blind_chess/widgets/chess_board.dart';
import 'package:blind_chess/services/diagnostic_recorder.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    SettingsService.instance.resetToDefaults();
  });

  group('VoiceCommandParser - Unit Tests', () {
    test('coordinate-style moves', () {
      final legalMoves = [
        {'from': 'e2', 'to': 'e4', 'piece': 'p', 'san': 'e4'},
        {'from': 'g1', 'to': 'f3', 'piece': 'n', 'san': 'Nf3'},
      ];

      expect(
        VoiceCommandParser.parseCommand('e2 e4', legalMoves),
        equals(legalMoves[0]),
      );
      expect(
        VoiceCommandParser.parseCommand('e2 to e4', legalMoves),
        equals(legalMoves[0]),
      );
      expect(
        VoiceCommandParser.parseCommand('g1 to f3', legalMoves),
        equals(legalMoves[1]),
      );
    });

    test('piece-and-destination moves', () {
      final legalMoves = [
        {'from': 'g1', 'to': 'f3', 'piece': 'n', 'san': 'Nf3'},
        {'from': 'f1', 'to': 'c4', 'piece': 'b', 'san': 'Bc4'},
        {'from': 'e2', 'to': 'e4', 'piece': 'p', 'san': 'e4'},
      ];

      expect(
        VoiceCommandParser.parseCommand('knight f3', legalMoves),
        equals(legalMoves[0]),
      );
      expect(
        VoiceCommandParser.parseCommand('bishop takes c4', legalMoves),
        equals(legalMoves[1]),
      );
      expect(
        VoiceCommandParser.parseCommand('pawn e4', legalMoves),
        equals(legalMoves[2]),
      );
    });

    test('castling moves', () {
      final legalMoves = [
        {'from': 'e1', 'to': 'g1', 'piece': 'k', 'san': 'O-O'},
        {'from': 'e1', 'to': 'c1', 'piece': 'k', 'san': 'O-O-O'},
      ];

      expect(
        VoiceCommandParser.parseCommand('castle kingside', legalMoves),
        equals(legalMoves[0]),
      );
      expect(
        VoiceCommandParser.parseCommand('short castle', legalMoves),
        equals(legalMoves[0]),
      );
      expect(
        VoiceCommandParser.parseCommand('castle queenside', legalMoves),
        equals(legalMoves[1]),
      );
      expect(
        VoiceCommandParser.parseCommand('long castle', legalMoves),
        equals(legalMoves[1]),
      );
    });

    test('ambiguous / unparseable moves return null or error', () {
      final legalMoves = [
        {'from': 'b1', 'to': 'd2', 'piece': 'n', 'san': 'Nbd2'},
        {'from': 'f3', 'to': 'd2', 'piece': 'n', 'san': 'Nfd2'},
      ];

      final result = VoiceCommandParser.parseCommand(
        'knight to d2',
        legalMoves,
      );
      expect(result, isNotNull);
      expect(
        result!['error'],
        contains('Two knights can move there. Please specify which one.'),
      );

      expect(
        VoiceCommandParser.parseCommand('invalid text', legalMoves),
        isNull,
      );
    });

    test('coordinate promotion support', () {
      final legalMoves = [
        {
          'from': 'e7',
          'to': 'e8',
          'piece': 'p',
          'san': 'e8=Q',
          'promotion': 'q',
        },
        {
          'from': 'e7',
          'to': 'e8',
          'piece': 'p',
          'san': 'e8=R',
          'promotion': 'r',
        },
      ];

      expect(
        VoiceCommandParser.parseCommand('e7 e8 queen', legalMoves),
        equals(legalMoves[0]),
      );
      expect(
        VoiceCommandParser.parseCommand('e7 to e8 rook', legalMoves),
        equals(legalMoves[1]),
      );
    });

    test('phonetic aliases mapping', () {
      final legalMoves = [
        {'from': 'g1', 'to': 'c3', 'piece': 'n', 'san': 'Nc3'},
        {'from': 'e2', 'to': 'e4', 'piece': 'p', 'san': 'e4'},
      ];

      expect(
        VoiceCommandParser.parseCommand('night c3', legalMoves),
        equals(legalMoves[0]),
      );
      expect(
        VoiceCommandParser.parseCommand('nite c3', legalMoves),
        equals(legalMoves[0]),
      );
      expect(
        VoiceCommandParser.parseCommand('nine c3', legalMoves),
        equals(legalMoves[0]),
      );
    });

    test('case-insensitive coordinate and piece matching', () {
      final legalMoves = [
        {'from': 'g1', 'to': 'c6', 'piece': 'n', 'san': 'Nc6'},
        {'from': 'e2', 'to': 'e4', 'piece': 'p', 'san': 'e4'},
      ];

      expect(
        VoiceCommandParser.parseCommand('NIGHT C6', legalMoves),
        equals(legalMoves[0]),
      );
      expect(
        VoiceCommandParser.parseCommand('Knight C 6', legalMoves),
        equals(legalMoves[0]),
      );
      expect(
        VoiceCommandParser.parseCommand('E 4', legalMoves),
        equals(legalMoves[1]),
      );
    });

    test('single-square shorthand matching', () {
      final legalMoves = [
        {'from': 'e2', 'to': 'e4', 'piece': 'p', 'san': 'e4'},
      ];

      expect(
        VoiceCommandParser.parseCommand('e4', legalMoves),
        equals(legalMoves[0]),
      );
      expect(
        VoiceCommandParser.parseCommand('e 4', legalMoves),
        equals(legalMoves[0]),
      );
      expect(
        VoiceCommandParser.parseCommand('e to 4', legalMoves),
        equals(legalMoves[0]),
      );
    });

    test(
      'single-square command with multiple candidate moves returns error map',
      () {
        final legalMoves = [
          {'from': 'b1', 'to': 'c3', 'piece': 'n', 'san': 'Nbc3'},
          {'from': 'g1', 'to': 'c3', 'piece': 'n', 'san': 'Ngc3'},
        ];

        final result = VoiceCommandParser.parseCommand('c3', legalMoves);
        expect(result, isNotNull);
        expect(
          result!['error'],
          contains('Two knights can move there. Please specify which one.'),
        );
      },
    );

    test('single-square command with no legal moves returns null', () {
      final legalMoves = [
        {'from': 'e2', 'to': 'e4', 'piece': 'p', 'san': 'e4'},
      ];

      expect(
        VoiceCommandParser.parseCommand('h6', legalMoves)!['error'],
        equals("That move isn't legal."),
      );
    });

    test('comprehensive voice parser validation suite', () {
      final legalMoves = [
        {'from': 'e2', 'to': 'e4', 'piece': 'p', 'san': 'e4'},
        {'from': 'c7', 'to': 'c5', 'piece': 'p', 'san': 'c5'},
        {'from': 'b1', 'to': 'c3', 'piece': 'n', 'san': 'Nc3'},
        {'from': 'd8', 'to': 'f6', 'piece': 'q', 'san': 'Qf6'},
        {'from': 'c1', 'to': 'g5', 'piece': 'b', 'san': 'Bg5'},
        {'from': 'd8', 'to': 'd1', 'piece': 'r', 'san': 'Rd1'},
        {'from': 'd8', 'to': 'd8', 'piece': 'r', 'san': 'Rd8'},
        {'from': 'e1', 'to': 'e2', 'piece': 'k', 'san': 'Ke2'},
        // Ambiguity candidates
        {'from': 'b1', 'to': 'd2', 'piece': 'n', 'san': 'Nbd2'},
        {'from': 'g1', 'to': 'd2', 'piece': 'n', 'san': 'Ngd2'},
      ];

      // e4
      expect(
        VoiceCommandParser.parseCommand('e4', legalMoves),
        equals(legalMoves[0]),
      );

      // c5
      expect(
        VoiceCommandParser.parseCommand('c5', legalMoves),
        equals(legalMoves[1]),
      );

      // knight c3
      expect(
        VoiceCommandParser.parseCommand('knight c3', legalMoves),
        equals(legalMoves[2]),
      );

      // night c3
      expect(
        VoiceCommandParser.parseCommand('night c3', legalMoves),
        equals(legalMoves[2]),
      );

      // queen f6
      expect(
        VoiceCommandParser.parseCommand('queen f6', legalMoves),
        equals(legalMoves[3]),
      );

      // bishop g5
      expect(
        VoiceCommandParser.parseCommand('bishop g5', legalMoves),
        equals(legalMoves[4]),
      );

      // rook d8
      expect(
        VoiceCommandParser.parseCommand('rook d8', legalMoves),
        equals(legalMoves[6]),
      );

      // king e2
      expect(
        VoiceCommandParser.parseCommand('king e2', legalMoves),
        equals(legalMoves[7]),
      );

      // ambiguous piece move
      final ambResult = VoiceCommandParser.parseCommand(
        'knight d2',
        legalMoves,
      );
      expect(ambResult, isNotNull);
      expect(
        ambResult!['error'],
        contains('Two knights can move there. Please specify which one.'),
      );

      // illegal move
      expect(
        VoiceCommandParser.parseCommand('knight e5', legalMoves)!['error'],
        equals("That move isn't legal."),
      );

      // invalid square
      expect(
        VoiceCommandParser.parseCommand('knight x9', legalMoves)!['error'],
        equals("I couldn't recognize the destination square."),
      );
    });

    test('natural spoken disambiguation by file, rank, and square', () {
      final legalMoves = [
        {'from': 'e7', 'to': 'd5', 'piece': 'n', 'san': 'Ned5'},
        {'from': 'f6', 'to': 'd5', 'piece': 'n', 'san': 'Nfd5'},
        {'from': 'a1', 'to': 'a5', 'piece': 'r', 'san': 'Raa5'},
        {'from': 'c1', 'to': 'g5', 'piece': 'b', 'san': 'Bcg5'},
        {'from': 'd1', 'to': 'h4', 'piece': 'q', 'san': 'Qdh4'},
        {'from': 'b7', 'to': 'd5', 'piece': 'n', 'san': 'Nbd5'},
        {'from': 'b1', 'to': 'd5', 'piece': 'n', 'san': 'N1d5'},
      ];

      // knight d5 (should be ambiguous between Ned5, Nfd5, Nbd5, N1d5)
      final ambResult = VoiceCommandParser.parseCommand(
        'knight d5',
        legalMoves,
      );
      expect(ambResult, isNotNull);
      expect(
        ambResult!['error'],
        contains('Two knights can move there. Please specify which one.'),
      );

      // night d5 (alias, also ambiguous)
      final ambResult2 = VoiceCommandParser.parseCommand(
        'night d5',
        legalMoves,
      );
      expect(ambResult2, isNotNull);
      expect(
        ambResult2!['error'],
        contains('Two knights can move there. Please specify which one.'),
      );

      // knight e d5 (origin file filtering)
      expect(
        VoiceCommandParser.parseCommand('knight e d5', legalMoves),
        equals(legalMoves[0]),
      );

      // knight f d5 (origin file filtering)
      expect(
        VoiceCommandParser.parseCommand('knight f d5', legalMoves),
        equals(legalMoves[1]),
      );

      // knight e7 d5 (origin square filtering)
      expect(
        VoiceCommandParser.parseCommand('knight e7 d5', legalMoves),
        equals(legalMoves[0]),
      );

      // rook a a5 (origin file filtering)
      expect(
        VoiceCommandParser.parseCommand('rook a a5', legalMoves),
        equals(legalMoves[2]),
      );

      // bishop c g5 (origin file filtering)
      expect(
        VoiceCommandParser.parseCommand('bishop c g5', legalMoves),
        equals(legalMoves[3]),
      );

      // queen d h4 (origin file filtering)
      expect(
        VoiceCommandParser.parseCommand('queen d h4', legalMoves),
        equals(legalMoves[4]),
      );

      // knight 6 d5 (origin rank filtering, matches Nfd5 because f6 ends with 6)
      expect(
        VoiceCommandParser.parseCommand('knight 6 d5', legalMoves),
        equals(legalMoves[1]),
      );

      // knight 1 d5 (origin rank filtering, matches N1d5 because b1 ends with 1)
      expect(
        VoiceCommandParser.parseCommand('knight 1 d5', legalMoves),
        equals(legalMoves[6]),
      );
    });

    test('TextNormalizer independent unit test', () {
      expect(TextNormalizer.normalize(' Knight   C3.'), equals('knight c3'));
      expect(TextNormalizer.normalize('e to 4'), equals('e4'));
      expect(TextNormalizer.normalize('e 4'), equals('e4'));
    });

    test('PieceNormalizer independent unit test', () {
      expect(PieceNormalizer.normalize('knight')?['piece'], equals('n'));
      expect(PieceNormalizer.normalize('night')?['piece'], equals('n'));
      expect(PieceNormalizer.normalize('nite')?['piece'], equals('n'));
      expect(PieceNormalizer.normalize('n8')?['piece'], equals('n'));
      expect(PieceNormalizer.normalize('nine')?['piece'], equals('n'));

      expect(PieceNormalizer.normalize('rook')?['piece'], equals('r'));
      expect(PieceNormalizer.normalize('ruk')?['piece'], equals('r'));
      expect(PieceNormalizer.normalize('rock')?['piece'], equals('r'));
      expect(PieceNormalizer.normalize('rok')?['piece'], equals('r'));

      expect(PieceNormalizer.normalize('queen')?['piece'], equals('q'));
      expect(PieceNormalizer.normalize('qeen')?['piece'], equals('q'));
      expect(PieceNormalizer.normalize('kween')?['piece'], equals('q'));
      expect(PieceNormalizer.normalize('quean')?['piece'], equals('q'));

      expect(PieceNormalizer.normalize('bishop')?['piece'], equals('b'));
      expect(PieceNormalizer.normalize('bishup')?['piece'], equals('b'));
      expect(PieceNormalizer.normalize('bisop')?['piece'], equals('b'));

      expect(PieceNormalizer.normalize('king')?['piece'], equals('k'));
      expect(PieceNormalizer.normalize('keng')?['piece'], equals('k'));
      expect(PieceNormalizer.normalize('kin')?['piece'], equals('k'));

      expect(PieceNormalizer.normalize('pawn')?['piece'], equals('p'));
      expect(PieceNormalizer.normalize('pon')?['piece'], equals('p'));

      expect(PieceNormalizer.normalize('unknown'), isNull);
    });

    test('SquareNormalizer independent unit test', () {
      expect(SquareNormalizer.normalize('bee eight')?['square'], equals('b8'));
      expect(SquareNormalizer.normalize('be eight')?['square'], equals('b8'));
      expect(SquareNormalizer.normalize('v8')?['square'], equals('b8'));
      expect(SquareNormalizer.normalize('see four')?['square'], equals('c4'));
      expect(SquareNormalizer.normalize('sea four')?['square'], equals('c4'));
      expect(SquareNormalizer.normalize('dee five')?['square'], equals('d5'));
      expect(SquareNormalizer.normalize('eff six')?['square'], equals('f6'));
      expect(SquareNormalizer.normalize('gee seven')?['square'], equals('g7'));
      expect(SquareNormalizer.normalize('aitch two')?['square'], equals('h2'));
      expect(SquareNormalizer.normalize('invalid'), isNull);

      // Verify digit/word aliases
      expect(SquareNormalizer.normalizeFile('bee')?['file'], equals('b'));
      expect(SquareNormalizer.normalizeFile('be')?['file'], equals('b'));
      expect(SquareNormalizer.normalizeFile('v')?['file'], equals('b'));
      expect(SquareNormalizer.normalizeFile('sea')?['file'], equals('c'));
      expect(SquareNormalizer.normalizeFile('see')?['file'], equals('c'));
      expect(SquareNormalizer.normalizeFile('dee')?['file'], equals('d'));
      expect(SquareNormalizer.normalizeFile('eff')?['file'], equals('f'));
      expect(SquareNormalizer.normalizeFile('gee')?['file'], equals('g'));
      expect(SquareNormalizer.normalizeFile('aitch')?['file'], equals('h'));

      expect(SquareNormalizer.normalizeRank('won')?['rank'], equals('1'));
      expect(SquareNormalizer.normalizeRank('one')?['rank'], equals('1'));
      expect(SquareNormalizer.normalizeRank('to')?['rank'], equals('2'));
      expect(SquareNormalizer.normalizeRank('too')?['rank'], equals('2'));
      expect(SquareNormalizer.normalizeRank('for')?['rank'], equals('4'));
      expect(SquareNormalizer.normalizeRank('fore')?['rank'], equals('4'));
      expect(SquareNormalizer.normalizeRank('ate')?['rank'], equals('8'));
    });

    test('VoiceIntent independent unit test', () {
      final intent1 = VoiceIntent.parse('knight c3');
      expect(intent1.piece, equals('n'));
      expect(intent1.destinationSquare, equals('c3'));

      final intent2 = VoiceIntent.parse('knight e d5');
      expect(intent2.piece, equals('n'));
      expect(intent2.originFile, equals('e'));
      expect(intent2.destinationSquare, equals('d5'));

      final intent3 = VoiceIntent.parse('castle kingside');
      expect(intent3.piece, equals('k'));
      expect(intent3.isKingsideCastling, isTrue);
    });

    test('LegalMoveMatcher independent unit test', () {
      final legalMoves = [
        {'from': 'e7', 'to': 'd5', 'piece': 'n', 'san': 'Ned5'},
        {'from': 'f6', 'to': 'd5', 'piece': 'n', 'san': 'Nfd5'},
      ];

      final intent1 = VoiceIntent(
        piece: 'n',
        destinationSquare: 'd5',
        originFile: 'e',
      );
      expect(
        LegalMoveMatcher.match(intent1, legalMoves),
        equals(legalMoves[0]),
      );

      final intent2 = VoiceIntent(piece: 'n', destinationSquare: 'd5');
      final match2 = LegalMoveMatcher.match(intent2, legalMoves);
      expect(match2, isNotNull);
      expect(
        match2!['error'],
        contains('Two knights can move there. Please specify which one.'),
      );
    });

    test('confidence thresholds test', () {
      final legalMoves = [
        {'from': 'e2', 'to': 'e4', 'piece': 'p', 'san': 'e4'},
      ];

      // Exact match - high confidence >= 85%
      final okResult = VoiceCommandParser.parseCommand('e4', legalMoves);
      expect(okResult, equals(legalMoves[0]));

      // Medium confidence [70% - 85%]
      // Under the new confidence-gap design, there is no longer a fixed 85% execute threshold.
      // A move with 78% confidence (which is >= minAbsoluteConfidence of 70%) and a large gap
      // (no other candidates) will be auto-executed instead of returned as a suggestion list.
      final medIntent = VoiceIntent(
        piece: 'p',
        destinationSquare: 'e4',
        confidence: 0.80,
      );
      final medResult = LegalMoveMatcher.match(
        medIntent,
        legalMoves,
        sttConfidence: 0.50,
      );
      expect(medResult, equals(legalMoves[0]));

      // Low confidence < 70%
      final lowIntent = VoiceIntent(
        piece: 'p',
        destinationSquare: 'e4',
        confidence: 0.65,
      );
      final lowResult = LegalMoveMatcher.match(
        lowIntent,
        legalMoves,
        sttConfidence: 0.30,
      );
      expect(lowResult, isNotNull);
      expect(
        lowResult!['error'],
        contains("I'm only 65% confident. Did you mean e4?"),
      );
    });

    test('WordSimilarityService independent unit test', () {
      final sim = WordSimilarityService.similarity('ruk', 'rook');
      expect(sim, greaterThan(0.0));
      expect(sim, lessThan(1.0));

      final ranked = WordSimilarityService.rankedCandidates('ruk', [
        'bishop',
        'rook',
        'queen',
      ]);
      expect(ranked.first.candidate, equals('rook'));
      expect(ranked.first.score, greaterThan(ranked[1].score));
    });

    test('dictionary loading and configuration validity', () {
      // Piece dictionary loading
      expect(pieceDictionary.containsKey('knight'), isTrue);
      expect(pieceDictionary['knight'], contains('knight'));
      // File dictionary loading
      expect(fileDictionary.containsKey('a'), isTrue);
      expect(fileDictionary['a'], contains('ay'));
      // Rank dictionary loading
      expect(rankDictionary.containsKey('1'), isTrue);
      expect(rankDictionary['1'], contains('one'));
    });

    test('SquareNormalizer candidate pruning top 5 limit', () {
      final list = SquareNormalizer.rankedCandidates('bee ate');
      expect(list.length, lessThanOrEqualTo(5));
      expect(list.first.square, equals('b8'));
    });

    test('error messages and legal suggestion filtering test', () {
      final legalMoves = [
        {'from': 'b1', 'to': 'c3', 'piece': 'n', 'san': 'Nc3'},
        {'from': 'g1', 'to': 'c3', 'piece': 'n', 'san': 'Nf3'},
        {'from': 'b1', 'to': 'd2', 'piece': 'n', 'san': 'Nbd2'},
        {'from': 'f3', 'to': 'd2', 'piece': 'n', 'san': 'Nfd2'},
      ];

      // 1. Unrecognized piece error
      final errPiece = VoiceCommandParser.parseCommand(
        'invalid c3',
        legalMoves,
      );
      expect(errPiece, isNotNull);
      expect(errPiece!['error'], equals("I couldn't recognize the piece."));

      // 2. Unrecognized square error
      final errSquare = VoiceCommandParser.parseCommand(
        'knight x9',
        legalMoves,
      );
      expect(errSquare, isNotNull);
      expect(
        errSquare!['error'],
        equals("I couldn't recognize the destination square."),
      );

      // 3. Piece Mismatch Clarification (Recognition Noise Bypass)
      // Under Task 3 from Day 49.23, a piece mismatch when that piece cannot reach the
      // recognized square, but a different piece can, should return a mismatch clarification prompt.
      final errIllegal = VoiceCommandParser.parseCommand(
        'bishop c3',
        legalMoves,
      );
      expect(errIllegal, isNotNull);
      expect(
        errIllegal!['error'],
        equals(
          "I heard 'bishop' but that can't reach c3. Did you mean knight to c3?",
        ),
      );

      // 4. Ambiguity warning
      final errAmb = VoiceCommandParser.parseCommand('knight d2', legalMoves);
      expect(errAmb, isNotNull);
      expect(
        errAmb!['error'],
        equals("Two knights can move there. Please specify which one."),
      );
    });

    test('performance timing execution test', () {
      final legalMoves = [
        {'from': 'e2', 'to': 'e4', 'piece': 'p', 'san': 'e4'},
      ];
      final stopwatch = Stopwatch()..start();
      final result = VoiceCommandParser.parseCommand('e4', legalMoves);
      stopwatch.stop();
      expect(result, isNotNull);
      expect(stopwatch.elapsedMilliseconds, lessThan(20));
      debugPrint(
        'Performance test timing elapsed: ${stopwatch.elapsedMilliseconds} ms',
      );
    });
  });

  group('Voice Command - Widget & Integration Tests', () {
    late MockSpeechService mockSpeechService;

    setUp(() {
      mockSpeechService = MockSpeechService();
      SpeechService.instance = mockSpeechService;
    });

    tearDown(() {
      SpeechService.instance = RealSpeechService();
    });

    testWidgets(
      'microphone button triggers listening and displays recognized text',
      (WidgetTester tester) async {
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VoiceCommandWidget(onCommand: (cmd, {sttConfidence}) {}),
            ),
          ),
        );

        expect(find.byType(VoiceCommandWidget), findsOneWidget);
        expect(find.text('Voice Command'), findsOneWidget);
        expect(
          find.textContaining('Tap microphone and speak move'),
          findsOneWidget,
        );

        // Tap microphone to listen
        await tester.tap(find.byKey(const ValueKey('mic_button')));
        await tester.pump();

        expect(mockSpeechService.isListening, isTrue);
        expect(find.text('Listening...'), findsOneWidget);

        // Simulate speech input
        mockSpeechService.simulateSpeech('knight f3');
        await tester.pump();

        expect(find.text('"knight f3"'), findsOneWidget);
      },
    );

    testWidgets('valid recognized move executes on GameScreen', (
      WidgetTester tester,
    ) async {
      // Overriding size to prevent chess board hit testing warnings
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

      // Simulate valid legal move
      mockSpeechService.simulateSpeech('e2 e4');
      await tester.pump(const Duration(milliseconds: 500));

      // Board should update (from e2 to e4)
      final boardFinder = find.byType(ChessBoard);
      final boardWidget = tester.widget<ChessBoard>(boardFinder);
      expect(boardWidget.chessEngineService.getHistory().length, 1);
      expect(find.text('Selected Square:'), findsOneWidget);
    });

    testWidgets('invalid move displays error SnackBar and does not execute', (
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

      await tester.tap(find.byKey(const ValueKey('mic_button')));
      await tester.pump();

      // Simulate illegal/unrecognized move
      mockSpeechService.simulateSpeech('e2 e5');
      await tester.pump(const Duration(milliseconds: 500));

      // Move should NOT execute (moves count remains 0)
      final boardFinder = find.byType(ChessBoard);
      final boardWidget = tester.widget<ChessBoard>(boardFinder);
      expect(boardWidget.chessEngineService.getHistory().length, 0);
      expect(find.text("That move isn't legal."), findsOneWidget);
    });

    testWidgets(
      'tap-to-move still works perfectly alongside mic button presence',
      (WidgetTester tester) async {
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

        // Find ChessSquare E2 and tap it
        final e2SquareFinder = find.byWidgetPredicate(
          (widget) => widget is ChessSquare && widget.label == 'E2',
        );
        await tester.ensureVisible(e2SquareFinder);
        await tester.tap(e2SquareFinder);
        await tester.pumpAndSettle();

        // Assert square selection worked
        expect(find.text('Selected Square:'), findsOneWidget);
        expect(
          find.text('E2'),
          findsNWidgets(2),
        ); // label and Selected Square text
      },
    );

    testWidgets(
      'ambiguous shorthand move displays specific SnackBar in GameScreen',
      (WidgetTester tester) async {
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

        // Make moves to set up ambiguous King (e1) and Queen (d3) on d2
        // Move 1: d2 d4 (White pawn)
        await tester.tap(find.byKey(const ValueKey('mic_button')));
        await tester.pump();
        mockSpeechService.simulateSpeech('d2 d4');
        await tester.pump(const Duration(milliseconds: 500));

        // Move 2: Black moves e7 e5
        await tester.tap(find.byKey(const ValueKey('mic_button')));
        await tester.pump();
        mockSpeechService.simulateSpeech('e7 e5');
        await tester.pump(const Duration(milliseconds: 500));

        // Move 3: Qd3 (d1-d3)
        await tester.tap(find.byKey(const ValueKey('mic_button')));
        await tester.pump();
        mockSpeechService.simulateSpeech('d1 d3');
        await tester.pump(const Duration(milliseconds: 500));

        // Move 4: Black captures exd4 (e5 d4)
        await tester.tap(find.byKey(const ValueKey('mic_button')));
        await tester.pump();
        mockSpeechService.simulateSpeech('e5 d4');
        await tester.pump(const Duration(milliseconds: 500));

        // Now both White King on e1 and Queen on d3 can move to d2!
        // Speak "d2"
        await tester.tap(find.byKey(const ValueKey('mic_button')));
        await tester.pump();
        mockSpeechService.simulateSpeech('d2');
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          find.textContaining("Ambiguous voice command. Candidates:"),
          findsOneWidget,
        );
      },
    );

    testWidgets('successful voice commands execution sequence', (
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

      // 1. White speaks "night f3"
      await tester.tap(find.byKey(const ValueKey('mic_button')));
      await tester.pump();
      mockSpeechService.simulateSpeech('night f3');
      await tester.pump(const Duration(milliseconds: 500));

      // 2. Black moves e7 e5
      await tester.tap(find.byKey(const ValueKey('mic_button')));
      await tester.pump();
      mockSpeechService.simulateSpeech('e7 e5');
      await tester.pump(const Duration(milliseconds: 500));

      // 3. White speaks "bishop c4"
      await tester.tap(find.byKey(const ValueKey('mic_button')));
      await tester.pump();
      mockSpeechService.simulateSpeech('bishop c4');
      await tester.pump(const Duration(milliseconds: 500));

      // 4. Black moves d7 d6
      await tester.tap(find.byKey(const ValueKey('mic_button')));
      await tester.pump();
      mockSpeechService.simulateSpeech('d7 d6');
      await tester.pump(const Duration(milliseconds: 500));

      // 5. White speaks "queen e2"
      await tester.tap(find.byKey(const ValueKey('mic_button')));
      await tester.pump();
      mockSpeechService.simulateSpeech('queen e2');
      await tester.pump(const Duration(milliseconds: 500));

      // 6. Black moves a7 a6
      await tester.tap(find.byKey(const ValueKey('mic_button')));
      await tester.pump();
      mockSpeechService.simulateSpeech('a7 a6');
      await tester.pump(const Duration(milliseconds: 500));

      // 7. White moves queen back to d1 (e2 d1)
      await tester.tap(find.byKey(const ValueKey('mic_button')));
      await tester.pump();
      mockSpeechService.simulateSpeech('e2 d1');
      await tester.pump(const Duration(milliseconds: 500));

      // 8. Black moves h7 h6
      await tester.tap(find.byKey(const ValueKey('mic_button')));
      await tester.pump();
      mockSpeechService.simulateSpeech('h7 h6');
      await tester.pump(const Duration(milliseconds: 500));

      // 9. White speaks "king e2"
      await tester.tap(find.byKey(const ValueKey('mic_button')));
      await tester.pump();
      mockSpeechService.simulateSpeech('king e2');
      await tester.pump(const Duration(milliseconds: 500));

      // 10. Black moves g7 g6
      await tester.tap(find.byKey(const ValueKey('mic_button')));
      await tester.pump();
      mockSpeechService.simulateSpeech('g7 g6');
      await tester.pump(const Duration(milliseconds: 500));

      // 11. White speaks "rook e1"
      await tester.tap(find.byKey(const ValueKey('mic_button')));
      await tester.pump();
      mockSpeechService.simulateSpeech('rook e1');
      await tester.pump(const Duration(milliseconds: 500));
    });

    test('DiagnosticRecorder and Failure Classification tests', () {
      final legalMoves = [
        {'from': 'e2', 'to': 'e4', 'piece': 'p', 'san': 'e4'},
        {'from': 'b1', 'to': 'c3', 'piece': 'n', 'san': 'Nc3'},
        {'from': 'g1', 'to': 'f3', 'piece': 'n', 'san': 'Nf3'},
      ];

      DiagnosticRecorder.instance.clear();
      expect(DiagnosticRecorder.instance.records, isEmpty);

      // 1. Success parse
      final result1 = VoiceCommandParser.parseCommand(
        'e4',
        legalMoves,
        sttConfidence: 0.95,
      );
      expect(result1, isNotNull);
      expect(DiagnosticRecorder.instance.records.length, 1);
      final r1 = DiagnosticRecorder.instance.records.first;
      expect(r1.rawSpeech, 'e4');
      expect(r1.recognizedText, 'e4');
      expect(r1.failureReason, isNull);
      expect(r1.finalResult, 'e4');

      // 2. Speech recognition failed
      VoiceCommandParser.parseCommand('', legalMoves);
      expect(
        DiagnosticRecorder.instance.records.last.failureReason,
        'Speech recognition failed',
      );

      // 3. Piece not recognized
      VoiceCommandParser.parseCommand('hello e4', legalMoves);
      expect(
        DiagnosticRecorder.instance.records.last.failureReason,
        'Piece not recognized',
      );

      // 4. Destination not recognized
      VoiceCommandParser.parseCommand('knight x9', legalMoves);
      expect(
        DiagnosticRecorder.instance.records.last.failureReason,
        'Destination not recognized',
      );

      // 5. Confidence too low
      VoiceCommandParser.parseCommand('e4', legalMoves, sttConfidence: 0.60);
      expect(
        DiagnosticRecorder.instance.records.last.failureReason,
        'Confidence too low',
      );

      // 6. Move not legal
      VoiceCommandParser.parseCommand('knight e5', legalMoves);
      expect(
        DiagnosticRecorder.instance.records.last.failureReason,
        'Move not legal',
      );

      // 7. Ambiguous move
      VoiceCommandParser.parseCommand('knight c3', [
        {'from': 'b1', 'to': 'c3', 'piece': 'n', 'san': 'Nbc3'},
        {'from': 'e2', 'to': 'c3', 'piece': 'n', 'san': 'Nec3'},
      ]);
      expect(
        DiagnosticRecorder.instance.records.last.failureReason,
        'Ambiguous move',
      );

      // 8. Execution failed
      DiagnosticRecorder.instance.updateLastRecordExecution(success: false);
      expect(
        DiagnosticRecorder.instance.records.last.failureReason,
        'Execution failed',
      );

      // 9. Memory limit constraint (100)
      for (int i = 0; i < 150; i++) {
        VoiceCommandParser.parseCommand('e4', legalMoves);
      }
      expect(DiagnosticRecorder.instance.records.length, 100);
    });

    test('SettingsService isVoiceDebugMode toggle works', () async {
      SettingsService.instance.resetToDefaults();
      expect(SettingsService.instance.isVoiceDebugMode, equals(kDebugMode));
      await SettingsService.instance.setVoiceDebugMode(!kDebugMode);
      expect(SettingsService.instance.isVoiceDebugMode, equals(!kDebugMode));
    });

    test('Phonetic Recognition Engine - Regression Tests', () {
      final legalMoves = [
        {'from': 'g1', 'to': 'f3', 'piece': 'n', 'san': 'Nf3'},
        {'from': 'a1', 'to': 'b1', 'piece': 'r', 'san': 'Rab1'},
        {'from': 'd1', 'to': 'f3', 'piece': 'q', 'san': 'Qf3'},
        {'from': 'c1', 'to': 'e3', 'piece': 'b', 'san': 'Be3'},
        {'from': 'e1', 'to': 'e2', 'piece': 'k', 'san': 'Ke2'},
        {'from': 'b2', 'to': 'f3', 'piece': 'p', 'san': 'bxf3'},
        {'from': 'c2', 'to': 'd3', 'piece': 'p', 'san': 'cxd3'},
        {'from': 'd3', 'to': 'e4', 'piece': 'p', 'san': 'dxe4'},
        {'from': 'f4', 'to': 'g5', 'piece': 'p', 'san': 'fxg5'},
        {'from': 'g5', 'to': 'f6', 'piece': 'p', 'san': 'gxf6'},
        {'from': 'h5', 'to': 'g6', 'piece': 'p', 'san': 'hxg6'},
      ];

      // Pieces phonetic homophones
      expect(
        VoiceCommandParser.parseCommand('knight f3', legalMoves),
        equals(legalMoves[0]),
      );
      expect(
        VoiceCommandParser.parseCommand('night f3', legalMoves),
        equals(legalMoves[0]),
      );
      expect(
        VoiceCommandParser.parseCommand('nite f3', legalMoves),
        equals(legalMoves[0]),
      );
      expect(
        VoiceCommandParser.parseCommand('n8 f3', legalMoves),
        equals(legalMoves[0]),
      );

      expect(
        VoiceCommandParser.parseCommand('rook b1', legalMoves),
        equals(legalMoves[1]),
      );
      expect(
        VoiceCommandParser.parseCommand('ruk b1', legalMoves),
        equals(legalMoves[1]),
      );
      expect(
        VoiceCommandParser.parseCommand('rok b1', legalMoves),
        equals(legalMoves[1]),
      );
      expect(
        VoiceCommandParser.parseCommand('rock b1', legalMoves),
        equals(legalMoves[1]),
      );

      expect(
        VoiceCommandParser.parseCommand('queen f3', legalMoves),
        equals(legalMoves[2]),
      );
      expect(
        VoiceCommandParser.parseCommand('qeen f3', legalMoves),
        equals(legalMoves[2]),
      );
      expect(
        VoiceCommandParser.parseCommand('kween f3', legalMoves),
        equals(legalMoves[2]),
      );
      expect(
        VoiceCommandParser.parseCommand('quean f3', legalMoves),
        equals(legalMoves[2]),
      );

      expect(
        VoiceCommandParser.parseCommand('bishop e3', legalMoves),
        equals(legalMoves[3]),
      );
      expect(
        VoiceCommandParser.parseCommand('bishup e3', legalMoves),
        equals(legalMoves[3]),
      );
      expect(
        VoiceCommandParser.parseCommand('bisop e3', legalMoves),
        equals(legalMoves[3]),
      );

      expect(
        VoiceCommandParser.parseCommand('king e2', legalMoves),
        equals(legalMoves[4]),
      );
      expect(
        VoiceCommandParser.parseCommand('keng e2', legalMoves),
        equals(legalMoves[4]),
      );
      expect(
        VoiceCommandParser.parseCommand('kin e2', legalMoves),
        equals(legalMoves[4]),
      );

      // Files homophones
      expect(
        VoiceCommandParser.parseCommand('bee f3', legalMoves),
        equals(legalMoves[5]),
      );
      expect(
        VoiceCommandParser.parseCommand('be f3', legalMoves),
        equals(legalMoves[5]),
      );
      expect(
        VoiceCommandParser.parseCommand('v f3', legalMoves),
        equals(legalMoves[5]),
      );

      expect(
        VoiceCommandParser.parseCommand('sea d3', legalMoves),
        equals(legalMoves[6]),
      );
      expect(
        VoiceCommandParser.parseCommand('see d3', legalMoves),
        equals(legalMoves[6]),
      );
      expect(
        VoiceCommandParser.parseCommand('cee d3', legalMoves),
        equals(legalMoves[6]),
      );

      expect(
        VoiceCommandParser.parseCommand('dee e4', legalMoves),
        equals(legalMoves[7]),
      );
      expect(
        VoiceCommandParser.parseCommand('eff g5', legalMoves),
        equals(legalMoves[8]),
      );
      expect(
        VoiceCommandParser.parseCommand('gee f6', legalMoves),
        equals(legalMoves[9]),
      );
      expect(
        VoiceCommandParser.parseCommand('aitch g6', legalMoves),
        equals(legalMoves[10]),
      );

      // Ranks / Numbers homophones
      final numMoves = [
        {'from': 'e2', 'to': 'e4', 'piece': 'p', 'san': 'e4'},
        {'from': 'e2', 'to': 'e1', 'piece': 'p', 'san': 'e1'},
        {'from': 'e2', 'to': 'e2', 'piece': 'p', 'san': 'e2'},
        {'from': 'e2', 'to': 'e8', 'piece': 'p', 'san': 'e8'},
      ];
      expect(
        VoiceCommandParser.parseCommand('e won', numMoves),
        equals(numMoves[1]),
      );
      expect(
        VoiceCommandParser.parseCommand('e one', numMoves),
        equals(numMoves[1]),
      );
      expect(
        VoiceCommandParser.parseCommand('e to', numMoves),
        equals(numMoves[2]),
      );
      expect(
        VoiceCommandParser.parseCommand('e too', numMoves),
        equals(numMoves[2]),
      );
      expect(
        VoiceCommandParser.parseCommand('e for', numMoves),
        equals(numMoves[0]),
      );
      expect(
        VoiceCommandParser.parseCommand('e fore', numMoves),
        equals(numMoves[0]),
      );
      expect(
        VoiceCommandParser.parseCommand('e ate', numMoves),
        equals(numMoves[3]),
      );
      expect(
        VoiceCommandParser.parseCommand('e eight', numMoves),
        equals(numMoves[3]),
      );
    });

    test('Day 49.24 - Rock h e one to Re1 ranking bug regression test', () {
      final legalMoves = [
        {'from': 'g5', 'to': 'f6', 'piece': 'b', 'san': 'Bf6'},
        {'from': 'g5', 'to': 'e7', 'piece': 'b', 'san': 'Be7'},
        {'from': 'g5', 'to': 'd8', 'piece': 'b', 'san': 'Bd8'},
        {'from': 'g5', 'to': 'h6', 'piece': 'b', 'san': 'Bxh6'},
        {'from': 'g5', 'to': 'h4', 'piece': 'b', 'san': 'Bh4'},
        {'from': 'g5', 'to': 'f4', 'piece': 'b', 'san': 'Bf4'},
        {'from': 'g5', 'to': 'e3', 'piece': 'b', 'san': 'Be3'},
        {'from': 'g5', 'to': 'd2', 'piece': 'b', 'san': 'Bd2'},
        {'from': 'b3', 'to': 'a4', 'piece': 'b', 'san': 'Ba4'},
        {'from': 'b3', 'to': 'c4', 'piece': 'b', 'san': 'Bc4'},
        {'from': 'd3', 'to': 'c4', 'piece': 'q', 'san': 'Qc4'},
        {'from': 'd3', 'to': 'b5', 'piece': 'q', 'san': 'Qb5'},
        {'from': 'd3', 'to': 'a6', 'piece': 'q', 'san': 'Qa6'},
        {'from': 'd3', 'to': 'd4', 'piece': 'q', 'san': 'Qd4'},
        {'from': 'd3', 'to': 'e3', 'piece': 'q', 'san': 'Qe3'},
        {'from': 'd3', 'to': 'e2', 'piece': 'q', 'san': 'Qe2'},
        {'from': 'd3', 'to': 'f1', 'piece': 'q', 'san': 'Qf1'},
        {'from': 'd3', 'to': 'd2', 'piece': 'q', 'san': 'Qd2'},
        {'from': 'd3', 'to': 'd1', 'piece': 'q', 'san': 'Qd1'},
        {'from': 'd3', 'to': 'c3', 'piece': 'q', 'san': 'Qc3'},
        {'from': 'f3', 'to': 'd4', 'piece': 'n', 'san': 'Nd4'},
        {'from': 'f3', 'to': 'e5', 'piece': 'n', 'san': 'Nxe5'},
        {'from': 'f3', 'to': 'h4', 'piece': 'n', 'san': 'Nh4'},
        {'from': 'f3', 'to': 'e1', 'piece': 'n', 'san': 'Ne1'},
        {'from': 'f3', 'to': 'd2', 'piece': 'n', 'san': 'Nd2'},
        {'from': 'a2', 'to': 'a3', 'piece': 'p', 'san': 'a3'},
        {'from': 'a2', 'to': 'a4', 'piece': 'p', 'san': 'a4'},
        {'from': 'c2', 'to': 'c3', 'piece': 'p', 'san': 'c3'},
        {'from': 'c2', 'to': 'c4', 'piece': 'p', 'san': 'c4'},
        {'from': 'g2', 'to': 'g3', 'piece': 'p', 'san': 'g3'},
        {'from': 'h2', 'to': 'h3', 'piece': 'p', 'san': 'h3'},
        {'from': 'h2', 'to': 'h4', 'piece': 'p', 'san': 'h4'},
        {'from': 'c1', 'to': 'd2', 'piece': 'k', 'san': 'Kd2'},
        {'from': 'c1', 'to': 'd1', 'piece': 'k', 'san': 'Kd1'},
        {'from': 'c1', 'to': 'b1', 'piece': 'k', 'san': 'Kb1'},
        {'from': 'g1', 'to': 'f1', 'piece': 'r', 'san': 'Rf1'},
        {'from': 'g1', 'to': 'e1', 'piece': 'r', 'san': 'Re1'},
        {'from': 'g1', 'to': 'd1', 'piece': 'r', 'san': 'Rd1'},
      ];

      final result = VoiceCommandParser.parseCommand(
        'Rock h e one',
        legalMoves,
        boardFen:
            'r3r1k1/ppp2ppp/1b1p3n/3Pq1B1/4P1b1/1B1Q1N2/PPP2PPP/2K3RR w - - 2 17',
      );

      expect(result, equals(legalMoves[36])); // Re1

      final errResult = VoiceCommandParser.parseCommand(
        'Rock h',
        legalMoves,
        boardFen:
            'r3r1k1/ppp2ppp/1b1p3n/3Pq1B1/4P1b1/1B1Q1N2/PPP2PPP/2K3RR w - - 2 17',
      );
      expect(errResult, isNotNull);
      expect(
        errResult!['error'],
        equals("I couldn't recognize the destination square."),
      );
    });

    test(
      'VoiceRegressionService auto-generates test files and diagnostic summaries',
      () {
        final legalMoves = [
          {'from': 'g1', 'to': 'f3', 'piece': 'n', 'san': 'Nf3'},
        ];
        final intent = VoiceIntent(
          piece: 'n',
          destinationSquare: 'f3',
          confidence: 0.85,
        );

        final testFile = File(
          'test/voice_regressions/debug_test_regression_test.dart',
        );
        if (testFile.existsSync()) {
          testFile.deleteSync();
        }

        final prevVal = VoiceRegressionService.enableGeneration;
        VoiceRegressionService.enableGeneration = true;

        try {
          VoiceRegressionService.handleFailure(
            rawSpeech: 'debug test regression',
            boardFen:
                'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
            legalMoves: legalMoves,
            failureReason: 'Piece not recognized',
            sttConfidence: 0.90,
            intent: intent,
          );

          expect(testFile.existsSync(), isTrue);

          final contents = testFile.readAsStringSync();
          expect(
            contents,
            contains("test('Voice Regression - debug test regression'"),
          );
          expect(contents, contains("final legalMoves ="));
          expect(contents, contains("san': 'Nf3'"));
          expect(contents, contains("Failure Reason: Piece not recognized"));
        } finally {
          VoiceRegressionService.enableGeneration = prevVal;
          if (testFile.existsSync()) {
            testFile.deleteSync();
          }
        }
      },
    );
  });
}
