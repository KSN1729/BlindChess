import 'package:flutter/material.dart';

/// [StatelessWidget communication]
/// Widgets in Flutter communicate primarily by passing parameters through their constructors.
/// Since [StatelessWidget] objects are immutable (their properties cannot change over time),
/// they receive initial data, configuration settings, or callback functions from parent widgets
/// during creation. For navigation, passing arguments to the constructor of the next screen
/// is the standard way to share information between screens.
///
/// In this case, [LearningScreen] is constructed cleanly as const since it currently does
/// not require complex runtime data from [HomeScreen].

/// [LearningScreen]
/// A dedicated screen representing the learning environment in BlindChess.
/// It displays instructions for upcoming chess memory exercises and a button to return home.
class LearningScreen extends StatelessWidget {
  const LearningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('Learning Mode'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Text(
                  'BlindChess Learning Mode',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Text(
                  'Future memory training exercises will appear here.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  /// [Navigator.pop]
                  /// Pops the top-most route (this current [LearningScreen]) off the Navigator's stack.
                  /// This action slides the current screen away and reveals the previous screen
                  /// underneath (the [HomeScreen]), which was waiting directly below it in the stack.
                  Navigator.pop(context);
                },
                child: const Text('Back Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
