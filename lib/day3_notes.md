# Day 3 Master Notes: Flutter UI Layout & Widgets

Welcome to Day 3 of your training! This document is a comprehensive guide to building user interfaces in Flutter, including the layout system, sizing computations, and a detailed guide on 25 foundational widgets.

---

## The Flutter Layout Rule: "Constraints Go Down, Sizes Go Up, Parent Sets Position"

To build layouts successfully in Flutter, you must memorize this fundamental rule:

1. **Constraints Go Down:** The parent widget passes constraints (minimum/maximum width and height) down to its child.
2. **Sizes Go Up:** The child widget determines its own size based on the constraints it received, and reports this size up to the parent.
3. **Parent Sets Position:** The parent widget places the child at a specific coordinate (X, Y) on the screen canvas.

```
       Parent (Constraint: Min W: 0, Max W: 400)
         │
         ▼  (Constraints Go Down)
       Child (Decides size: W: 150, H: 100)
         │
         ▲  (Sizes Go Up)
       Parent (Sets position: Centered at X: 125, Y: 50)
```

### Key Layout Concepts
* **Widget Tree:** The hierarchy of widget blueprints you define in code.
* **MainAxis & CrossAxis:**
  * In a **`Column`** (vertical layout): MainAxis is vertical; CrossAxis is horizontal.
  * In a **`Row`** (horizontal layout): MainAxis is horizontal; CrossAxis is vertical.
* **Alignment:** 
  * `MainAxisAlignment` governs alignment along the MainAxis (e.g. `center`, `spaceBetween`).
  * `CrossAxisAlignment` governs alignment along the CrossAxis (e.g. `stretch`, `center`).
* **Nested & Responsive Layouts:** Using combinations of flex columns, rows, and media queries to adapt to varying device aspect ratios.

---

## Comprehensive Widget Directory (25 Essential Widgets)

---

### 1. Text
* **Purpose:** Displays a string of styled text.
* **Syntax:** `Text('Label', style: TextStyle())`
* **Important Properties:** `style`, `textAlign`, `maxLines`, `overflow`.
* **When to use:** Whenever you need to show labels, messages, or titles.
* **When NOT to use:** For text entry (use `TextField` instead).
* **Common Mistakes:** Hardcoding colors instead of pulling from the current `Theme`.
* **Performance:** Mark with `const` if the text string and style are static.
* **Simple Examples:**
  1. `Text('Hello World')`
  2. `Text('Bold Title', style: TextStyle(fontWeight: FontWeight.bold))`
* **BlindChess Example:**
  ```dart
  Text('White to move', style: Theme.of(context).textTheme.titleLarge)
  ```

---

### 2. Icon
* **Purpose:** Renders a graphic icon from a font glyph library.
* **Syntax:** `Icon(Icons.play_arrow)`
* **Important Properties:** `icon`, `size`, `color`.
* **When to use:** Showing decorative symbols or indicators.
* **When NOT to use:** If you need a tap handler (wrap it in an `IconButton` or `GestureDetector` instead).
* **Common Mistakes:** Setting sizes without wrapping, leading to layout overflows.
* **Performance:** Highly optimized; always declare icons as `const`.
* **Simple Examples:**
  1. `Icon(Icons.favorite, color: Colors.red)`
  2. `Icon(Icons.settings, size: 36.0)`
* **BlindChess Example:**
  ```dart
  Icon(Icons.flag, color: Colors.red, size: 28.0) // Resign flag
  ```

---

### 3. Image
* **Purpose:** Displays an image asset, network file, or memory buffer.
* **Syntax:** `Image.asset('path')` or `Image.network('url')`
* **Important Properties:** `fit` (`BoxFit`), `width`, `height`, `loadingBuilder`.
* **When to use:** Visual backgrounds, custom graphics, or logos.
* **When NOT to use:** For standard vector shapes (use `CustomPaint` or icons).
* **Common Mistakes:** Loading high-resolution images from assets without resizing, leading to memory bloat.
* **Performance:** Use appropriate cache sizes and format types.
* **Simple Examples:**
  1. `Image.network('https://example.com/logo.png')`
  2. `Image.asset('assets/avatar.png', width: 50, height: 50)`
