// This is a basic Flutter widget test for screen separation and navigation.

import 'package:flutter_test/flutter_test.dart';

import 'package:chess/main.dart';
import 'package:chess/screens/home_screen.dart';
import 'package:chess/screens/learning_screen.dart';

void main() {
  testWidgets('BlindChess screen navigation transition test', (WidgetTester tester) async {
    // 1. Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // 2. Verify that we start on the HomeScreen.
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Welcome to BlindChess'), findsOneWidget);
    expect(find.text('Start Learning'), findsOneWidget);

    // Verify LearningScreen is not yet in the tree.
    expect(find.byType(LearningScreen), findsNothing);

    // 3. Tap the 'Start Learning' button to navigate.
    await tester.tap(find.text('Start Learning'));
    
    // Pump and settle triggers and waits for all transitions/routing animations to complete.
    await tester.pumpAndSettle();

    // 4. Verify we are now on the LearningScreen.
    expect(find.byType(LearningScreen), findsOneWidget);
    expect(find.text('BlindChess Learning Mode'), findsOneWidget);
    expect(find.text('Future memory training exercises will appear here.'), findsOneWidget);
    expect(find.text('Back Home'), findsOneWidget);

    // Verify HomeScreen is no longer the top screen active.
    expect(find.text('Welcome to BlindChess'), findsNothing);

    // 5. Tap the 'Back Home' button to pop back.
    await tester.tap(find.text('Back Home'));
    await tester.pumpAndSettle();

    // 6. Verify we are returned to the HomeScreen.
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Welcome to BlindChess'), findsOneWidget);
    expect(find.byType(LearningScreen), findsNothing);
  });
}
