# Day 21: Legal Move Highlighting Notes

Welcome to Day 21! Today, we completed two key milestones:
1. Switched the visual board positions fully over to our rules-enforcing **`ChessEngineService`**.
2. Implemented **legal move destination highlighting** utilizing the underlying `chess` engine.

---

## 1. How `legalDestinationsFrom` Works (Step-by-Step)

Our method in `ChessEngineService` computes destinations as follows:
1. **Coordinate Conversion**: We map the 0-indexed screen coordinate indexes `(row, col)` into algebraic chess coordinates (e.g. `(row 6, col 4)` $\rightarrow$ `"e2"`).
2. **Move Generation**: We query the chess rules engine by calling `_chess.moves({'square': 'e2', 'verbose': true})`. 
   - Specifying the `'square'` key restricts move generation to only this starting square.
   - Specifying `'verbose': true` tells the engine to return detailed maps representing each move.
3. **Parsing Destinations**: We iterate through the returned move maps and retrieve the `'to'` value (which holds algebraic coordinates of destination squares, e.g. `"e3"`, `"e4"`).
4. **Reverse Mapping**: We convert the destination strings back to standard 0-indexed coordinate record pairs `(targetRow, targetCol)`.
5. **Output**: We return a `List<(int row, int col)>` containing all valid destinations. If a square is empty, has no legal moves, or contains a piece of the player whose turn it is not (e.g. Black pieces at the start of the game), the engine returns an empty list, resulting in no highlights.

---

## 2. Respecting Flip-Perspective Transformations

When the player clicks the **"Flip Board"** button, the view rotates 180 degrees.
* **The Rules Engine**: Stays perspective-agnostic. The mathematical board coordinates (`e2`, `e4`) remain constant.
* **The UI Layer**: Dynamically projects indices. We map screen row and column loop indices into `actualRowIndex` and `actualColIndex` based on `isWhitePerspective`.
* **Highlights Rendering**: By comparing `actualRowIndex` and `actualColIndex` against our record list of `highlightedSquares`, the visual highlights are automatically repositioned to match the flipped pieces.

---

## 3. What is Intentionally NOT Done Yet (Making Moves)

Tapping a highlighted destination square does **not** move the piece yet.
* **Separation of Concerns**: In user interface design, it is best practice to separate *calculating potential actions* from *executing those actions*.
* **Validation**: By first ensuring our highlighting logic is 100% bug-free and that the coordinates map perfectly, we build a solid foundation before modifying the internal state of the rules engine. Moving pieces will be implemented on Day 22.

---

Congratulations on completing Day 21!