* **BlindChess Example:**
  ```dart
  Image.asset('assets/pieces/white_knight.png', fit: BoxFit.contain)
  ```

---

### 4. Container
* **Purpose:** A multi-feature structural block combining sizing, margin, padding, border decoration, and background coloring.
* **Syntax:** `Container(decoration: BoxDecoration())`
* **Important Properties:** `padding`, `margin`, `decoration`, `width`, `height`, `constraints`.
* **When to use:** When you need a combination of custom background styling, borders, and margins.
* **When NOT to use:** If you only need padding (use `Padding`) or empty spacing (use `SizedBox`).
* **Common Mistakes:** Setting both `color` and `decoration` properties at the same time (throws runtime error; color must go inside the `decoration` object).
* **Performance:** Containers are heavy to paint; avoid using them for simple spacing.
* **Simple Examples:**
  1. `Container(color: Colors.blue, width: 100, height: 100)`
  2. `Container(padding: EdgeInsets.all(8), child: Text('Child'))`
* **BlindChess Example:**
  ```dart
  Container(
    width: 45,
    height: 45,
    decoration: BoxDecoration(
      color: Colors.brown[300],
      border: Border.all(color: Colors.black, width: 0.5),
    ),
  )
  ```

---

### 5. Padding
* **Purpose:** Adds empty buffer space around its single child widget.
* **Syntax:** `Padding(padding: EdgeInsets.all(8), child: ...)`
* **Important Properties:** `padding`, `child`.
* **When to use:** To separate a specific widget from adjacent content.
* **When NOT to use:** Do not nest multiple `Padding` widgets; combine margins or expand padding parameters instead.
* **Common Mistakes:** Using empty `SizedBox` blocks inside scroll views instead of padding, causing structural offsets.
* **Performance:** Extremely lightweight. Prefer this over empty containers.
* **Simple Examples:**
  1. `Padding(padding: EdgeInsets.only(top: 16.0), child: Text('Spacing'))`
  2. `Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Icon(Icons.add))`
* **BlindChess Example:**
  ```dart
  Padding(
    padding: const EdgeInsets.all(8.0),
    child: Text('Captured Pieces:'),
  )
  ```

---

### 6. Margin (via Container)
* **Purpose:** Creates spacing around the *outside* perimeter of a widget, pushing neighbors away.
* **Syntax:** `Container(margin: EdgeInsets.all(12), child: ...)`
* **Important Properties:** Managed using the `margin` property inside a `Container`.
* **When to use:** Creating a buffer gap between separate high-level sections.
* **When NOT to use:** When you need padding *inside* the widget container boundaries.
* **Common Mistakes:** Confusing margin (outside buffer) with padding (inside buffer).
* **Performance:** Handled by layout constraints within the Container lifecycle.
* **Simple Examples:**
  1. `Container(margin: EdgeInsets.all(20), child: Text('Margined'))`
  2. `Container(margin: EdgeInsets.symmetric(vertical: 10), child: Card())`
* **BlindChess Example:**
  ```dart
  Container(
    margin: const EdgeInsets.symmetric(vertical: 16.0),
    child: Text('Game Clock Display'),
  )
  ```

---

### 7. SizedBox
* **Purpose:** A box with a fixed width, height, or both, forcing its child to match those dimensions.
* **Syntax:** `SizedBox(width: 20, height: 20)`
* **Important Properties:** `width`, `height`, `child`.
* **When to use:** Creating exact spacing between elements in Columns/Rows, or sizing buttons.
* **When NOT to use:** When you need background decorations or borders (use `Container`).
* **Common Mistakes:** Specifying double infinity dimensions inside unconstrained layout trees (results in crashes).
* **Performance:** Extremely lightweight; preferred over `Container` for simple spacing.
* **Simple Examples:**
  1. `SizedBox(height: 16.0) // Vertical spacing`
  2. `SizedBox(width: 200, child: ElevatedButton(...))`
* **BlindChess Example:**
  ```dart
  const SizedBox(width: 8.0) // Spacing between chess captured counts
  ```

---

