import 'package:flutter/material.dart';
import 'learning_screen.dart';

/// [Why separate files are useful]
/// As projects grow, keeping all widgets in a single file like `main.dart` leads to massive,
/// unmaintainable, and hard-to-read codebases. Dividing screens into dedicated files:
/// 1. Encourages encapsulation and separation of concerns.
/// 2. Makes it easier to locate, debug, and modify specific parts of the UI.
/// 3. Facilitates collaboration, as developers can work on different screens without git merge conflicts.
/// 4. Promotes code reuse and modular testing.

/// [HomeScreen]
/// The starting page of the BlindChess application, containing the main header,
/// informational text, a visual chessboard layout icon, and a button to initiate learning mode.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('BlindChess'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Text(
                  'Welcome to BlindChess',
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
                  'Train your chess memory with Blindfold Mode',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.grid_on,
                  size: 64,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  /// [Navigator]
                  /// In Flutter, navigation is managed by the [Navigator] widget. The Navigator maintains
                  /// a history of routes (screens) using a Stack data structure (LIFO - Last In, First Out).
                  /// `Navigator.push()` is used to push a new route onto the stack, displaying the new screen.
                  ///
                  /// [MaterialPageRoute]
                  /// A modal route that replaces the entire screen with a platform-adaptive transition animation
                  /// (e.g., sliding up on iOS, fading/scaling up on Android).
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LearningScreen(),
                    ),
                  );
                },
                child: const Text('Start Learning'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
