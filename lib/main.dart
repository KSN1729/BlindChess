import 'package:flutter/material.dart';

// main is the entry point of the Flutter application.
void main() {
  runApp(const MyApp());
}

/// [MaterialApp]
/// The root widget of a Flutter application. It configures the general metadata of the app
/// (such as title, theme, and navigation routes) and enables Material Design features.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // The title of the application, used by the operating system for display (e.g., in task managers).
      title: 'BlindChess Learning',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // The default home screen of the application.
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    /// [SafeArea]
    /// A helper widget that automatically inserts padding to avoid overlapping with
    /// system UI elements like notch, status bar, navigation bar, or rounded corners.
    return SafeArea(
      /// [Scaffold]
      /// A container widget that provides a structural layout framework for a Material Design screen.
      /// It contains slots for major components like an AppBar, Drawer, FloatingActionButton, and a Body.
      child: Scaffold(
        /// [AppBar]
        /// A top toolbar widget that displays branding, screen title, and utility actions.
        /// It helps define the context of the screen.
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          // The title widget displayed in the AppBar.
          title: const Text('BlindChess'),
        ),
        /// [Center]
        /// A layout widget that aligns its single child widget in the exact center
        /// (both horizontally and vertically) of the available space.
        body: Center(
          /// [Column]
          /// A multi-child layout widget that displays its children in a vertical sequence (top-to-bottom).
          /// It supports aligning children horizontally and distributing them vertically.
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              /// [Padding]
              /// A layout widget that wraps another widget and adds space around it
              /// based on the provided EdgeInsets constraints.
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                /// [Text]
                /// A basic widget that renders a single line or multi-line styled text string
                /// with custom font size, weight, alignment, and color.
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
              /// [Container]
              /// A general-purpose widget that combines painting, positioning, and sizing.
              /// It can display colors, borders, shadows, backgrounds, padding, margins, and shapes.
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                /// [Icon]
                /// A widget that displays a graphical vector symbol or glyph from a font family
                /// (like the standard Material Icons font).
                child: const Icon(
                  Icons.grid_on, // Grid icon representing a chessboard layout
                  size: 64,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 32),
              /// [ElevatedButton]
              /// A Material Design button that elevates above the background when active.
              /// It triggers a callback function (onPressed) when tapped by the user.
              ElevatedButton(
                onPressed: () {
                  // ScaffoldMessenger is used to display snack bar messages at the bottom of the screen.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('BlindChess journey begins!'),
                      duration: Duration(seconds: 2),
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