### 8. Row
* **Purpose:** Arranges child widgets in a horizontal line.
* **Syntax:** `Row(children: [])`
* **Important Properties:** `mainAxisAlignment`, `crossAxisAlignment`, `mainAxisSize`.
* **When to use:** Laying out side-by-side elements (e.g. icon + text label).
* **When NOT to use:** If contents might overflow the horizontal screen borders (use a scrollable list instead).
* **Common Mistakes:** Placing unconstrained children like `ListView` directly inside a Row without wrapping.
* **Performance:** Rebuilds children elements simultaneously. Optimize alignment.
* **Simple Examples:**
  1. `Row(children: [Text('A'), Text('B')])`
  2. `Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [...])`
* **BlindChess Example:**
  ```dart
  Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [Text('Player 1: 10:00'), Text('Player 2: 09:45')],
  )
  ```

---

### 9. Column
* **Purpose:** Arranges child widgets in a vertical stack.
* **Syntax:** `Column(children: [])`
* **Important Properties:** `mainAxisAlignment`, `crossAxisAlignment`, `mainAxisSize`.
* **When to use:** Ordering elements sequentially from top to bottom.
* **When NOT to use:** When content exceeds the vertical screen length, resulting in a yellow overflow warning (use `ListView` instead).
* **Common Mistakes:** Nesting columns without specifying bounds, causing unbounded height errors.
* **Performance:** Keep widget nesting count shallow.
* **Simple Examples:**
  1. `Column(children: [Text('Top'), Text('Bottom')])`
  2. `Column(crossAxisAlignment: CrossAxisAlignment.start, children: [...])`
* **BlindChess Example:**
  ```dart
  Column(
    children: [
      Text('Current Score'),
      Text('+3 pawns'),
    ],
  )
  ```

---

### 10. Expanded
* **Purpose:** Forces a child of a `Row`, `Column`, or `Flex` to fill all remaining available space.
* **Syntax:** `Expanded(flex: 1, child: ...)`
* **Important Properties:** `flex` (proportional share factor), `child`.
* **When to use:** Preventing layout overflow and sizing layouts proportionally.
* **When NOT to use:** Outside of flex widgets (Columns, Rows, Flex). Will throw an error.
* **Common Mistakes:** Wrapping every element in a Row with `Expanded` without setting appropriate flex ratios.
* **Performance:** Very efficient for dynamically calculating screen proportions.
* **Simple Examples:**
  1. `Row(children: [Expanded(child: Container(color: Colors.red)), Text('Label')])`
  2. `Column(children: [Expanded(flex: 2, child: A), Expanded(flex: 1, child: B)])`
* **BlindChess Example:**
  ```dart
  Row(
    children: [
      Expanded(child: Text('Player Names')), // Takes remaining space
      IconButton(onPressed: () {}, icon: Icon(Icons.settings)),
    ],
  )
  ```

---

### 11. Flexible
* **Purpose:** Similar to `Expanded`, but allows the child to size itself smaller than the maximum remaining space.
* **Syntax:** `Flexible(fit: FlexFit.loose, child: ...)`
* **Important Properties:** `flex`, `fit` (`FlexFit.tight` behaves like `Expanded`).
* **When to use:** When you want a child to resize dynamically without forcing it to fill the entire remaining layout space.
* **When NOT to use:** Outside of flex columns or rows.
* **Common Mistakes:** Confusing it with `Expanded` (Expanded forces the child to fill the space; Flexible allows it to shrink).
* **Performance:** Lightweight dynamic constraints.
* **Simple Examples:**
  1. `Row(children: [Flexible(child: Text('Short Text')), Container()])`
  2. `Flexible(fit: FlexFit.loose, child: Container(width: 50))`
* **BlindChess Example:**
  ```dart
  Flexible(
    fit: FlexFit.loose,
    child: Text('Long Chess Move History text log...'),
  )
  ```

---

