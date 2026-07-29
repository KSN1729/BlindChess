import 'package:flutter/material.dart';
import '../widgets/section_title.dart';
import 'learning_screen.dart';

/// [Why widgets are separated]
/// Separating widgets into different files decomposes large, monolith files into small, single-purpose
/// components. This makes visual layouts modular, easier to maintain, and cleaner to read.
///
/// [Widget reuse]
/// Reusable widgets are building blocks that can be declared once and referenced across different screens
/// (like using [SectionTitle] in both [HomeScreen] and [LearningScreen]). This ensures design consistency
/// and drastically reduces code duplication.
///
/// [Constructor communication]
/// Parent widgets communicate with child widgets by passing arguments (like `title`) into their
/// constructor when instantiating them.
///
/// [StatelessWidget]
/// A widget that relies only on configuration properties passed through its constructor. It has no internal,
/// mutable state that changes during its lifecycle.
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
                // Replaced the plain welcome Text widget with our custom reusable SectionTitle widget.
                child: SectionTitle(
                  title: 'Welcome to BlindChess',
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
