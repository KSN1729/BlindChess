import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/chess_piece.dart';
import '../utils/chess_svgs.dart';
import '../services/settings_service.dart';

/// [StatelessWidget]
/// A StatelessWidget is a widget that does not maintain dynamic internal state. Once built,
/// its visual representation is completely constant, determined solely by the values passed
/// to it during creation. This widget is fast and efficient because it never needs to trigger
/// its own redraw.
///
/// [Why reusable widgets are useful]
/// Instead of duplicating code for 64 different squares on a chessboard, we write a single
/// reusable [ChessSquare] widget. Reusable widgets promote DRY (Don't Repeat Yourself) design,
/// make it extremely easy to tweak visual borders or layouts in one place, and ensure consistent
/// behavior across our application.
///
/// [Reusable code]
/// Reusable code isolates specific behaviors and layouts so they can be instantiated anywhere.
/// By passing parameters like `pieceName` and `isWhitePiece` into ChessSquare, we keep this widget
/// completely flexible—it can display any piece type, color, and coordinate without hardcoding
/// internal mapping logics.
class ChessSquare extends StatelessWidget {
  /// [final variables]
  /// In Dart, fields of a StatelessWidget must be declared as `final`.
  /// This indicates that once the variables are initialized in the constructor, their values
  /// cannot be reassigned or modified. Immutability ensures predictability and thread-safety
  /// in the widget tree.
  final Color squareColor;
  final String label;

  /// [Callback functions]
  /// A callback is a function passed as an argument to another widget. It allows a child widget
  /// to notify its parent when an event occurs (like a user tap), delegating the actual execution
  /// logic back to the parent where the business logic or state is managed.
  ///
  /// [VoidCallback]
  /// A built-in Dart type definition (typedef) representing a function that takes no arguments
  /// and returns no value (`void Function()`). It is widely used in Flutter for tap, change, and press events.
  ///
  /// [Passing functions to child widgets]
  /// By declaring `onTap` as a constructor parameter, the parent screen can inject a customized
  /// function. The child widget acts as a mediator, simply holding the function reference and
  /// executing it when triggered.
  final VoidCallback? onTap;

  // The selection state parameter passed to check if this square is chosen.
  final bool isSelected;

  /// [Null safety]
  /// Dart is a null-safe language. Null safety prevents bugs caused by trying to access fields or methods
  /// on a `null` variable (which raises a Null Pointer Exception).
  ///
  /// By declaring `ChessPiece? piece` (with a question mark `?`), we inform Dart that this parameter is nullable—it
  /// can hold a concrete `ChessPiece` object, or it can hold `null` representing an empty square. Dart requires
  /// us to check if the value is null before using it.
  final ChessPiece? piece;

  // The English name of the piece (e.g. 'King', 'Queen', etc.) or 'Empty'.
  final String pieceName;

  // True if the piece is white, false otherwise.
  final bool isWhitePiece;

  // True if the king on this square is currently in check.
  final bool isCheck;

  // True if the piece symbol should be hidden under Blindfold Mode rules.
  final bool isPieceHidden;

  // Visual guess evaluation state ('green' for correct, 'red' for incorrect, or null).
  final String? flashState;

  /// [Constructor parameters]
  /// The constructor allows parent widgets to pass configurations when instantiating this widget.
  /// - `this.squareColor` and `this.label` assign the passed values directly to our final fields.
  /// - `required` keyword guarantees that these parameters are provided at compilation time.
  /// - `this.onTap` is optional since a square might not always be interactive.
  /// - `this.isSelected` defaults to false.
  /// - `this.piece` is optional and can be null for empty squares.
  /// - `this.pieceName` defaults to 'Empty'.
  /// - `this.isWhitePiece` defaults to false.
  const ChessSquare({
    super.key,
    required this.squareColor,
    required this.label,
    this.onTap,
    this.isSelected = false,
    this.piece,
    this.pieceName = 'Empty',
    this.isWhitePiece = false,
    this.isCheck = false,
    this.isPieceHidden = false,
    this.flashState,
  });

  @override
  Widget build(BuildContext context) {
    /// [Tooltip widget]
    /// A built-in Material design widget that displays a floating text description when a user long-presses
    /// (on mobile devices) or hovers (on desktop web browsers) the wrapped widget. Tooltips significantly
    /// improve visual accessibility by explaining what obscure graphical symbols represent.
    ///
    /// If Blindfold Mode is active and hiding pieces, we obfuscate the tooltip message to prevent cheating.
    return Tooltip(
      message: isPieceHidden
          ? 'Square $label'
          : (pieceName == 'Empty'
                ? 'Empty Square'
                : '${isWhitePiece ? 'White' : 'Black'} $pieceName'),
      child: GestureDetector(
        /// [Anonymous functions]
        /// Inside `onTap`, we pass a short inline anonymous function `() => onTap?.call()` to check
        /// if a callback was provided and execute it.
        onTap: () {
          onTap?.call();
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final squareSize = constraints.maxWidth;
            final pieceSize =
                squareSize * 0.55; // 55% of square size for the piece SVG
            final fontSize =
                squareSize *
                0.25; // 25% of square size for coordinates when empty
            final labelFontSize =
                squareSize * 0.18; // 18% for small rank/file labels

            return Container(
              decoration: BoxDecoration(
                color: squareColor,
                // Apply a thicker red border when selected, or standard black border when not.
                border: isSelected
                    ? Border.all(color: Colors.red, width: 3.0)
                    : Border.all(color: Colors.black, width: 1.5),
                // Apply a glowing red shadow around the checked king's square
                boxShadow: isCheck
                    ? [
                        const BoxShadow(
                          color: Colors.redAccent,
                          blurRadius: 12.0,
                          spreadRadius: 3.0,
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                children: [
                  Center(
                    // Conditional UI rendering: if no piece is on this square, show only the coordinate label.
                    // Otherwise, stack the piece SVG graphic above the coordinate label vertically.
                    child: piece == null
                        ? Text(
                            SettingsService.instance.showCoordinates ? label : '',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: fontSize,
                              color: squareColor == Colors.white
                                  ? Colors.black
                                  : Colors.white,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedOpacity(
                                opacity: isPieceHidden ? 0.0 : 1.0,
                                duration: const Duration(milliseconds: 250),
                                child: SizedBox(
                                  width: pieceSize,
                                  height: pieceSize,
                                  child: SvgPicture.string(
                                    getPieceSvg(
                                      piece!.pieceType,
                                      piece!.pieceColor,
                                      SettingsService.instance.boardTheme,
                                    ),
                                  ),
                                ),
                              ),
                              if (SettingsService.instance.showCoordinates) ...[
                                SizedBox(height: squareSize * 0.02),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: labelFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: squareColor == Colors.white
                                        ? Colors.black.withValues(alpha: 0.6)
                                        : Colors.white.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                  // Correct/Incorrect feedback overlay
                  if (flashState != null)
                    Positioned.fill(
                      child: Container(
                        color: flashState == 'green'
                            ? Colors.green.withValues(alpha: 0.4)
                            : Colors.red.withValues(alpha: 0.4),
                        child: Center(
                          child: Text(
                            flashState == 'green' ? '✓' : '✗',
                            style: TextStyle(
                              fontSize: squareSize * 0.5,
                              fontWeight: FontWeight.bold,
                              color: flashState == 'green'
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
