// This is a basic Flutter widget test for screen separation, navigation, state management, and custom widgets.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess/main.dart';
import 'package:chess/screens/home_screen.dart';
import 'package:chess/screens/learning_screen.dart';
import 'package:chess/widgets/chess_square.dart';

void main() {
  testWidgets('BlindChess screen transition, StatefulWidget progress counter, and 8x8 Chessboard test', (WidgetTester tester) async {
    // 1. Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // 2. Verify that we start on the HomeScreen.
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Welcome to BlindChess'), findsOneWidget);

    // Verify ProgressCard is drawn on HomeScreen.
    expect(find.text('Learning Progress'), findsOneWidget);
    expect(find.text('Completed Lessons: 0'), findsOneWidget);

    // 3. Tap 'Complete Lesson' button on HomeScreen and verify counter increments.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Complete Lesson'));
    await tester.pump(); // Rebuild state

    // Verify counter is now 1.
    expect(find.text('Completed Lessons: 1'), findsOneWidget);
    expect(find.text('Completed Lessons: 0'), findsNothing);

    // 4. Tap the 'Start Learning' button to navigate.
    await tester.tap(find.text('Start Learning'));
    await tester.pumpAndSettle();

    // 5. Verify we are now on the LearningScreen.
    expect(find.byType(LearningScreen), findsOneWidget);
    expect(find.text('BlindChess Learning Mode'), findsOneWidget);

    // Verify Chessboard header and 64 ChessSquare widgets are visible
    expect(find.text('Complete 8×8 Chessboard'), findsOneWidget);
    expect(find.byType(ChessSquare), findsNWidgets(64));

    // Verify the four corners of the board are rendered correctly
    expect(find.text('A1'), findsOneWidget);
    expect(find.text('H1'), findsOneWidget);
    expect(find.text('A8'), findsOneWidget);
    expect(find.text('H8'), findsOneWidget);

    // Test tapping a chess square triggers the callback and shows a SnackBar
    final d4Square = find.text('D4');
    await tester.ensureVisible(d4Square);
    await tester.tap(d4Square);
    await tester.pump(); // Start SnackBar animation
    expect(find.text('You tapped D4'), findsOneWidget);

    // Verify a separate ProgressCard is drawn on LearningScreen starting at 0.
    expect(find.text('Completed Lessons: 0'), findsOneWidget);

    // 6. Tap 'Complete Lesson' button on LearningScreen and verify counter increments.
    final completeButton = find.widgetWithText(ElevatedButton, 'Complete Lesson');
    await tester.ensureVisible(completeButton);
    await tester.tap(completeButton);
    await tester.pump(); // Rebuild state

    // Verify LearningScreen counter is now 1.
    expect(find.text('Completed Lessons: 1'), findsOneWidget);
    expect(find.text('Completed Lessons: 0'), findsNothing);

    // 7. Tap the 'Back Home' button to pop back.
    final backHomeButton = find.text('Back Home');
    await tester.ensureVisible(backHomeButton);
    await tester.tap(backHomeButton);
    await tester.pumpAndSettle();

    // 8. Verify we are returned to the HomeScreen and the home counter is still 1.
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Completed Lessons: 1'), findsOneWidget);
  });
}