### 12. Align
* **Purpose:** Positions a child widget relative to its parent bounds.
* **Syntax:** `Align(alignment: Alignment.topRight, child: ...)`
* **Important Properties:** `alignment` (e.g. `Alignment.centerLeft`), `widthFactor`, `heightFactor`.
* **When to use:** Placing an element at a specific border or corner within a layout structure.
* **When NOT to use:** If you need absolute overlap positioning (use `Stack` / `Positioned` instead).
* **Common Mistakes:** Omitting alignment bounds, causing elements to default to center alignment.
* **Performance:** Optimized layout positioning.
* **Simple Examples:**
  1. `Align(alignment: Alignment.bottomRight, child: Text('Corner'))`
  2. `Align(alignment: Alignment(-0.8, 0.0), child: Icon(Icons.star))`
* **BlindChess Example:**
  ```dart
  Align(
    alignment: Alignment.centerLeft,
    child: Text('Captured Pieces:'),
  )
  ```

---

### 13. Center
* **Purpose:** A specific case of the `Align` widget that centers its child both horizontally and vertically.
* **Syntax:** `Center(child: ...)`
* **Important Properties:** `widthFactor`, `heightFactor`.
* **When to use:** Centering text blocks, progress loaders, or empty screen states.
* **When NOT to use:** When you need multi-child alignments along a row or column direction.
* **Common Mistakes:** Wrapping every nested layout block in a `Center` widget, causing sizing errors.
* **Performance:** Highly optimized centering calculations.
* **Simple Examples:**
  1. `Center(child: CircularProgressIndicator())`
  2. `Center(child: Text('No Data'))`
* **BlindChess Example:**
  ```dart
  Center(
    child: Text('Draw Offered'),
  )
  ```

---

### 14. Stack
* **Purpose:** Lays out children on top of each other, overlapping them.
* **Syntax:** `Stack(children: [])`
* **Important Properties:** `alignment`, `fit`, `clipBehavior`.
* **When to use:** Overlaying text badges on images, custom floating indicators, or stacked backgrounds.
* **When NOT to use:** For standard sequence flow positions (use `Column` or `Row`).
* **Common Mistakes:** Placing unconstrained children inside a Stack, causing alignment glitches.
* **Performance:** Marginally heavy to render because children are drawn over one another.
* **Simple Examples:**
  1. `Stack(children: [Image.asset('bg.png'), Center(child: Text('Overlay'))])`
  2. `Stack(alignment: Alignment.topRight, children: [Icon(Icons.mail), Badge()])`
* **BlindChess Example:**
  ```dart
  Stack(
    children: [
      ChessBoardView(),
      Positioned(top: 10, left: 10, child: Text('09:45')), // overlay clock on board
    ],
  )
  ```

---

### 15. Positioned
* **Purpose:** Positions a child widget within a `Stack` using absolute offsets.
* **Syntax:** `Positioned(top: 10, right: 10, child: ...)`
* **Important Properties:** `top`, `bottom`, `left`, `right`, `width`, `height`.
* **When to use:** Offsetting overlays within a Stack widget.
* **When NOT to use:** Anywhere outside a `Stack` widget.
* **Common Mistakes:** Specifying both `left` and `right` along with a fixed `width`, causing layout conflicts.
* **Performance:** Direct positioning calculations.
* **Simple Examples:**
  1. `Positioned(bottom: 0, left: 0, right: 0, child: Text('Footer'))`
  2. `Positioned(top: 8, right: 8, child: RedDotIndicator())`
* **BlindChess Example:**
  ```dart
  Positioned(
    top: 5,
    right: 5,
    child: Icon(Icons.circle, color: Colors.green, size: 10), // Online indicator
  )
  ```

---

### 16. ListView
* **Purpose:** Renders a scrollable linear list of widgets.
* **Syntax:** `ListView(children: [])` or `ListView.builder()`
* **Important Properties:** `scrollDirection`, `reverse`, `shrinkWrap`, `physics`.
* **When to use:** Linear lists that may overflow the screen boundaries.
* **When NOT to use:** When you have a massive dataset (use `ListView.builder` for dynamic loading instead).
* **Common Mistakes:** Nesting list views without setting bounds (results in unbounded height crash).
* **Performance:** `ListView.builder` is highly efficient, dynamically building only visible items.
* **Simple Examples:**
  1. `ListView(children: [Text('Row 1'), Text('Row 2')])`
  2. `ListView.builder(itemCount: 100, itemBuilder: (ctx, idx) => Text('$idx'))`
