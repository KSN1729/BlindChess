# Day 12: Grid Selection & StatefulWidget Notes

Welcome to Day 12! Today, we took a deep dive into user selection states and dynamic rendering. We converted our **`LearningScreen`** into a `StatefulWidget` to maintain a mutable selected coordinate, and we modified our **`ChessSquare`** to conditionally draw a thick red border when active.

---

## 1. Why LearningScreen Became a StatefulWidget

On Day 11, the `LearningScreen` was a `StatelessWidget`. It could trigger a SnackBar notification on tap because showing a SnackBar is an action managed globally by `ScaffoldMessenger`, which does not modify the local properties of the screen.

However, to implement square selection:
1. We need to remember which square the user clicked.
2. We need this coordinate value to persist in memory across screen draws.
3. We need to trigger a redraw of the entire board when this selection changes to update the borders.

A `StatelessWidget` cannot hold dynamic variables or schedule redraws. Therefore, we converted `LearningScreen` into a `StatefulWidget` so we can store the `selectedSquare` variable in its persistent `State` object.

---

## 2. How Selection Works

The selection workflow runs as follows:
1. **User Action**: The user clicks on square **E4**.
2. **Event Trigger**: The `onTap` callback inside `ChessSquare` delegates execution to the anonymous callback defined in `LearningScreen`.
3. **State Mutation**: The callback runs `setState(() { selectedSquare = label; });`, assigning the value `'E4'` to our persistent state variable.
4. **Invalidation**: Flutter marks the `LearningScreen` state as dirty.
5. **Rebuild**: During the next draw frame, Flutter rebuilds `LearningScreen`.
6. **Comparison**: When generating each of the 64 squares, Flutter evaluates:
   - For `E4`: `isSelected = (selectedSquare == "E4")` $\rightarrow$ `true`.
   - For all other 63 squares: `isSelected = (selectedSquare == label)` $\rightarrow$ `false`.
7. **Redraw**: `ChessSquare` receives these booleans and draws the selected border styles accordingly.

---

## 3. What is Conditional Rendering

**Conditional rendering** is the technique of displaying different UI layouts, styles, or widgets based on certain runtime conditions (such as boolean flags or state values).

We implemented conditional rendering in two places:
1. **ChessSquare Border**:
   Inside `chess_square.dart`, we use Dart's ternary operator `condition ? expr1 : expr2` to decide which border configuration to paint:
   ```dart
   border: isSelected
       ? Border.all(color: Colors.red, width: 3.0)   // Selected style
       : Border.all(color: Colors.black, width: 1.5) // Default style
   ```
2. **Selection Label Text**:
   Inside `learning_screen.dart`, we use the null-coalescing operator `??` to conditionally choose the string:
   ```dart
   selectedSquare ?? 'None'
   ```
   If `selectedSquare` is null (initial state), it falls back to `'None'`.

---

## 4. Boolean Comparison & Expressions

A boolean expression evaluates to either `true` or `false`.
In our chessboard generator, we pass:
```dart
isSelected: selectedSquare == label
```
Here, `selectedSquare == label` compares the currently selected coordinate stored in our state against the coordinate label of the specific square being generated.
* If `selectedSquare` is `'E4'` and the square is `'E4'`, the comparison returns `true`.
* If `selectedSquare` is `'E4'` and the square is `'A1'`, the comparison returns `false`.

---

## 5. How Flutter Rebuilds Widgets

When `setState()` is called, Flutter does not perform fine-grained DOM modifications. Instead, it rebuilds the widget subtree:
1. It calls the `build()` method of the stateful class.
2. The method returns a completely new tree of widget configurations.
3. Flutter's engine performs a fast comparison (diffing) between the new widget tree and the active element tree (a process called **reconciliation**).
4. It updates only the specific visual elements (the borders and texts) that changed, keeping performance extremely high (up to 120 FPS).

---

## 6. Why Only One Square Stays Selected

Since we maintain selection using a single state variable (`String? selectedSquare`), that variable can only hold one string value at a time (e.g., it is either `'E4'`, `'A1'`, or `null`).

Because of this:
- The equality check `selectedSquare == label` can only evaluate to `true` for **one** coordinate label in the entire list of 64 squares.
- When the user taps a new square (e.g., `'A1'`), the variable updates to `'A1'`. The previous selection `'E4'` now evaluates to `false` (`"A1" == "E4"` is false).
- The red border automatically transfers to the new square, ensuring a clean, single-selection experience.

---

Congratulations on completing Day 12! You have successfully mastered stateful grid selections and conditional styling in Flutter.
