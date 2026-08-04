// This is a basic Flutter widget test for screen separation, navigation, state management, and custom widgets.

import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blind_chess/main.dart';
import 'package:blind_chess/screens/home_screen.dart';
import 'package:blind_chess/screens/game_screen.dart';
import 'package:blind_chess/widgets/chess_square.dart';
import 'package:blind_chess/models/board.dart';
import 'package:blind_chess/models/chess_piece.dart';
import 'package:blind_chess/services/chess_engine_service.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:blind_chess/services/statistics_service.dart';
import 'package:blind_chess/services/settings_service.dart';

void main() {
  setUp(() {
    SettingsService.instance.resetToDefaults();
  });

  testWidgets('BlindChess screen transition and 8x8 Chessboard test', (
    WidgetTester tester,
  ) async {
    // 1. Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // 2. Verify that we start on the HomeScreen.
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Welcome to BlindChess'), findsOneWidget);

    // Verify ProgressCard/lessons do NOT exist on HomeScreen
    expect(find.text('Learning Progress'), findsNothing);
    expect(find.text('Completed Lessons: 0'), findsNothing);
    expect(find.text('Complete Lesson'), findsNothing);

    // 3. Tap the 'Start Game' button to navigate.
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    // 4. Verify we are now on the GameScreen.
    expect(find.byType(GameScreen), findsOneWidget);
    expect(
      find.text('BlindChess Learning Mode'),
      findsNothing,
    ); // Verify old title is gone
    expect(
      find.text('Future memory training exercises will appear here.'),
      findsNothing,
    ); // Verify old subtitle is gone

    // Verify Chessboard header and 64 ChessSquare widgets are visible
    expect(find.text('Chess Match'), findsOneWidget);
    expect(find.byType(ChessSquare), findsNWidgets(64));

    // Verify corners
    List<ChessSquare> getChessSquares() {
      return tester.widgetList<ChessSquare>(find.byType(ChessSquare)).toList();
    }

    ChessSquare getSquareByLabel(String label) {
      return tester.widget<ChessSquare>(
        find.byWidgetPredicate(
          (widget) => widget is ChessSquare && widget.label == label,
        ),
      );
    }

    expect(getChessSquares()[0].label, 'A8');
    expect(getChessSquares()[0].piece?.pieceType, PieceType.rook);
    expect(getChessSquares()[7].label, 'H8');
    expect(getChessSquares()[7].piece?.pieceType, PieceType.rook);
    expect(getChessSquares()[56].label, 'A1');
    expect(getChessSquares()[56].piece?.pieceType, PieceType.rook);
    expect(getChessSquares()[63].label, 'H1');
    expect(getChessSquares()[63].piece?.pieceType, PieceType.rook);

    // Tap Flip Board button to swap to Black's perspective
    final flipButton = find.widgetWithText(ElevatedButton, 'Flip Board');
    expect(flipButton, findsOneWidget);
    await tester.ensureVisible(flipButton);
    await tester.tap(flipButton);
    await tester.pumpAndSettle();

    // Verify the corners of the board in Black's perspective
    expect(getChessSquares()[0].label, 'H1');
    expect(getChessSquares()[0].piece?.pieceType, PieceType.rook);
    expect(getChessSquares()[7].label, 'A1');
    expect(getChessSquares()[7].piece?.pieceType, PieceType.rook);
    expect(getChessSquares()[56].label, 'H8');
    expect(getChessSquares()[56].piece?.pieceType, PieceType.rook);
    expect(getChessSquares()[63].label, 'A8');
    expect(getChessSquares()[63].piece?.pieceType, PieceType.rook);

    // Flip back to White's perspective for the remainder of the test
    await tester.tap(flipButton);
    await tester.pumpAndSettle();

    // Verify that the initial selection text is "None"
    expect(find.text('Selected Square:'), findsOneWidget);
    expect(find.text('None'), findsOneWidget);

    // Test tapping a chess square (D2) triggers the callback, shows a SnackBar, and updates selection
    final d2SquareFirst = find.widgetWithText(ChessSquare, 'D2');
    await tester.ensureVisible(d2SquareFirst);
    await tester.tap(d2SquareFirst);
    await tester.pumpAndSettle(); // Settle state updates and SnackBar animation

    // Verify SnackBar message appears
    expect(find.text('You tapped D2'), findsOneWidget);

    // Dismiss SnackBars to avoid overlaying other interactive buttons
    ScaffoldMessenger.of(
      tester.element(find.byType(GameScreen)),
    ).clearSnackBars();
    await tester.pumpAndSettle();

    // Verify Selected Square updates to D2
    expect(
      find.text('D2'),
      findsNWidgets(2),
    ); // The square label and the Selected Square display text
    expect(find.text('None'), findsNothing);

    // Assert that the ChessSquare widget has isSelected set to true
    final d2ChessSquareFirst = tester.widget<ChessSquare>(d2SquareFirst);
    expect(d2ChessSquareFirst.isSelected, isTrue);

    // Assert that another ChessSquare (e.g. A1) is not selected
    final a1ChessSquare = tester.widget<ChessSquare>(
      find.widgetWithText(ChessSquare, 'A1'),
    );
    expect(a1ChessSquare.isSelected, isFalse);

    // Test legal move highlighting: tap white pawn E2
    final e2SquareFinder = find.byWidgetPredicate(
      (widget) => widget is ChessSquare && widget.label == 'E2',
    );
    await tester.ensureVisible(e2SquareFinder);
    await tester.tap(e2SquareFinder);
    await tester.pumpAndSettle();

    // Verify selection state of E2 is true
    expect(getSquareByLabel('E2').isSelected, isTrue);

    // Verify destinations E3 and E4 are highlighted (have green blended colors)
    final e3SquareWidget = getSquareByLabel('E3');
    final e4SquareWidget = getSquareByLabel('E4');
    expect(
      e3SquareWidget.squareColor,
      Color.lerp(const Color(0xFFB58863), Colors.green, 0.3),
      reason: 'E3 should be highlighted (brown blended with green)',
    );
    expect(
      e4SquareWidget.squareColor,
      Color.lerp(const Color(0xFFF0D9B5), Colors.green, 0.3),
      reason: 'E4 should be highlighted (white blended with green)',
    );

    // Verify non-destination squares (e.g., E5, E1) are NOT highlighted
    final e5Square = getSquareByLabel('E5');
    final e1Square = getSquareByLabel('E1');
    expect(
      e5Square.squareColor,
      const Color(0xFFB58863),
      reason: 'E5 should not be highlighted',
    );
    expect(
      e1Square.squareColor,
      const Color(0xFFB58863),
      reason: 'E1 should not be highlighted',
    );

    // Tap E2 again to deselect
    await tester.tap(e2SquareFinder);
    await tester.pumpAndSettle();

    // Verify E2 selection is cleared and highlights are cleared
    expect(getSquareByLabel('E2').isSelected, isFalse);
    expect(
      getSquareByLabel('E3').squareColor,
      const Color(0xFFB58863),
      reason: 'E3 highlight should be cleared',
    );
    expect(
      getSquareByLabel('E4').squareColor,
      const Color(0xFFF0D9B5),
      reason: 'E4 highlight should be cleared',
    );

    // Tap a piece with no legal moves (e.g. A1 Rook)
    final a1SquareFinder = find.byWidgetPredicate(
      (widget) => widget is ChessSquare && widget.label == 'A1',
    );
    await tester.ensureVisible(a1SquareFinder);
    await tester.tap(a1SquareFinder);
    await tester.pumpAndSettle();

    // Verify A1 is selected
    expect(getSquareByLabel('A1').isSelected, isTrue);

    // Verify no squares are highlighted (all other squares retain their base colors)
    expect(
      getSquareByLabel('A2').squareColor,
      const Color(0xFFF0D9B5),
      reason: 'A2 should not be highlighted',
    );
    expect(
      getSquareByLabel('B1').squareColor,
      const Color(0xFFF0D9B5),
      reason: 'B1 should not be highlighted',
    );

    // Dismiss SnackBar from A1 tap
    ScaffoldMessenger.of(
      tester.element(find.byType(GameScreen)),
    ).clearSnackBars();
    await tester.pumpAndSettle();

    // Verify ProgressCard / lessons are NOT present on GameScreen
    expect(find.text('Complete Lesson'), findsNothing);

    // 5. Tap the 'Back Home' button to pop back.
    final backHomeButton = find.text('Back Home');
    await tester.ensureVisible(backHomeButton);
    await tester.tap(backHomeButton);
    await tester.pumpAndSettle();

    // 6. Verify we are returned to the HomeScreen and ProgressCard is still absent.
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Learning Progress'), findsNothing);
  });

  testWidgets(
    'BlindChess - select E2, tap E4, asserts white pawn now at E4 and E2 is empty',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      Future<void> tapSquare(String label) async {
        final f = find.byWidgetPredicate(
          (w) => w is ChessSquare && w.label == label,
        );
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      ChessSquare getSquare(String label) {
        return tester.widget<ChessSquare>(
          find.byWidgetPredicate((w) => w is ChessSquare && w.label == label),
        );
      }

      // Tap E2 (White Pawn)
      await tapSquare('E2');
      expect(getSquare('E2').isSelected, isTrue);

      // Tap E4 (Highlighted legal destination)
      await tapSquare('E4');

      // Assert white pawn is now at E4 and E2 is empty
      expect(getSquare('E4').piece?.symbol, '♙');
      expect(getSquare('E2').piece, isNull);

      // Assert last-move highlights are applied (subtle yellow tint)
      expect(
        getSquare('E2').squareColor,
        Color.lerp(const Color(0xFFF0D9B5), Colors.yellow, 0.15),
      );
      expect(
        getSquare('E4').squareColor,
        Color.lerp(const Color(0xFFF0D9B5), Colors.yellow, 0.15),
      );
    },
  );

  testWidgets('BlindChess - play short move sequence 1. e4 e5 2. Nf3 Nc6', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    Future<void> tapSquare(String label) async {
      final f = find.byWidgetPredicate(
        (w) => w is ChessSquare && w.label == label,
      );
      await tester.ensureVisible(f);
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    // 1. e4
    await tapSquare('E2');
    await tapSquare('E4');

    // 1... e5
    await tapSquare('E7');
    await tapSquare('E5');

    // 2. Nf3
    await tapSquare('G1');
    await tapSquare('F3');

    // 2... Nc6
    await tapSquare('B8');
    await tapSquare('C6');

    ChessSquare getSquare(String label) {
      return tester.widget<ChessSquare>(
        find.byWidgetPredicate((w) => w is ChessSquare && w.label == label),
      );
    }

    // Assert final state
    expect(getSquare('E4').piece?.symbol, '♙'); // White Pawn
    expect(getSquare('E5').piece?.symbol, '♟'); // Black Pawn
    expect(getSquare('F3').piece?.symbol, '♘'); // White Knight
    expect(getSquare('C6').piece?.symbol, '♞'); // Black Knight
  });

  testWidgets('BlindChess - play capture 1. e4 d5 2. exd5', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    Future<void> tapSquare(String label) async {
      final f = find.byWidgetPredicate(
        (w) => w is ChessSquare && w.label == label,
      );
      await tester.ensureVisible(f);
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    // 1. e4
    await tapSquare('E2');
    await tapSquare('E4');

    // 1... d5
    await tapSquare('D7');
    await tapSquare('D5');

    // 2. exd5
    await tapSquare('E4');
    await tapSquare('D5');

    ChessSquare getSquare(String label) {
      return tester.widget<ChessSquare>(
        find.byWidgetPredicate((w) => w is ChessSquare && w.label == label),
      );
    }

    // Assert capture: White Pawn is now at D5, and E4 is empty
    expect(getSquare('D5').piece?.symbol, '♙');
    expect(getSquare('E4').piece, isNull);
  });

  testWidgets('BlindChess - turn enforcement prevents out-of-turn selection', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    Future<void> tapSquare(String label) async {
      final f = find.byWidgetPredicate(
        (w) => w is ChessSquare && w.label == label,
      );
      await tester.ensureVisible(f);
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    ChessSquare getSquare(String label) {
      return tester.widget<ChessSquare>(
        find.byWidgetPredicate((w) => w is ChessSquare && w.label == label),
      );
    }

    // Attempt to tap Black Pawn E7 on Move 1 (White's turn)
    await tapSquare('E7');

    // E7 should NOT be selected, and its destination E6/E5 should NOT be highlighted
    expect(getSquare('E7').isSelected, isFalse);
    expect(getSquare('E6').squareColor, const Color(0xFFF0D9B5));
    expect(getSquare('E5').squareColor, const Color(0xFFB58863));
  });

  testWidgets(
    'BlindChess - Fool\'s Mate checkmate ends game and freezes board',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      Future<void> tapSquare(String label) async {
        final f = find.byWidgetPredicate(
          (w) => w is ChessSquare && w.label == label,
        );
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      ChessSquare getSquare(String label) {
        return tester.widget<ChessSquare>(
          find.byWidgetPredicate((w) => w is ChessSquare && w.label == label),
        );
      }

      // 1. f3
      await tapSquare('F2');
      await tapSquare('F3');

      // 1... e5
      await tapSquare('E7');
      await tapSquare('E5');

      // 2. g4
      await tapSquare('G2');
      await tapSquare('G4');

      // 2... Qh4#
      await tapSquare('D8');
      await tapSquare('H4');

      // Verify checkmate dialog is displayed with "Checkmate — Black wins."
      expect(find.text('Checkmate'), findsOneWidget);
      expect(find.text('Checkmate — Black wins.'), findsOneWidget);

      // Tap "OK" to dismiss dialog to test board freeze
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Board should be frozen: tapping E2 should NOT select it
      await tapSquare('E2');
      expect(getSquare('E2').isSelected, isFalse);
    },
  );

  testWidgets(
    'BlindChess - check indicator shows red glow and disappears when resolved',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      Future<void> tapSquare(String label) async {
        final f = find.byWidgetPredicate(
          (w) => w is ChessSquare && w.label == label,
        );
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      ChessSquare getSquare(String label) {
        return tester.widget<ChessSquare>(
          find.byWidgetPredicate((w) => w is ChessSquare && w.label == label),
        );
      }

      // 1. e4
      await tapSquare('E2');
      await tapSquare('E4');

      // 1... e5
      await tapSquare('E7');
      await tapSquare('E5');

      // 2. Qh5
      await tapSquare('D1');
      await tapSquare('H5');

      // 2... Nc6
      await tapSquare('B8');
      await tapSquare('C6');

      // 3. Qxf7+ (check)
      await tapSquare('H5');
      await tapSquare('F7');

      // Verify King on E8 is in check (using isCheck)
      expect(
        getSquare('E8').isCheck,
        isTrue,
        reason: 'E8 King should show check glow',
      );

      // Resolve check: 3... Kxf7
      await tapSquare('E8');
      await tapSquare('F7');

      // Verify check is resolved and glow is gone
      expect(
        getSquare('F7').isCheck,
        isFalse,
        reason: 'F7 King should no longer show check glow',
      );
    },
  );

  testWidgets(
    'BlindChess - stalemate detection pops stalemate dialog and freezes board',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      // Obtain state to inject stalemate FEN
      final finder = find.byType(GameScreen);
      final state = tester.state(finder);
      final dynamic dynamicState = state;

      // Load stalemate FEN: k7/8/1Q6/8/8/8/8/4K3 b - - 0 1
      dynamicState.chessEngineService.load('k7/8/1Q6/8/8/8/8/4K3 b - - 0 1');

      // Rebuild the state and check status
      tester.binding.scheduleFrame();
      dynamicState.setState(() {
        dynamicState.checkGameStatus();
      });
      await tester.pumpAndSettle();

      // Verify stalemate dialog is displayed
      expect(find.text('Stalemate'), findsOneWidget);
      expect(find.text('Stalemate — Draw.'), findsOneWidget);

      // Tap "OK" to dismiss dialog to test board freeze
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Board should be frozen: tapping E1 should NOT select it
      final e1Finder = find.byWidgetPredicate(
        (w) => w is ChessSquare && w.label == 'E1',
      );
      await tester.ensureVisible(e1Finder);
      await tester.tap(e1Finder);
      await tester.pumpAndSettle();

      expect(dynamicState.selectedSquare, isNull);
    },
  );

  testWidgets('BlindChess - castling moves both king and rook', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    final finder = find.byType(GameScreen);
    final state = tester.state(finder);
    final dynamic dynamicState = state;

    // Load castling-ready FEN
    dynamicState.chessEngineService.load(
      'r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1',
    );
    tester.binding.scheduleFrame();
    dynamicState.setState(() {});
    await tester.pumpAndSettle();

    Future<void> tapSquare(String label) async {
      final f = find.byWidgetPredicate(
        (w) => w is ChessSquare && w.label == label,
      );
      await tester.ensureVisible(f);
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    ChessSquare getSquare(String label) {
      return tester.widget<ChessSquare>(
        find.byWidgetPredicate((w) => w is ChessSquare && w.label == label),
      );
    }

    // Tap White King on E1
    await tapSquare('E1');

    // Assert castling destination G1 and C1 are in highlights
    expect(
      dynamicState.highlightedSquares.contains((7, 6)),
      isTrue,
      reason: 'G1 should be highlighted',
    );
    expect(
      dynamicState.highlightedSquares.contains((7, 2)),
      isTrue,
      reason: 'C1 should be highlighted',
    );

    // Tap G1 (Kingside castle)
    await tapSquare('G1');

    // Assert King is at G1 (row 7, col 6) and Rook is at F1 (row 7, col 5)
    expect(getSquare('G1').piece?.pieceType, PieceType.king);
    expect(getSquare('F1').piece?.pieceType, PieceType.rook);
    expect(getSquare('E1').piece, isNull);
    expect(getSquare('H1').piece, isNull);
  });

  testWidgets('BlindChess - en passant captures adjacent pawn', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    final finder = find.byType(GameScreen);
    final state = tester.state(finder);
    final dynamic dynamicState = state;

    // Load en-passant-ready FEN (White pawn on e5, Black pawn just advanced d7->d5, en passant square d6)
    dynamicState.chessEngineService.load(
      'rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR w KQkq f6 0 3',
    );
    tester.binding.scheduleFrame();
    dynamicState.setState(() {});
    await tester.pumpAndSettle();

    Future<void> tapSquare(String label) async {
      final f = find.byWidgetPredicate(
        (w) => w is ChessSquare && w.label == label,
      );
      await tester.ensureVisible(f);
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    ChessSquare getSquare(String label) {
      return tester.widget<ChessSquare>(
        find.byWidgetPredicate((w) => w is ChessSquare && w.label == label),
      );
    }

    // Tap White Pawn on E5 (row 3, col 4)
    await tapSquare('E5');

    // Assert F6 is highlighted (en passant capture square)
    expect(
      dynamicState.highlightedSquares.contains((2, 5)),
      isTrue,
      reason: 'F6 should be highlighted',
    );

    // Tap F6
    await tapSquare('F6');

    // Assert White Pawn is on F6, and Black Pawn on F5 (row 3, col 5) is removed
    expect(getSquare('F6').piece?.pieceType, PieceType.pawn);
    expect(getSquare('F6').piece?.pieceColor, PieceColor.white);
    expect(
      getSquare('F5').piece,
      isNull,
      reason: 'Captured black pawn on F5 should be removed',
    );
    expect(getSquare('E5').piece, isNull);
  });

  testWidgets(
    'BlindChess - pawn promotion displays dialog and promotes to chosen piece',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      final finder = find.byType(GameScreen);
      final state = tester.state(finder);
      final dynamic dynamicState = state;

      // Load promotion-ready FEN: White pawn on E7, ready to advance to E8
      dynamicState.chessEngineService.load('k7/4P3/8/8/8/8/8/4K3 w - - 0 1');
      tester.binding.scheduleFrame();
      dynamicState.setState(() {});
      await tester.pumpAndSettle();

      Future<void> tapSquare(String label) async {
        final f = find.byWidgetPredicate(
          (w) => w is ChessSquare && w.label == label,
        );
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      ChessSquare getSquare(String label) {
        return tester.widget<ChessSquare>(
          find.byWidgetPredicate((w) => w is ChessSquare && w.label == label),
        );
      }

      // Tap E7 (White Pawn)
      await tapSquare('E7');

      // Tap E8 (Promotion rank)
      await tapSquare('E8');

      // Assert the promotion dialog is displayed
      expect(find.text('Promote Pawn to:'), findsOneWidget);

      // Tap "Knight" symbol option (White Knight symbol is ♘)
      final knightOptionFinder = find.widgetWithText(ElevatedButton, '♘');
      expect(knightOptionFinder, findsOneWidget);
      await tester.tap(knightOptionFinder);
      await tester.pumpAndSettle();

      // Assert the dialog is dismissed and piece on E8 is a Knight
      expect(find.text('Promote Pawn to:'), findsNothing);
      expect(getSquare('E8').piece?.pieceType, PieceType.knight);
      expect(getSquare('E8').piece?.pieceColor, PieceColor.white);
      expect(getSquare('E7').piece, isNull);
    },
  );

  testWidgets('BlindChess - mid-game undo reverts board state and active turn', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    Future<void> tapSquare(String label) async {
      final f = find.byWidgetPredicate(
        (w) => w is ChessSquare && w.label == label,
      );
      await tester.ensureVisible(f);
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    ChessSquare getSquare(String label) {
      return tester.widget<ChessSquare>(
        find.byWidgetPredicate((w) => w is ChessSquare && w.label == label),
      );
    }

    // Play 1. e4 e5 2. Nf3
    await tapSquare('E2');
    await tapSquare('E4');
    await tapSquare('E7');
    await tapSquare('E5');
    await tapSquare('G1');
    await tapSquare('F3');

    // Assert Knight is at F3, E5 has Black pawn
    expect(getSquare('F3').piece?.pieceType, PieceType.knight);
    expect(getSquare('E5').piece?.pieceType, PieceType.pawn);

    // Tap Undo
    final undoFinder = find.widgetWithText(ElevatedButton, 'Undo');
    await tester.ensureVisible(undoFinder);
    await tester.tap(undoFinder);
    await tester.pumpAndSettle();

    // Knight should be back on G1, F3 should be empty
    expect(getSquare('G1').piece?.pieceType, PieceType.knight);
    expect(getSquare('F3').piece, isNull);

    // Turn should be reverted to White: Select G1 (White Knight) should be legal
    await tapSquare('G1');
    expect(getSquare('G1').isSelected, isTrue);
  });

  testWidgets('BlindChess - undo button is disabled at start and is a no-op', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    final undoButtonFinder = find.widgetWithText(ElevatedButton, 'Undo');
    expect(undoButtonFinder, findsOneWidget);

    final undoButtonWidget = tester.widget<ElevatedButton>(undoButtonFinder);
    expect(undoButtonWidget.onPressed, isNull);
  });

  testWidgets(
    'BlindChess - move history shows correct SAN strings in paired chips',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      Future<void> tapSquare(String label) async {
        final f = find.byWidgetPredicate(
          (w) => w is ChessSquare && w.label == label,
        );
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      // Play 1. e4 e5 2. Nf3 Nc6
      await tapSquare('E2');
      await tapSquare('E4');
      await tapSquare('E7');
      await tapSquare('E5');
      await tapSquare('G1');
      await tapSquare('F3');
      await tapSquare('B8');
      await tapSquare('C6');

      // Assert move history list displays chips with paired notation
      expect(find.text('1. e4 e5'), findsOneWidget);
      expect(find.text('2. Nf3 Nc6'), findsOneWidget);
    },
  );

  testWidgets(
    'BlindChess - undo after checkmate dismisses game over state and unfreezes board',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      Future<void> tapSquare(String label) async {
        final f = find.byWidgetPredicate(
          (w) => w is ChessSquare && w.label == label,
        );
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      ChessSquare getSquare(String label) {
        return tester.widget<ChessSquare>(
          find.byWidgetPredicate((w) => w is ChessSquare && w.label == label),
        );
      }

      // Fool's Mate
      await tapSquare('F2');
      await tapSquare('F3');
      await tapSquare('E7');
      await tapSquare('E5');
      await tapSquare('G2');
      await tapSquare('G4');
      await tapSquare('D8');
      await tapSquare('H4');

      // Checkmate dialog appears
      expect(find.text('Checkmate'), findsOneWidget);

      // Tap OK to dismiss dialog
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Board should be frozen: tapping E2 should not select it
      await tapSquare('E2');
      expect(getSquare('E2').isSelected, isFalse);

      // Tap Undo
      final undoFinder = find.widgetWithText(ElevatedButton, 'Undo');
      await tester.ensureVisible(undoFinder);
      await tester.tap(undoFinder);
      await tester.pumpAndSettle();

      // Board should be unfrozen: Black Queen back on D8, can select White E2 pawn
      expect(getSquare('H4').piece, isNull);
      expect(getSquare('D8').piece?.pieceType, PieceType.queen);

      await tapSquare('D8');
      expect(getSquare('D8').isSelected, isTrue);
    },
  );

  testWidgets(
    'BlindChess - New Game resets engine, clears history, and disables Undo',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      Future<void> tapSquare(String label) async {
        final f = find.byWidgetPredicate(
          (w) => w is ChessSquare && w.label == label,
        );
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      // Play some moves
      await tapSquare('E2');
      await tapSquare('E4');
      await tapSquare('E7');
      await tapSquare('E5');

      expect(find.text('1. e4 e5'), findsOneWidget);

      // Tap New Game
      final newGameFinder = find.widgetWithText(ElevatedButton, 'New Game');
      await tester.ensureVisible(newGameFinder);
      await tester.tap(newGameFinder);
      await tester.pumpAndSettle();

      // Verify history is cleared and Undo button is disabled
      expect(find.text('1. e4 e5'), findsNothing);

      final undoButtonFinder = find.widgetWithText(ElevatedButton, 'Undo');
      final undoButtonWidget = tester.widget<ElevatedButton>(undoButtonFinder);
      expect(undoButtonWidget.onPressed, isNull);
    },
  );

  testWidgets(
    'BlindChess - piece symbols hide after threshold move when Blindfold is ON',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      Future<void> tapSquare(String label) async {
        final f = find.byWidgetPredicate(
          (w) => w is ChessSquare && w.label == label,
        );
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      ChessSquare getSquare(String label) {
        return tester.widget<ChessSquare>(
          find.byWidgetPredicate((w) => w is ChessSquare && w.label == label),
        );
      }

      // Toggle Blindfold Mode ON
      final switchFinder = find.byType(Switch).first;
      expect(switchFinder, findsOneWidget);
      await tester.ensureVisible(switchFinder);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Verify isPieceHidden is false initially
      expect(getSquare('E2').isPieceHidden, isFalse);

      // Play 5 moves (threshold is 5)
      await tapSquare('E2');
      await tapSquare('E4');
      await tapSquare('E7');
      await tapSquare('E5');
      await tapSquare('G1');
      await tapSquare('F3');
      await tapSquare('B8');
      await tapSquare('C6');
      await tapSquare('F1');
      await tapSquare('B5');

      // Assert that isPieceHidden is now true
      expect(getSquare('E4').isPieceHidden, isTrue);
      expect(getSquare('E5').isPieceHidden, isTrue);
    },
  );

  testWidgets('BlindChess - piece symbols remain visible if Blindfold is OFF', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    Future<void> tapSquare(String label) async {
      final f = find.byWidgetPredicate(
        (w) => w is ChessSquare && w.label == label,
      );
      await tester.ensureVisible(f);
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    ChessSquare getSquare(String label) {
      return tester.widget<ChessSquare>(
        find.byWidgetPredicate((w) => w is ChessSquare && w.label == label),
      );
    }

    // Play 5 moves
    await tapSquare('E2');
    await tapSquare('E4');
    await tapSquare('E7');
    await tapSquare('E5');
    await tapSquare('G1');
    await tapSquare('F3');
    await tapSquare('B8');
    await tapSquare('C6');
    await tapSquare('F1');
    await tapSquare('B5');

    // Assert that isPieceHidden is false
    expect(getSquare('E4').isPieceHidden, isFalse);
  });

  testWidgets('BlindChess - piece taps and highlights still work when hidden', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    final finder = find.byType(GameScreen);
    final state = tester.state(finder);
    final dynamic dynamicState = state;

    Future<void> tapSquare(String label) async {
      final f = find.byWidgetPredicate(
        (w) => w is ChessSquare && w.label == label,
      );
      await tester.ensureVisible(f);
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    // Toggle Blindfold ON
    final switchFinder = find.byType(Switch).first;
    await tester.ensureVisible(switchFinder);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    // Play 5 moves to hide pieces
    await tapSquare('E2');
    await tapSquare('E4');
    await tapSquare('E7');
    await tapSquare('E5');
    await tapSquare('G1');
    await tapSquare('F3');
    await tapSquare('B8');
    await tapSquare('C6');
    await tapSquare('F1');
    await tapSquare('B5');

    // Tap Black Knight on C6 (now hidden)
    await tapSquare('C6');

    // Assert highlights are calculated for C6 knight destinations
    expect(dynamicState.highlightedSquares, isNotEmpty);
  });

  testWidgets(
    'BlindChess - toggling Blindfold OFF immediately restores piece visibility',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      Future<void> tapSquare(String label) async {
        final f = find.byWidgetPredicate(
          (w) => w is ChessSquare && w.label == label,
        );
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      ChessSquare getSquare(String label) {
        return tester.widget<ChessSquare>(
          find.byWidgetPredicate((w) => w is ChessSquare && w.label == label),
        );
      }

      // Toggle Blindfold ON
      final switchFinder = find.byType(Switch).first;
      await tester.ensureVisible(switchFinder);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Play 5 moves to hide pieces
      await tapSquare('E2');
      await tapSquare('E4');
      await tapSquare('E7');
      await tapSquare('E5');
      await tapSquare('G1');
      await tapSquare('F3');
      await tapSquare('B8');
      await tapSquare('C6');
      await tapSquare('F1');
      await tapSquare('B5');

      expect(getSquare('E4').isPieceHidden, isTrue);

      // Toggle Blindfold OFF
      await tester.ensureVisible(switchFinder);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Assert isPieceHidden is immediately false
      expect(getSquare('E4').isPieceHidden, isFalse);
    },
  );

  testWidgets(
    'BlindChess - correct guess triggers green checkmark and increments Memory Score',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      Future<void> tapSquare(String label) async {
        final f = find.byWidgetPredicate(
          (w) => w is ChessSquare && w.label == label,
        );
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      // Toggle Blindfold Mode ON
      final switchFinder = find.byType(Switch).first;
      await tester.ensureVisible(switchFinder);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Play 5 moves (threshold is 5) to hide pieces. After 5. Bb5, active turn is Black.
      await tapSquare('E2');
      await tapSquare('E4');
      await tapSquare('E7');
      await tapSquare('E5');
      await tapSquare('G1');
      await tapSquare('F3');
      await tapSquare('B8');
      await tapSquare('C6');
      await tapSquare('F1');
      await tapSquare('B5');

      // Tap E5 (Black Pawn - correct guess) manually to avoid pumpAndSettle clearing the flash timer
      final e5Finder = find.byWidgetPredicate(
        (w) => w is ChessSquare && w.label == 'E5',
      );
      await tester.ensureVisible(e5Finder);
      await tester.tap(e5Finder);
      await tester.pump(); // Pump single frame to show the flash overlay

      // Assert green overlay checkmark appears
      expect(find.text('✓'), findsOneWidget);

      // Pump to settle the flash timer
      await tester.pumpAndSettle();

      // Assert Memory Score shows 1 / 1 (100%)
      expect(find.text('Memory Score: 1 / 1 (100%)'), findsOneWidget);
    },
  );

  testWidgets(
    'BlindChess - incorrect guess triggers red cross and only increments attempts',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      Future<void> tapSquare(String label) async {
        final f = find.byWidgetPredicate(
          (w) => w is ChessSquare && w.label == label,
        );
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      // Toggle Blindfold Mode ON
      final switchFinder = find.byType(Switch).first;
      await tester.ensureVisible(switchFinder);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Play 5 moves. Active turn is Black.
      await tapSquare('E2');
      await tapSquare('E4');
      await tapSquare('E7');
      await tapSquare('E5');
      await tapSquare('G1');
      await tapSquare('F3');
      await tapSquare('B8');
      await tapSquare('C6');
      await tapSquare('F1');
      await tapSquare('B5');

      // Tap E4 (White Pawn - incorrect guess) manually to avoid pumpAndSettle clearing the flash timer
      final e4Finder = find.byWidgetPredicate(
        (w) => w is ChessSquare && w.label == 'E4',
      );
      await tester.ensureVisible(e4Finder);
      await tester.tap(e4Finder);
      await tester.pump(); // Pump single frame to show the flash overlay

      // Assert red overlay cross appears
      expect(find.text('✗'), findsOneWidget);

      // Pump to settle the flash timer
      await tester.pumpAndSettle();

      // Assert Memory Score shows 0 / 1 (0%)
      expect(find.text('Memory Score: 0 / 1 (0%)'), findsOneWidget);
    },
  );

  testWidgets(
    'BlindChess - Memory Score is not shown/tracked before pieces hide',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      Future<void> tapSquare(String label) async {
        final f = find.byWidgetPredicate(
          (w) => w is ChessSquare && w.label == label,
        );
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      // Toggle Blindfold Mode ON
      final switchFinder = find.byType(Switch).first;
      await tester.ensureVisible(switchFinder);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Play only 4 moves (pieces still visible)
      await tapSquare('E2');
      await tapSquare('E4');
      await tapSquare('E7');
      await tapSquare('E5');
      await tapSquare('G1');
      await tapSquare('F3');
      await tapSquare('B8');
      await tapSquare('C6');

      // Verify Memory Score is not rendered
      expect(find.textContaining('Memory Score:'), findsNothing);
    },
  );

  testWidgets(
    'BlindChess - Reveal temporarily shows pieces and then hides them after 3 seconds',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      Future<void> tapSquare(String label) async {
        final f = find.byWidgetPredicate(
          (w) => w is ChessSquare && w.label == label,
        );
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      ChessSquare getSquare(String label) {
        return tester.widget<ChessSquare>(
          find.byWidgetPredicate((w) => w is ChessSquare && w.label == label),
        );
      }

      // Toggle Blindfold ON
      final switchFinder = find.byType(Switch).first;
      await tester.ensureVisible(switchFinder);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Play 5 moves
      await tapSquare('E2');
      await tapSquare('E4');
      await tapSquare('E7');
      await tapSquare('E5');
      await tapSquare('G1');
      await tapSquare('F3');
      await tapSquare('B8');
      await tapSquare('C6');
      await tapSquare('F1');
      await tapSquare('B5');

      expect(getSquare('E4').isPieceHidden, isTrue);

      // Tap Reveal Pieces
      final revealFinder = find.widgetWithText(ElevatedButton, 'Reveal Pieces');
      expect(revealFinder, findsOneWidget);
      await tester.ensureVisible(revealFinder);
      await tester.tap(revealFinder);
      await tester.pump(); // Start reveal

      // Verify pieces are now visible
      expect(getSquare('E4').isPieceHidden, isFalse);

      // Pump fake 3 seconds timer
      await tester.pump(const Duration(seconds: 3));

      // Verify pieces are hidden again
      expect(getSquare('E4').isPieceHidden, isTrue);
    },
  );

  testWidgets('BlindChess - Reveal button enters a 10-move cooldown', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    Future<void> tapSquare(String label) async {
      final f = find.byWidgetPredicate(
        (w) => w is ChessSquare && w.label == label,
      );
      await tester.ensureVisible(f);
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    // Toggle Blindfold ON
    final switchFinder = find.byType(Switch).first;
    await tester.ensureVisible(switchFinder);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    // Play 5 moves
    await tapSquare('E2');
    await tapSquare('E4');
    await tapSquare('E7');
    await tapSquare('E5');
    await tapSquare('G1');
    await tapSquare('F3');
    await tapSquare('B8');
    await tapSquare('C6');
    await tapSquare('F1');
    await tapSquare('B5');

    // Tap Reveal Pieces
    final revealFinder = find.widgetWithText(ElevatedButton, 'Reveal Pieces');
    await tester.ensureVisible(revealFinder);
    await tester.tap(revealFinder);
    await tester.pumpAndSettle();

    // Verify button is now disabled and shows 10 moves left cooldown
    final cooldownFinder = find.widgetWithText(
      ElevatedButton,
      'Reveal (10 moves left)',
    );
    expect(cooldownFinder, findsOneWidget);
    expect(tester.widget<ElevatedButton>(cooldownFinder).onPressed, isNull);

    // Play 1 move (Black knight C6 to A5)
    await tapSquare('C6');
    await tapSquare('A5');

    // Verify cooldown goes down to 9 moves left
    expect(
      find.widgetWithText(ElevatedButton, 'Reveal (9 moves left)'),
      findsOneWidget,
    );

    // Play 9 more moves to clear the 10-move cooldown
    // Move 2: White Pawn D2 to D3
    await tapSquare('D2');
    await tapSquare('D3');
    // Move 3: Black Knight A5 to C6
    await tapSquare('A5');
    await tapSquare('C6');
    // Move 4: White Pawn D3 to D4
    await tapSquare('D3');
    await tapSquare('D4');
    // Move 5: Black Knight C6 to A5
    await tapSquare('C6');
    await tapSquare('A5');
    // Move 6: White Pawn D4 to D5
    await tapSquare('D4');
    await tapSquare('D5');
    // Move 7: Black Knight A5 to C6
    await tapSquare('A5');
    await tapSquare('C6');
    // Move 8: White Pawn C2 to C3
    await tapSquare('C2');
    await tapSquare('C3');
    // Move 9: Black Knight C6 to A5
    await tapSquare('C6');
    await tapSquare('A5');
    // Move 10: White Pawn C3 to C4
    await tapSquare('C3');
    await tapSquare('C4');

    // Assert Reveal Pieces is enabled again
    expect(
      find.widgetWithText(ElevatedButton, 'Reveal Pieces'),
      findsOneWidget,
    );
  });

  testWidgets(
    'BlindChess - Reveal button cooldown handles undo without overflow',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      Future<void> tapSquare(String label) async {
        final f = find.byWidgetPredicate(
          (w) => w is ChessSquare && w.label == label,
        );
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      // Toggle Blindfold ON
      final switchFinder = find.byType(Switch).first;
      await tester.ensureVisible(switchFinder);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Play 5 moves to trigger hidden state
      await tapSquare('E2');
      await tapSquare('E4');
      await tapSquare('E7');
      await tapSquare('E5');
      await tapSquare('G1');
      await tapSquare('F3');
      await tapSquare('B8');
      await tapSquare('C6');
      await tapSquare('F1');
      await tapSquare('B5');

      // Tap Reveal Pieces
      final revealFinder = find.widgetWithText(ElevatedButton, 'Reveal Pieces');
      await tester.ensureVisible(revealFinder);
      await tester.tap(revealFinder);
      await tester.pumpAndSettle();

      // Verify button is disabled and shows 10 moves left
      expect(
        find.widgetWithText(ElevatedButton, 'Reveal (10 moves left)'),
        findsOneWidget,
      );

      // Press Undo button
      final undoFinder = find.widgetWithText(ElevatedButton, 'Undo');
      await tester.ensureVisible(undoFinder);
      await tester.tap(undoFinder);
      await tester.pumpAndSettle();

      // Cooldown is reset, and button doesn't show moves left
      expect(find.textContaining('moves left'), findsNothing);
    },
  );

  testWidgets('BlindChess - Easy difficulty hides pieces after 10 moves', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    Future<void> tapSquare(String label) async {
      final f = find.byWidgetPredicate(
        (w) => w is ChessSquare && w.label == label,
      );
      await tester.ensureVisible(f);
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    ChessSquare getSquare(String label) {
      return tester.widget<ChessSquare>(
        find.byWidgetPredicate((w) => w is ChessSquare && w.label == label),
      );
    }

    // Toggle Blindfold ON
    final switchFinder = find.byType(Switch).first;
    await tester.ensureVisible(switchFinder);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    // Select Easy difficulty (index 0)
    final easyFinder = find.text('Easy');
    expect(easyFinder, findsOneWidget);
    await tester.ensureVisible(easyFinder);
    await tester.tap(easyFinder);
    await tester.pumpAndSettle();

    // Play 9 moves
    await tapSquare('E2');
    await tapSquare('E4'); // 1
    await tapSquare('E7');
    await tapSquare('E5'); // 2
    await tapSquare('G1');
    await tapSquare('F3'); // 3
    await tapSquare('B8');
    await tapSquare('C6'); // 4
    await tapSquare('F1');
    await tapSquare('B5'); // 5
    await tapSquare('C6');
    await tapSquare('A5'); // 6
    await tapSquare('D2');
    await tapSquare('D3'); // 7
    await tapSquare('A5');
    await tapSquare('C6'); // 8
    await tapSquare('D3');
    await tapSquare('D4'); // 9

    // Assert pieces are still visible after 9 moves
    expect(getSquare('E4').isPieceHidden, isFalse);

    // Play 10th move (Black Knight C6 to A5)
    await tapSquare('C6');
    await tapSquare('A5'); // 10

    // Assert pieces are hidden after 10 moves
    expect(getSquare('E4').isPieceHidden, isTrue);
  });

  testWidgets('BlindChess - Medium difficulty hides pieces after 5 moves', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    Future<void> tapSquare(String label) async {
      final f = find.byWidgetPredicate(
        (w) => w is ChessSquare && w.label == label,
      );
      await tester.ensureVisible(f);
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    ChessSquare getSquare(String label) {
      return tester.widget<ChessSquare>(
        find.byWidgetPredicate((w) => w is ChessSquare && w.label == label),
      );
    }

    // Toggle Blindfold ON
    final switchFinder = find.byType(Switch).first;
    await tester.ensureVisible(switchFinder);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    // Plays 5 moves
    await tapSquare('E2');
    await tapSquare('E4');
    await tapSquare('E7');
    await tapSquare('E5');
    await tapSquare('G1');
    await tapSquare('F3');
    await tapSquare('B8');
    await tapSquare('C6');
    await tapSquare('F1');
    await tapSquare('B5');

    expect(getSquare('E4').isPieceHidden, isTrue);
  });

  testWidgets(
    'BlindChess - Hard difficulty hides pieces immediately at move 0 and first move works',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      Future<void> tapSquare(String label) async {
        final f = find.byWidgetPredicate(
          (w) => w is ChessSquare && w.label == label,
        );
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      ChessSquare getSquare(String label) {
        return tester.widget<ChessSquare>(
          find.byWidgetPredicate((w) => w is ChessSquare && w.label == label),
        );
      }

      // Toggle Blindfold ON
      final switchFinder = find.byType(Switch).first;
      await tester.ensureVisible(switchFinder);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Select Hard difficulty (index 2)
      final hardFinder = find.text('Hard');
      await tester.ensureVisible(hardFinder);
      await tester.tap(hardFinder);
      await tester.pumpAndSettle();

      // Tap New Game
      final newGameFinder = find.widgetWithText(ElevatedButton, 'New Game');
      await tester.ensureVisible(newGameFinder);
      await tester.tap(newGameFinder);
      await tester.pumpAndSettle();

      // Assert pieces are hidden immediately at move 0
      expect(getSquare('E2').isPieceHidden, isTrue);

      // Make the first move E2 to E4 (hidden pawn)
      await tapSquare('E2');
      await tapSquare('E4');

      // Assert move is executed correctly (pawn now at E4, E2 is empty)
      expect(getSquare('E4').piece?.pieceType, PieceType.pawn);
      expect(getSquare('E2').piece, isNull);
    },
  );

  testWidgets(
    'BlindChess - switching difficulty mid-game updates piece visibility instantly',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      Future<void> tapSquare(String label) async {
        final f = find.byWidgetPredicate(
          (w) => w is ChessSquare && w.label == label,
        );
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      ChessSquare getSquare(String label) {
        return tester.widget<ChessSquare>(
          find.byWidgetPredicate((w) => w is ChessSquare && w.label == label),
        );
      }

      // Toggle Blindfold ON
      final switchFinder = find.byType(Switch).first;
      await tester.ensureVisible(switchFinder);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Select Easy
      final easyFinder = find.text('Easy');
      await tester.ensureVisible(easyFinder);
      await tester.tap(easyFinder);
      await tester.pumpAndSettle();

      // Play 3 moves
      await tapSquare('E2');
      await tapSquare('E4');
      await tapSquare('E7');
      await tapSquare('E5');
      await tapSquare('G1');
      await tapSquare('F3');

      // Pieces still visible on Easy
      expect(getSquare('E4').isPieceHidden, isFalse);

      // Switch to Hard difficulty mid-game
      final hardFinder = find.text('Hard');
      await tester.ensureVisible(hardFinder);
      await tester.tap(hardFinder);
      await tester.pumpAndSettle();

      // Pieces should hide immediately because Hard threshold (0) is met
      expect(getSquare('E4').isPieceHidden, isTrue);

      // Switch back to Easy difficulty
      await tester.ensureVisible(easyFinder);
      await tester.tap(easyFinder);
      await tester.pumpAndSettle();

      // Pieces should reappear immediately because current moves (3) < Easy threshold (10)
      expect(getSquare('E4').isPieceHidden, isFalse);
    },
  );

  testWidgets(
    'BlindChess - New Game preserves the previously selected difficulty',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      final finder = find.byType(GameScreen);
      final state = tester.state(finder);
      final dynamic dynamicState = state;

      // Toggle Blindfold ON
      final switchFinder = find.byType(Switch).first;
      await tester.ensureVisible(switchFinder);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Select Hard
      final hardFinder = find.text('Hard');
      await tester.ensureVisible(hardFinder);
      await tester.tap(hardFinder);
      await tester.pumpAndSettle();

      expect(dynamicState.selectedDifficulty, BlindfoldDifficulty.hard);

      // Tap New Game
      final newGameFinder = find.widgetWithText(ElevatedButton, 'New Game');
      await tester.ensureVisible(newGameFinder);
      await tester.tap(newGameFinder);
      await tester.pumpAndSettle();

      // Verify difficulty is still Hard
      expect(dynamicState.selectedDifficulty, BlindfoldDifficulty.hard);
    },
  );

  testWidgets(
    'BlindChess - checkmate increments total games and correct color wins stats',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await StatisticsService.instance.clearStats();

      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      Future<void> tapSquare(String label) async {
        final f = find.byWidgetPredicate(
          (w) => w is ChessSquare && w.label == label,
        );
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      // Play Fool\'s Mate checkmate. White is checkmated, so Black wins.
      await tapSquare('F2');
      await tapSquare('F3');
      await tapSquare('E7');
      await tapSquare('E5');
      await tapSquare('G2');
      await tapSquare('G4');
      await tapSquare('D8');
      await tapSquare('H4');

      // Dismiss checkmate dialog
      expect(find.text('Checkmate — Black wins.'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(StatisticsService.instance.totalGamesPlayed, 1);
      expect(StatisticsService.instance.blackWins, 1);
      expect(StatisticsService.instance.whiteWins, 0);

      // Open Stats Screen
      final statsFinder = find.byIcon(Icons.bar_chart);
      await tester.ensureVisible(statsFinder);
      await tester.tap(statsFinder);
      await tester.pumpAndSettle();

      // Verify stats displayed on screen
      expect(
        find.text('1'),
        findsNWidgets(2),
      ); // Games played summary (48px text) and Black Wins tile both show "1"
    },
  );

  testWidgets('BlindChess - stalemate increments Draws and not wins', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await StatisticsService.instance.clearStats();

    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Start Game'));
    await tester.pumpAndSettle();

    final finder = find.byType(GameScreen);
    final state = tester.state(finder);
    final dynamic dynamicState = state;

    // Load stalemate FEN: k7/8/1Q6/8/8/8/8/4K3 b - - 0 1
    dynamicState.chessEngineService.load('k7/8/1Q6/8/8/8/8/4K3 b - - 0 1');

    // Trigger state rebuild and check status
    tester.binding.scheduleFrame();
    dynamicState.setState(() {
      dynamicState.checkGameStatus();
    });
    await tester.pumpAndSettle();

    // Dismiss Stalemate dialog
    expect(find.text('Stalemate — Draw.'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(StatisticsService.instance.totalGamesPlayed, 1);
    expect(StatisticsService.instance.draws, 1);
    expect(StatisticsService.instance.whiteWins, 0);
    expect(StatisticsService.instance.blackWins, 0);

    // Navigate to stats screen
    final statsFinder = find.byIcon(Icons.bar_chart);
    await tester.ensureVisible(statsFinder);
    await tester.tap(statsFinder);
    await tester.pumpAndSettle();

    // Verify stats displays 1 draw
    expect(
      find.text('1'),
      findsNWidgets(2),
    ); // Games played summary (48px text) and Draws tile both show "1"
  });

  testWidgets(
    'BlindChess - Blindfold game increments total blindfold games and updates accuracy',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await StatisticsService.instance.clearStats();

      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      Future<void> tapSquare(String label) async {
        final f = find.byWidgetPredicate(
          (w) => w is ChessSquare && w.label == label,
        );
        await tester.ensureVisible(f);
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      // Toggle Blindfold ON
      final switchFinder = find.byType(Switch).first;
      await tester.ensureVisible(switchFinder);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Select Hard Mode (hides immediately)
      final hardFinder = find.text('Hard');
      await tester.ensureVisible(hardFinder);
      await tester.tap(hardFinder);
      await tester.pumpAndSettle();

      // Play Fool\'s mate with perfect selection guesses
      // Taps F2 (correct guess), then F3 (move)
      await tapSquare('F2');
      await tapSquare('F3');
      // Taps E7 (correct guess), then E5 (move)
      await tapSquare('E7');
      await tapSquare('E5');
      // Taps G2 (correct guess), then G4 (move)
      await tapSquare('G2');
      await tapSquare('G4');
      // Taps D8 (correct guess), then H4 (move)
      await tapSquare('D8');
      await tapSquare('H4');

      // Dismiss checkmate dialog
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(StatisticsService.instance.totalBlindfoldGamesPlayed, 1);
      expect(StatisticsService.instance.averageMemoryAccuracy, 100.0);

      // Open Stats Screen
      final statsFinder = find.byIcon(Icons.bar_chart);
      await tester.ensureVisible(statsFinder);
      await tester.tap(statsFinder);
      await tester.pumpAndSettle();

      // Verify stats display accuracy
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('100.0%'), findsOneWidget);
    },
  );

  testWidgets(
    'BlindChess - Highest Memory Score reflects maximum accuracy across games',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await StatisticsService.instance.clearStats();

      // Game 1: 100% accuracy recorded
      await StatisticsService.instance.recordGame(
        isDraw: false,
        winningColor: 'white',
        isCheckmate: true,
        halfMoves: 12,
        isBlindfoldModeActive: true,
        memoryScorePercentage: 100,
      );

      // Game 2: 50% accuracy recorded
      await StatisticsService.instance.recordGame(
        isDraw: false,
        winningColor: 'black',
        isCheckmate: true,
        halfMoves: 16,
        isBlindfoldModeActive: true,
        memoryScorePercentage: 50,
      );

      expect(StatisticsService.instance.highestMemoryScore, 100);
      expect(StatisticsService.instance.averageMemoryAccuracy, 75.0);

      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      // Open Stats Screen
      final statsFinder = find.byIcon(Icons.bar_chart);
      await tester.ensureVisible(statsFinder);
      await tester.tap(statsFinder);
      await tester.pumpAndSettle();

      expect(find.text('100%'), findsOneWidget);
      expect(find.text('75.0%'), findsOneWidget);
    },
  );

  testWidgets(
    'BlindChess - checkmate move count registers fastest win record',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await StatisticsService.instance.clearStats();

      // Game 1: Checkmate in 12 moves
      await StatisticsService.instance.recordGame(
        isDraw: false,
        winningColor: 'white',
        isCheckmate: true,
        halfMoves: 12,
      );

      // Game 2: Checkmate in 4 moves (faster!)
      await StatisticsService.instance.recordGame(
        isDraw: false,
        winningColor: 'black',
        isCheckmate: true,
        halfMoves: 4,
      );

      expect(StatisticsService.instance.fastestWinHalfMoves, 4);

      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      // Open Stats Screen
      final statsFinder = find.byIcon(Icons.bar_chart);
      await tester.ensureVisible(statsFinder);
      await tester.tap(statsFinder);
      await tester.pumpAndSettle();

      expect(find.text('Fastest Win: 4 half-moves'), findsOneWidget);
    },
  );

  testWidgets(
    'BlindChess - stats load correctly from mock SharedPreferences restart simulation',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'stats_total_games': 25,
        'stats_white_wins': 10,
        'stats_black_wins': 10,
        'stats_draws': 5,
        'stats_highest_memory_score': 90,
        'stats_total_blindfold_games': 4,
        'stats_sum_memory_accuracies': 320.0, // 320 / 4 = 80.0%
        'stats_fastest_win_half_moves': 8,
      });

      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      // Open Stats Screen
      final statsFinder = find.byIcon(Icons.bar_chart);
      await tester.ensureVisible(statsFinder);
      await tester.tap(statsFinder);
      await tester.pumpAndSettle();

      expect(find.text('25'), findsOneWidget);
      expect(find.text('10'), findsNWidgets(2));
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Fastest Win: 8 half-moves'), findsOneWidget);
      expect(find.text('90%'), findsOneWidget);
      expect(find.text('80.0%'), findsOneWidget);
    },
  );

  testWidgets(
    'BlindChess - zero-data launches render gracefully with N/A values',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await StatisticsService.instance.clearStats();

      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      // Open Stats Screen
      final statsFinder = find.byIcon(Icons.bar_chart);
      await tester.ensureVisible(statsFinder);
      await tester.tap(statsFinder);
      await tester.pumpAndSettle();

      // Verify 0 games and N/A values
      expect(
        find.text('0'),
        findsNWidgets(7),
      ); // Games played (48px text), White wins, Black wins, Draws, Blindfold Games, Online Games, Online Blindfold Games
      expect(find.text('Fastest Win: N/A'), findsOneWidget);
      expect(
        find.text('N/A'),
        findsNWidgets(2),
      ); // Highest score, average accuracy
    },
  );

  testWidgets(
    'BlindChess - toggling board theme and dark mode updates state and saves to preferences',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await SettingsService.instance.loadSettings();

      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      // Verify initial theme values
      expect(SettingsService.instance.boardTheme, 'classic_wood');
      expect(SettingsService.instance.isDarkMode, isFalse);

      // Tap 'Ocean' theme button
      final oceanFinder = find.text('Ocean');
      await tester.ensureVisible(oceanFinder);
      await tester.tap(oceanFinder);
      await tester.pumpAndSettle();

      expect(SettingsService.instance.boardTheme, 'ocean_blue');

      // Toggle Dark Mode (Switch index 1 in the settings section)
      final switchFinders = find.byType(Switch);
      expect(switchFinders, findsNWidgets(4));
      await tester.ensureVisible(switchFinders.at(1));
      await tester.tap(switchFinders.at(1));
      await tester.pumpAndSettle();

      expect(SettingsService.instance.isDarkMode, isTrue);

      // Check SharedPreferences commits
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('settings_board_theme'), 'ocean_blue');
      expect(prefs.getBool('settings_is_dark_mode'), isTrue);
    },
  );

  testWidgets(
    'BlindChess - toggling mute updates state and saves to preferences',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await SettingsService.instance.loadSettings();

      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      expect(SettingsService.instance.isMuted, isFalse);

      // Tap Muted switch (second switch in settings section, index 2)
      final switchFinders = find.byType(Switch);
      expect(switchFinders, findsNWidgets(4));
      await tester.ensureVisible(switchFinders.at(2));
      await tester.tap(switchFinders.at(2));
      await tester.pumpAndSettle();

      expect(SettingsService.instance.isMuted, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('settings_is_muted'), isTrue);
    },
  );

  test('ChessEngineService matches Board.initial() on all 64 squares', () {
    final board = Board.initial();
    final service = ChessEngineService();

    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final boardPiece = board.pieceAt(row, col);
        final servicePiece = service.pieceAt(row, col);

        if (boardPiece == null) {
          expect(
            servicePiece,
            isNull,
            reason: 'Expected null piece at Row $row, Col $col',
          );
        } else {
          expect(
            servicePiece,
            isNotNull,
            reason: 'Expected a piece at Row $row, Col $col',
          );
          expect(
            servicePiece!.pieceType,
            boardPiece.pieceType,
            reason: 'PieceType mismatch at Row $row, Col $col',
          );
          expect(
            servicePiece.pieceColor,
            boardPiece.pieceColor,
            reason: 'PieceColor mismatch at Row $row, Col $col',
          );
        }
      }
    }
  });

  testWidgets('BlindChess - Daily Streak calendar progression', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final service = StatisticsService.instance;
    await service.clearStats();

    final today = DateTime.now();

    // 1. First game ever -> Streak = 1
    await service.recordGame(isDraw: false, winningColor: 'white');
    expect(service.currentStreak, 1);

    // 2. Play game on simulated next day -> Streak = 2
    final yesterday = today.subtract(const Duration(days: 1));
    service.lastPlayedDate =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    service.currentStreak = 1;
    await service.recordGame(isDraw: false, winningColor: 'white');
    expect(service.currentStreak, 2);

    // 3. Play game on simulated same day -> Streak remains 2
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    service.lastPlayedDate = todayStr;
    service.currentStreak = 2;
    await service.recordGame(isDraw: false, winningColor: 'white');
    expect(service.currentStreak, 2);

    // 4. Play game after 2 days gap -> Streak resets to 1
    final twoDaysAgo = today.subtract(const Duration(days: 2));
    service.lastPlayedDate =
        '${twoDaysAgo.year}-${twoDaysAgo.month.toString().padLeft(2, '0')}-${twoDaysAgo.day.toString().padLeft(2, '0')}';
    service.currentStreak = 5;
    await service.recordGame(isDraw: false, winningColor: 'white');
    expect(service.currentStreak, 1);
  });

  testWidgets(
    'BlindChess - Achievements unlock states derived dynamically on load',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'stats_white_wins': 1,
        'stats_black_wins': 1,
        'stats_total_games': 2,
      });
      await StatisticsService.instance.loadStats();

      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      // Navigate to Stats Screen
      final statsFinder = find.byIcon(Icons.bar_chart);
      await tester.ensureVisible(statsFinder);
      await tester.tap(statsFinder);
      await tester.pumpAndSettle();

      // Verify "First Win" and "Both Sides" show Unlocked in the UI
      final firstWinContainer = find
          .ancestor(
            of: find.text('First Win'),
            matching: find.byType(Container),
          )
          .first;
      expect(
        find.descendant(of: firstWinContainer, matching: find.text('Unlocked')),
        findsOneWidget,
      );

      final bothSidesContainer = find
          .ancestor(
            of: find.text('Both Sides'),
            matching: find.byType(Container),
          )
          .first;
      expect(
        find.descendant(
          of: bothSidesContainer,
          matching: find.text('Unlocked'),
        ),
        findsOneWidget,
      );

      // Verify "Marathoner" shows Locked in the UI
      final marathonerContainer = find
          .ancestor(
            of: find.text('Marathoner'),
            matching: find.byType(Container),
          )
          .first;
      expect(
        find.descendant(of: marathonerContainer, matching: find.text('Locked')),
        findsOneWidget,
      );

      // Verify locked badges are present
      expect(find.text('Mind\'s Eye'), findsOneWidget);
      expect(find.text('Speed Demon'), findsOneWidget);
      expect(find.text('Perfectionist'), findsOneWidget);
      expect(find.text('Consistent'), findsOneWidget);
    },
  );

  test('AudioService has zero network dependencies', () {
    final file = io.File('lib/services/audio_service.dart');
    final content = file.readAsStringSync();
    expect(
      content.contains('http://'),
      isFalse,
      reason: 'Must not contain http URLs',
    );
    expect(
      content.contains('https://'),
      isFalse,
      reason: 'Must not contain https URLs',
    );
    expect(
      content.contains('UrlSource'),
      isFalse,
      reason: 'Must not use UrlSource',
    );
    expect(
      content.contains('AssetSource'),
      isTrue,
      reason: 'Must use AssetSource',
    );
  });

  testWidgets(
    'BlindChess - responsive chessboard rendering under narrow constraints without overflow',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const MaterialApp(home: GameScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Chess Match'), findsOneWidget);
      expect(find.byType(ChessSquare), findsNWidgets(64));
    },
  );
}