* **BlindChess Example:**
  ```dart
  ListView.builder(
    itemCount: moveHistoryList.length,
    itemBuilder: (context, index) => ListTile(title: Text(moveHistoryList[index])),
  )
  ```

---

### 17. GridView
* **Purpose:** Renders a scrollable grid of widgets (2D layout).
* **Syntax:** `GridView.count(crossAxisCount: 2)` or `GridView.builder()`
* **Important Properties:** `crossAxisCount`, `mainAxisSpacing`, `crossAxisSpacing`, `childAspectRatio`.
* **When to use:** Multi-column grids (like photo galleries, menus, or a chess board!).
* **When NOT to use:** When you need simple one-dimensional scroll lists.
* **Common Mistakes:** Setting incorrect `childAspectRatio` parameters, leading to squished elements.
* **Performance:** Use `GridView.builder` for list rendering to keep frame rates high.
* **Simple Examples:**
  1. `GridView.count(crossAxisCount: 3, children: [Card(), Card(), Card()])`
  2. `GridView.builder(gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4), itemBuilder: ...)`
* **BlindChess Example:**
  ```dart
  GridView.builder(
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
    itemCount: 64,
    itemBuilder: (context, index) => ChessSquare(index: index),
  )
  ```

---

### 18. SingleChildScrollView
* **Purpose:** Wraps a single child widget and enables vertical or horizontal scrolling.
* **Syntax:** `SingleChildScrollView(child: ...)`
* **Important Properties:** `scrollDirection`, `physics`, `padding`.
* **When to use:** Standard views (forms, static pages) that might overflow on smaller devices or when the on-screen keyboard appears.
* **When NOT to use:** As a replacement for infinite list views (use `ListView.builder` instead).
* **Common Mistakes:** Nesting a scroll view inside an unconstrained parent column without setting bounds.
* **Performance:** Renders its entire child tree at once; do not load massive grids/lists inside it.
* **Simple Examples:**
  1. `SingleChildScrollView(child: Column(children: [A, B, C, D]))`
  2. `SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(...))`
* **BlindChess Example:**
  ```dart
  SingleChildScrollView(
    child: Column(children: [ChessBoard(), GameStatus(), ControlPanel()]),
  )
  ```

---

### 19. SafeArea
* **Purpose:** Automatically inserts padding around its child to avoid status bars, physical notches, and home indicator bars.
* **Syntax:** `SafeArea(child: ...)`
* **Important Properties:** `top`, `bottom`, `left`, `right`.
* **When to use:** As a structural parent layout wrapper on mobile applications.
* **When NOT to use:** When your background images need to cover the entire physical screen display.
* **Common Mistakes:** Nesting multiple SafeAreas, reducing available design surface dimensions.
* **Performance:** Extremely cheap constraint application.
* **Simple Examples:**
  1. `SafeArea(child: Text('Safe Content'))`
  2. `SafeArea(bottom: false, child: CustomFooter())`
* **BlindChess Example:**
  ```dart
  SafeArea(
    child: Scaffold(body: ChessGameScreen()),
  )
  ```

---

### 20. Card
* **Purpose:** A Material Design content container with rounded corners and a shadow.
* **Syntax:** `Card(elevation: 2, child: ...)`
* **Important Properties:** `elevation`, `color`, `shape`, `margin`.
* **When to use:** Organizing items (e.g. settings panels, action options).
* **When NOT to use:** When you need a flat container (use `Container` or `SizedBox` instead).
* **Common Mistakes:** Placing heavy margin padding elements on the Card itself, forcing child styling issues.
* **Performance:** Performs draw calculations for shadows. Keep draw density sensible.
* **Simple Examples:**
  1. `Card(child: Padding(padding: EdgeInsets.all(8), child: Text('Card contents')))`
  2. `Card(elevation: 8, shape: StadiumBorder(), child: ...)`
* **BlindChess Example:**
  ```dart
  Card(
    elevation: 3,
    child: ListTile(title: Text('White: Grandmaster')),
  )
  ```

---

