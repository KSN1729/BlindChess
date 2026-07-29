import 'package:flutter/material.dart';
import '../widgets/section_title.dart';
import '../widgets/progress_card.dart';
import '../widgets/chess_square.dart';

/// [Why widgets are separated]
/// Keeping screens and layout components in separate files separates concerns and makes the codebase
/// highly organized, clean, and scaling-friendly.
///
/// [Widget reuse]
/// Reusable widgets let us write logic and styling rules in a single place. The [SectionTitle] widget,
/// for instance, ensures the font sizes, weights, and center alignments match perfectly on both screens.
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
    // List of files (columns) from A to H to map files to indices.
    final files = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: const Text('Learning Mode'),
        ),
        // We use SingleChildScrollView to make the screen scrollable, preventing layout overflow warnings.
        body: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
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
                const SizedBox(height: 16),
                
                // Chessboard Demo Title
                const Text(
                  'Complete 8×8 Chessboard',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 12),

                /// [Widget composition]
                /// In Flutter, we build complex visual interfaces by combining simple, basic widgets.
                /// Instead of coding a single massive grid widget from scratch, we compose the chessboard
                /// by nesting smaller components: a Column contains Rows, which in turn contain ChessSquares.
                ///
                /// [Why reusable widgets make the board easy to build]
                /// Building an 8x8 chessboard requires 64 squares. Without a reusable widget, we would need
                /// to duplicate the Container, BoxDecoration, borders, and labels 64 times. By leveraging our
                /// reusable `ChessSquare` class, we can construct the entire board dynamically using simple,
                /// clean configurations.
                ///
                /// [Column]
                /// A multi-child layout widget that arranges its children vertically from top to bottom.
                /// Here, the Column stacks the 8 chessboard ranks (rows) vertically on top of each other.
                ///
                /// [Row]
                /// A multi-child layout widget that arranges its children horizontally from left to right.
                /// Here, each Row displays a single chess rank consisting of 8 horizontal ChessSquares.
                ///
                /// [Nested widgets]
                /// Placing widgets inside other widgets (such as Rows inside a Column, and ChessSquares
                /// inside those Rows) is called nesting. This forms the hierarchical parent-child relationships
                /// that define Flutter's layout engine.
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(8, (rankIndex) {
                    // rankIndex: 0 (top row, rank 8) to 7 (bottom row, rank 1)
                    final rank = 8 - rankIndex;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(8, (fileIndex) {
                        // fileIndex: 0 (A) to 7 (H)
                        final file = files[fileIndex];
                        final label = '$file$rank';

                        // Alternating color logic:
                        // Square a1 (fileIndex=0, rankIndex=7) must be dark (brown).
                        // Sum of indices for a1 is 7 + 0 = 7 (odd).
                        // If (rankIndex + fileIndex) is odd, it is a brown square; if even, it is white.
                        final isDark = (rankIndex + fileIndex) % 2 != 0;
                        final squareColor = isDark ? Colors.brown : Colors.white;

                        return ChessSquare(
                          squareColor: squareColor,
                          label: label,
                        );
                      }),
                    );
                  }),
                ),

                const SizedBox(height: 16),
                // We display the learning progress card here
                const ProgressCard(),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Back Home'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
