// This is a basic Flutter widget test for the BlindChess application.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess/main.dart';

void main() {
  testWidgets('BlindChess home screen UI elements and SnackBar test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the welcome and description texts are displayed.
    expect(find.text('Welcome to BlindChess'), findsOneWidget);
    expect(find.text('Train your chess memory with Blindfold Mode'), findsOneWidget);

    // Verify that the chess grid icon is present.
    expect(find.byIcon(Icons.grid_on), findsOneWidget);

    // Verify that the button "Start Learning" is displayed.
    expect(find.text('Start Learning'), findsOneWidget);

    // Tap the 'Start Learning' button and trigger a frame.
    await tester.tap(find.text('Start Learning'));
    await tester.pump(); // Starts the SnackBar appearance animation

    // Verify that the SnackBar is displayed with the correct message.
    expect(find.text('BlindChess journey begins!'), findsOneWidget);
  });
}
