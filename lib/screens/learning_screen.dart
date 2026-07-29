import 'package:flutter/material.dart';
import '../widgets/section_title.dart';
import '../widgets/progress_card.dart';

/// [Why widgets are separated]
/// Keeping screens and layout components in separate files separates concerns and makes the codebase
/// highly organized, clean, and scaling-friendly.
///
/// [Widget reuse]
/// Reusable widgets let us write logic and styling rules in a single place. The [SectionTitle] widget,
/// for instance, ensures the font sizes, weights, and center alignments match perfectly on both screens
/// without needing duplicate [TextStyle] markup.
///
/// [Constructor communication]
/// We pass configurations (like the screen-specific title string) as constructor arguments to the child widget.
/// The child receives this data via constructor parameters and displays it accordingly.
///
/// [StatelessWidget]
/// A widget whose configuration values cannot change after creation. All variables declared within it
/// must be marked as `final`.
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
                // Replaced static text widget with custom SectionTitle widget.
                child: SectionTitle(
                  title: 'BlindChess Learning Mode',
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
              // We display the learning progress card here
              const ProgressCard(),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
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