### 21. ElevatedButton
* **Purpose:** A standard raised button with shadow and coloring feedback.
* **Syntax:** `ElevatedButton(onPressed: () {}, child: Text('Click'))`
* **Important Properties:** `onPressed`, `style` (`ButtonStyle`), `child`.
* **When to use:** Primary actions (e.g. "Save", "Submit", "Start Game").
* **When NOT to use:** For minor or secondary settings actions.
* **Common Mistakes:** Passing `null` to `onPressed` accidentally (disables the button).
* **Performance:** Fast drawing actions.
* **Simple Examples:**
  1. `ElevatedButton(onPressed: () => print('Click'), child: Text('Submit'))`
  2. `ElevatedButton.icon(onPressed: () {}, icon: Icon(Icons.add), label: Text('Add'))`
* **BlindChess Example:**
  ```dart
  ElevatedButton(
    onPressed: _startNewMatch,
    child: const Text('Start Match'),
  )
  ```

---

### 22. TextButton
* **Purpose:** A flat button without borders or shadows, used for secondary actions.
* **Syntax:** `TextButton(onPressed: () {}, child: Text('Click'))`
* **Important Properties:** `onPressed`, `style`, `child`.
* **When to use:** Secondary items in dialogs, navigation routes, or options blocks.
* **When NOT to use:** As the main focal call-to-action button on a screen.
* **Common Mistakes:** Placing it over colorful containers where the text color matches the background, making it invisible.
* **Performance:** Lightweight flat rendering.
* **Simple Examples:**
  1. `TextButton(onPressed: () {}, child: Text('Cancel'))`
  2. `TextButton(onPressed: () {}, child: Text('Learn More'))`
* **BlindChess Example:**
  ```dart
  TextButton(
    onPressed: _proposeDraw,
    child: const Text('Offer Draw'),
  )
  ```

---

### 23. OutlinedButton
* **Purpose:** A flat button containing a clear border outline.
* **Syntax:** `OutlinedButton(onPressed: () {}, child: Text('Click'))`
* **Important Properties:** `onPressed`, `style`, `child`.
* **When to use:** Secondary or fallback choices (e.g. "Export", "History").
* **When NOT to use:** As the primary button on a screen.
* **Common Mistakes:** Disabling states without checking border color consistency.
* **Performance:** Lightweight vector border drawing.
* **Simple Examples:**
  1. `OutlinedButton(onPressed: () {}, child: Text('Go Back'))`
  2. `OutlinedButton(onPressed: () {}, child: Text('Configure Settings'))`
* **BlindChess Example:**
  ```dart
  OutlinedButton(
    onPressed: _undoLastMove,
    child: const Text('Undo Move'),
  )
  ```

---

### 24. GestureDetector
* **Purpose:** An invisible utility widget that listens for touch gestures (tap, double tap, drag, zoom, long press).
* **Syntax:** `GestureDetector(onTap: () {}, child: ...)`
* **Important Properties:** `onTap`, `onLongPress`, `onDoubleTap`, `onPanUpdate` (dragging).
* **When to use:** Adding tap/drag interactions to custom layouts without showing a ripple effect.
* **When NOT to use:** When you need visual feedback (use `InkWell` instead).
* **Common Mistakes:** Forgetting to set `behavior: HitTestBehavior.opaque` on empty children, causing empty spaces to ignore tap gestures.
* **Performance:** Highly efficient listener.
* **Simple Examples:**
  1. `GestureDetector(onTap: () => print('Tapped'), child: Image.asset('hero.png'))`
  2. `GestureDetector(onDoubleTap: () {}, child: Container())`
* **BlindChess Example:**
  ```dart
  GestureDetector(
    onPanEnd: (details) => _handleSwipeGesture(details), // swipe to review history
    child: ChessBoardContainer(),
  )
  ```

---

