import 'package:flutter/material.dart';

/// [Reusable Widgets]
/// In Flutter, a reusable widget is a custom self-contained widget designed to perform
/// a specific visual or functional role. Instead of copying and pasting the same widget
/// configuration (like styling, colors, and fonts) across different screens, we build
/// a single widget and use it everywhere.
/// This makes code DRY (Don't Repeat Yourself), ensures design consistency, and makes
/// global UI updates extremely simple.

/// [StatelessWidget]
/// A widget that does not require mutable state. Once created, its appearance is fully determined
/// by the configuration inputs (constructor parameters) passed to it. In Flutter, all fields
/// of a [StatelessWidget] must be marked as `final` because the widget itself is immutable
/// and cannot change its properties dynamically after build time.
class SectionTitle extends StatelessWidget {
  /// [Constructor Parameters]
  /// We define a final field to hold the input title value.
  /// Being `final` means it is set once during instantiation and cannot be changed later.
  final String title;

  /// [Constructor]
  /// This constructor initializes the widget.
  /// - `super.key` passes a unique identifier key to the parent `StatelessWidget` constructor,
  ///   helping Flutter efficiently track and update widgets in the element tree.
  /// - `required this.title` is a named parameter specifying that the caller must supply
  ///   the title string when instantiating this widget.
  const SectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    // The build method describes the visual representation of our widget.
    // It returns a standard Text widget configured with our styling rules.
    return Text(
      title,
      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      textAlign: TextAlign.center,
    );
  }
}
