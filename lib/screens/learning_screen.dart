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
class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  // List of files (columns) from A to H to map files to indices.
  final files = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

  /// [selectedSquare variable]
  /// A mutable state variable that holds the coordinate label of the currently selected chess square (e.g., "E4").
  /// It is initialized to `null` to represent that no square is selected initially (which prints "None").
  String? selectedSquare;

  /// [Helper methods]
  /// A helper method is a function declared inside the state class to perform specific calculations
  /// or lookups. Instead of cluttering our UI build tree with complex conditional logic,
  /// we move that code into a helper function to keep the visual tree neat and maintainable.
  ///
  /// [Why logic is separated from UI]
  /// Separating logic from visual code makes UI rendering clean and decoupled. The build method
  /// only describes *what layout to draw*, while the helper method calculates *what data to put in it*.
  ///
  /// [Returning values]
  /// Functions return values using the `return` keyword, passing calculated results back to the caller.
  ///
  /// [Why empty strings are useful]
  /// We return an empty string `""` to represent empty chess squares. This acts as a standard sentinel
  /// value that tells the ChessSquare widget to skip piece rendering and only draw coordinates.
  String getPiece(int rankIndex, int fileIndex) {
    // Ranks:
    // rankIndex 0 represents Rank 8 (black back rank)
    // rankIndex 1 represents Rank 7 (black pawn rank)
    // rankIndex 2..5 represent empty squares (Ranks 6..3)
    // rankIndex 6 represents Rank 2 (white pawn rank)
    // rankIndex 7 represents Rank 1 (white back rank)
    if (rankIndex == 0) {
      // Black back rank pieces
      switch (fileIndex) {
        case 0:
        case 7:
          return '♜'; // Black Rook
        case 1:
        case 6:
          return '♞'; // Black Knight
        case 2:
        case 5:
          return '♝'; // Black Bishop
        case 3:
          return '♛'; // Black Queen
        case 4:
          return '♚'; // Black King
      }
    } else if (rankIndex == 1) {
      return '♟'; // Black Pawn
    } else if (rankIndex == 6) {
      return '♙'; // White Pawn
    } else if (rankIndex == 7) {
      // White back rank pieces
      switch (fileIndex) {
        case 0:
        case 7:
          return '♖'; // White Rook
        case 1:
        case 6:
          return '♘'; // White Knight
        case 2:
        case 5:
          return '♗'; // White Bishop
        case 3:
          return '♕'; // White Queen
        case 4:
          return '♔'; // White King
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
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

                /// [Looping in Flutter]
                /// Since Flutter layouts are constructed as nested trees of widget objects, we can use Dart's
                /// loop mechanisms directly inside our widget trees to generate arrays of child widgets dynamically.
                ///
                /// [List.generate()]
                /// A handy Dart constructor `List.generate(int length, Growable generator(int index))` that creates
                /// a list of objects. It executes the generator function once for each index from `0` to `length - 1`,
                /// outputting a list of widgets that Flutter renders sequentially.
                ///
                /// [Dynamic widget creation]
                /// Instead of hardcoding 64 separate [ChessSquare] widget calls in our source code, we use loops to
                /// dynamically instantiate widgets. The layout engine renders these widgets based on loop-calculated
                /// properties, saving manual typing and preventing errors.
                ///
                /// [Why dynamic generation is better than writing 64 widgets manually]
                /// 1. DRY (Don't Repeat Yourself): Reduces what would have been 1,000+ lines of duplicate container
                ///    instantiation markup down to under 30 lines.
                /// 2. Flexibility: If we want to change color logic, coordinates, or expand grid size (e.g., to 10x10),
                ///    we update a single formula rather than refactoring 64 hardcoded objects.
                /// 3. Readability: Keeps our visual widget tree clean and understandable.
                ///
                /// [Nested loops]
                /// To build a two-dimensional 8x8 chessboard, we place one loop inside another.
                /// - The outer loop runs 8 times to generate rows (representing ranks 8 down to 1).
                /// - The inner loop runs 8 times inside each row to generate columns (representing files A to H).
                /// This results in a total of 8 * 8 = 64 composed widgets.
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(8, (rankIndex) {
                    /// [Index values]
                    /// The generator function provides a 0-based integer index for each iteration.
                    /// Here, `rankIndex` starts at `0` and runs to `7`. We map this to chess ranks:
                    /// index 0 -> rank 8 (top row), index 7 -> rank 1 (bottom row).
                    final rank = 8 - rankIndex;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(8, (fileIndex) {
                        /// [Index values (inner loop)]
                        /// `fileIndex` starts at `0` and runs to `7`. We map this to files using our list:
                        /// index 0 -> file 'A' (left-most), index 7 -> file 'H' (right-most).
                        final file = files[fileIndex];
                        final label = '$file$rank';

                        // Alternating color logic:
                        // Square a1 (fileIndex=0, rankIndex=7) must be dark (brown).
                        // Sum of indices for a1 is 7 + 0 = 7 (odd).
                        // If (rankIndex + fileIndex) is odd, it is a brown square; if even, it is white.
                        final isDark = (rankIndex + fileIndex) % 2 != 0;
                        final squareColor = isDark ? Colors.brown : Colors.white;

                        /// [Boolean expressions]
                        /// `selectedSquare == label` is a boolean expression evaluating to `true` or `false`.
                        /// If the current square matches the selected coordinate, we pass `true` to `isSelected`.
                        ///
                        /// [Why only one square is highlighted]
                        /// Since `selectedSquare` is a single variable, the comparison `selectedSquare == label`
                        /// can evaluate to `true` for at most one square at any given time. All other 63 squares
                        /// evaluate to `false` and render with standard black borders.
                        return ChessSquare(
                          squareColor: squareColor,
                          label: label,
                          isSelected: selectedSquare == label,
                          piece: getPiece(rankIndex, fileIndex),
                          onTap: () {
                            // Clear any existing snack bars to prevent queueing delay
                            ScaffoldMessenger.of(context).clearSnackBars();
                            
                            // Show a sliding notification with the tapped square coordinates.
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('You tapped $label'),
                                duration: const Duration(seconds: 1),
                              ),
                            );

                            /// [setState()]
                            /// Tapping a square updates the `selectedSquare` variable.
                            /// Wrapping this state change in `setState()` tells the Flutter framework to mark
                            /// this widget as "dirty" and schedule a rebuild, running the build method again
                            /// to reflect the new selection on screen.
                            setState(() {
                              selectedSquare = label;
                            });
                          },
                        );
                      }),
                    );
                  }),
                ),

                const SizedBox(height: 12),

                // Title displaying which square is currently selected
                const Text(
                  'Selected Square:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                /// [Conditional UI]
                /// We use conditional rendering (`selectedSquare ?? 'None'`) to decide what text to show.
                /// If the variable is `null`, it renders `'None'`. If it has a value, it renders the coordinate.
                Text(
                  selectedSquare ?? 'None',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
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