### 25. InkWell
* **Purpose:** Wraps content to listen for click interactions while providing visual ripple effects.
* **Syntax:** `InkWell(onTap: () {}, child: ...)`
* **Important Properties:** `onTap`, `borderRadius`, `splashColor`, `highlightColor`.
* **When to use:** Standard buttons, list cards, or chessboard squares where clicking should trigger a ripple animation.
* **When NOT to use:** Inside complex scrolling elements where ripple calculation causes lag.
* **Common Mistakes:** Wrapping widgets that have solid background decorations, which covers and hides the ripple effect.
* **Performance:** Marginally heavier than `GestureDetector` due to the ripple animation.
* **Simple Examples:**
  1. `InkWell(onTap: () {}, child: Padding(padding: EdgeInsets.all(12), child: Text('Click')))`
  2. `InkWell(borderRadius: BorderRadius.circular(4), onTap: () => ...)`
* **BlindChess Example:**
  ```dart
  InkWell(
    onTap: () => _onSquareTapped(squareIndex),
    child: ChessPieceIcon(),
  )
  ```

---

## Comparison: Layout Controllers

| Widget | Multi-Child | Overflow Handling | Key Property |
| :--- | :--- | :--- | :--- |
| **`Column`** | Yes (vertical) | None (Overflow Warning) | `mainAxisAlignment` |
| **`Row`** | Yes (horizontal) | None (Overflow Warning) | `mainAxisAlignment` |
| **`ListView`** | Yes (linear) | Scrollable (No Overflow) | `physics`, `itemBuilder` |
| **`GridView`** | Yes (grid-2D) | Scrollable (No Overflow) | `crossAxisCount` |
| **`SingleChildScrollView`** | No (single-child) | Scrollable (No Overflow) | `scrollDirection` |

---

## Common Mistakes to Avoid

1. **Incorrect placement of `Expanded`/`Flexible`:**
   Placing `Expanded` outside a `Row`, `Column`, or `Flex` results in a crash.
2. **Nesting unconstrained lists:**
   Nesting a `ListView` directly inside another vertical scrollable widget without setting `shrinkWrap: true` and `physics: const NeverScrollableScrollPhysics()` causes unbounded height errors.
3. **Hardcoding container heights:**
   Avoid setting rigid heights on containers holding text; they will overflow on devices with larger font scale configurations. Use margins, padding, or `SizedBox` instead.

---

## Best Practices

* **Always use `const` on static children:** Instructs the renderer to reuse calculations, improving battery life and frame rates.
* **Keep layout structures flat:** Prefer `ListView.builder` or custom grids over deep column-in-row nesting to maintain smooth scrolling.
* **Utilize `SafeArea`:** Wrap the top-level layout in a `SafeArea` to prevent notches and taskbars from cutting off your headers and buttons.

---

## Day 3 Practice Exercises

Write down the answers on your practice sheet. Do not modify the application files.

1. **Text:** Write a `Text` widget displaying `"Checkmate!"` in bold red font, sized 24.
2. **Padding:** Wrap a `Text` widget with padding that adds 16.0 points of space *only* on the top side.
3. **SizedBox:** Use a `SizedBox` to create an empty horizontal gap of 12.0 points.
4. **Column Alignment:** Write the property configuration to center items vertically inside a `Column`.
5. **Row Alignment:** Set up a `Row` to align its children along the vertical center (CrossAxis).
6. **Expanded:** Set up a `Row` where the first child (a `Text`) fills all remaining horizontal space, and the second child (an `Icon`) is aligned to the right.
7. **Stack:** Write a code block overlaying a red notification badge at the top-right corner of a mailbox icon.
8. **Positioned:** Specify the coordinates inside a `Positioned` widget to anchor a badge exactly 5 points from the top and 5 points from the right bounds.
9. **ListView Builder:** Write the signature for a `ListView.builder` with an items count of `10`.
10. **GridView Count:** Write a `GridView.count` configuration creating a static grid with 8 columns.
11. **SingleChildScrollView:** Wrap a `Column` containing a form layout to prevent overflows when the system keyboard rises.
12. **SafeArea:** Configure a `SafeArea` that applies notch protection on the top side but ignores protection on the bottom side.
13. **Card Elevation:** Create a `Card` widget with an elevation factor of `6`.
14. **InkWell:** Write an `InkWell` click listener wrapper that prints `"Square clicked"` when tapped, with a border radius of `8`.
15. **GestureDetector:** Wrap an icon container to listen for double-tap gestures.
