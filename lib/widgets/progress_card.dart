import 'package:flutter/material.dart';

/// [What StatefulWidget is]
/// A StatefulWidget is a widget that describes a part of the user interface that can dynamically
/// change its state (data) over time. Unlike a StatelessWidget, which is immutable and constant
/// once built, a StatefulWidget associates itself with a mutable State object that holds values
/// that can change during the widget's lifecycle.
///
/// [Why StatefulWidget is needed]
/// When an application needs to respond to user interactions (like inputting text, clicking a button,
/// or fetching data) by immediately updating what is displayed on the screen, a StatefulWidget is needed.
/// It provides a mechanism to track changes and redraw the UI dynamically.
///
/// [Difference between StatelessWidget and StatefulWidget]
/// 1. StatelessWidget:
///    - Cannot change its appearance or data after creation.
///    - It has no dynamic memory of user interactions.
///    - It is completely drawn based on parameters passed through its constructor.
/// 2. StatefulWidget:
///    - Can change its visual appearance in response to user events.
///    - It maintains an internal 'State' object that lives independently of the widget configuration itself.
///    - It can redraw itself multiple times using new state values.
class ProgressCard extends StatefulWidget {
  const ProgressCard({super.key});

  /// [What State class does]
  /// A StatefulWidget class itself is immutable (just like StatelessWidget).
  /// To support mutable data, Flutter separates the widget configuration from its state.
  /// The `createState()` method returns the companion [State] object where all mutable data,
  /// variables, and business logic reside. The state object persists even when Flutter destroys
  /// and recreates the parent widget instance during layout updates.
  @override
  State<ProgressCard> createState() => _ProgressCardState();
}

class _ProgressCardState extends State<ProgressCard> {
  // Local state variable to track the number of completed lessons.
  int completedLessons = 0;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Learning Progress',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Completed Lessons: $completedLessons',
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                /// [What setState() does]
                /// `setState()` is the built-in method we call to notify the Flutter framework that
                /// the internal state of this object has changed.
                /// It takes a callback function where we update our state variables (here, `completedLessons`).
                ///
                /// [Why UI rebuilds after state changes]
                /// When `setState()` is called, Flutter flags this State object as "dirty".
                /// During the next frame draw, Flutter automatically invokes the state's `build()` method again.
                /// The build method executes with the updated values, generating a new widget subtree that
                /// updates the screen, rendering the new lesson count.
                setState(() {
                  completedLessons++;
                });
              },
              child: const Text('Complete Lesson'),
            ),
          ],
        ),
      ),
    );
  }
}
