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

  /// [Boolean variables]
  /// A boolean is a primitive data type that holds one of two possible values: `true` or `false`.
  /// Here, `isWhitePerspective` keeps track of the active board view orientation.
  bool isWhitePerspective = true;

  /// [selectedSquare variable]
  /// A mutable state variable that holds the coordinate label of the currently selected chess square (e.g., "E4").
  /// It is initialized to `null` to represent that no square is selected initially (which prints "None").
  String? selectedSquare;

  /// [Two-dimensional lists]
  /// A two-dimensional (2D) list is a list of lists, often used to represent a grid, table, or matrix in software.
  /// The outer list contains rows, and each inner list contains columns representing individual cells.
  ///
  /// [Why data should be stored separately from UI]
  /// By separating the board data state (`board`) from our layout rendering (`build` method), we follow the MVC
  /// (Model-View-Controller) design pattern. The visual builder simply draws the squares without needing to calculate
  /// where pieces go, making the code cleaner, less error-prone, testable, and highly scaling-friendly.
  ///
  /// [Rows and columns]
  /// The matrix consists of 8 rows (representing ranks 8 down to 1) and 8 columns (representing files A to H).
  final List<List<String>> board = const [
    ['♜', '♞', '♝', '♛', '♚', '♝', '♞', '♜'], // Row 0 -> Rank 8 (Black back rank)
    ['♟', '♟', '♟', '♟', '♟', '♟', '♟', '♟'], // Row 1 -> Rank 7 (Black pawns)
    ['', '', '', '', '', '', '', ''],         // Row 2 -> Rank 6 (Empty)
    ['', '', '', '', '', '', '', ''],         // Row 3 -> Rank 5 (Empty)
    ['', '', '', '', '', '', '', ''],         // Row 4 -> Rank 4 (Empty)
    ['', '', '', '', '', '', '', ''],         // Row 5 -> Rank 3 (Empty)
    ['♙', '♙', '♙', '♙', '♙', '♙', '♙', '♙'], // Row 6 -> Rank 2 (White pawns)
    ['♖', '♘', '♗', '♕', '♔', '♗', '♘', '♖'], // Row 7 -> Rank 1 (White back rank)
  ];

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

                /// [Flip Board Button]
                /// Toggling the perspective state triggers a UI rebuild using setState().
                ElevatedButton(
                  onPressed: () {
                    /// [setState()]
                    /// We use setState() to inform the Flutter framework that a state variable (isWhitePerspective)
                    /// has changed, prompting it to call the build method again to redraw the chessboard.
                    setState(() {
                      isWhitePerspective = !isWhitePerspective;
                    });
                  },
                  child: const Text('Flip Board'),
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
                    /// [Reversing row indexes]
                    /// Under White's perspective, row index 0 displays Rank 8 (top row) and row index 7 displays Rank 1 (bottom row).
                    /// When `isWhitePerspective` is false (Black's perspective), we reverse this lookup:
                    /// row index 0 displays Rank 1 and row index 7 displays Rank 8.
                    final actualRowIndex = isWhitePerspective ? rankIndex : 7 - rankIndex;
                    final rank = 8 - actualRowIndex;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(8, (fileIndex) {
                        /// [Reversing column indexes]
                        /// Under White's perspective, column index 0 is File A (left-most) and column index 7 is File H (right-most).
                        /// When `isWhitePerspective` is false (Black's perspective), we reverse this lookup:
                        /// column index 0 displays File H and column index 7 displays File A.
                        final actualColIndex = isWhitePerspective ? fileIndex : 7 - fileIndex;
                        final file = files[actualColIndex];
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

                        /// [Accessing data using indexes]
                        /// To get the correct chess piece for the square, we read directly from our matrix list using
                        /// indices. The first index `actualRowIndex` selects the row, and the second index `actualColIndex` selects
                        /// the column within that row.
                        ///
                        /// [board[row][column]]
                        /// Syntactically, `board[actualRowIndex][actualColIndex]` queries the nested array. For example:
                        /// `board[0][4]` evaluates to '♚' (Black King on E8), while `board[3][3]` evaluates to `""`.
                        ///
                        /// [Board orientation]
                        /// Board orientation describes the direction from which the players view the grid.
                        /// Reversing indices shifts the visual position of pieces 180 degrees.
                        ///
                        /// [Why board data remains unchanged]
                        /// We never write values to, or change the structural layout of, the underlying `board` list state
                        /// when flipping the board. Only the representation layout (the projected coordinates) changes.
                        return ChessSquare(
                          squareColor: squareColor,
                          label: label,
                          isSelected: selectedSquare == label,
                          piece: board[actualRowIndex][actualColIndex],
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
