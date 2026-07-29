import 'package:flutter/material.dart';

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

  /// [Unicode characters]
  /// Unicode is a universal character encoding standard that assigns a unique number to every character,
  /// including symbols like emoji and chess pieces. This allows us to display rich chess symbols (e.g. ♜, ♔)
  /// directly in our text widgets as string values, without needing heavy image assets.
  final String piece;

  /// [Constructor parameters]
  /// The constructor allows parent widgets to pass configurations when instantiating this widget.
  /// - `this.squareColor` and `this.label` assign the passed values directly to our final fields.
  /// - `required` keyword guarantees that these parameters are provided at compilation time.
  /// - `this.onTap` is optional since a square might not always be interactive.
  /// - `this.isSelected` defaults to false.
  /// - `this.piece` defaults to an empty string representing an empty square.
  const ChessSquare({
    super.key,
    required this.squareColor,
    required this.label,
    this.onTap,
    this.isSelected = false,
    this.piece = '',
  });

  @override
  Widget build(BuildContext context) {
    /// [GestureDetector or InkWell]
    /// Both capture tap events, but:
    /// - [GestureDetector]: A non-visual gesture wrapper that detects raw taps, double-taps, drags,
    ///   and scales without adding any visual effects.
    /// - [InkWell]: A Material Design widget that captures taps and shows a visual splash/ripple animation.
    ///
    /// Here, we wrap the square in a [GestureDetector] to capture clicks, executing the callback
    /// when the tap gesture is detected.
    return GestureDetector(
      /// [Anonymous functions]
      /// Inside `onTap`, we pass a short inline anonymous function `() => onTap?.call()` to check
      /// if a callback was provided and execute it.
      onTap: () {
        onTap?.call();
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: squareColor,
          // Apply a thicker red border when selected, or standard black border when not.
          border: isSelected
              ? Border.all(
                  color: Colors.red,
                  width: 3.0,
                )
              : Border.all(
                  color: Colors.black,
                  width: 1.5,
                ),
        ),
        child: Center(
          // Conditional UI rendering: if no piece is on this square, show only the coordinate label.
          // Otherwise, stack the piece character above the coordinate label vertically using a Column.
          child: piece.isEmpty
              ? Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: squareColor == Colors.white ? Colors.black : Colors.white,
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      piece,
                      style: TextStyle(
                        fontSize: 26,
                        height: 1.1, // Set tight line height to prevent vertical alignment offset
                        color: squareColor == Colors.white ? Colors.black : Colors.white,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: squareColor == Colors.white
                            ? Colors.black.withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
