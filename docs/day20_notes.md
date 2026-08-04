# Day 20: Chess Engine Integration & Adapter Notes

Welcome to Day 20! Today, we integrated the external **`chess` package (by davecom)** into our project and wired it up inside an **Adapter Service** to manage core rule validation and positions data.

---

## 1. What the `Chess` Class Provides

The `Chess` class from the `chess` package is a complete chess engine rules library. It manages:
* **Move legality**: Generating a list of all legal moves for a given position.
* **Game state flags**: Detecting if the game is in check, checkmate, stalemate, draw, or threefold repetition.
* **Special rules**: Hand-writing castling rights, promotion, and en passant validation.
* **FEN & PGN**: Reading from or exporting positions to standard text notations.

---

## 2. Our Adapter: Translating Piece Representations

In standard software design, we use the **Adapter Pattern** to convert the interface of one service into another interface that our client expects.

- **External Interface (`package:chess/chess.dart`)**:
  - Exposes pieces as a `Piece` object containing `PieceType` (constants like `PieceType.PAWN`) and `Color` (constants like `Color.WHITE`).
- **Our Domain Interface (`lib/models/chess_piece.dart`)**:
  - Expects a custom `ChessPiece` class containing our custom `PieceType` and `PieceColor` enums.

Our **`ChessEngineService`** class maps these two representations:
1. Translates 2D array row/column indexes into standard chess coordinate names (e.g. `row 0, col 4` $\rightarrow$ `"e8"`).
2. Reads the engine piece on that square.
3. Translates engine colors and types into our custom enum constants (`PieceColor.white`, `PieceType.king`).
4. Instantiates and returns a custom `ChessPiece` object.

---

## 3. What FEN Is and Why It's Useful

**FEN (Forsyth-Edwards Notation)** is a standard, single-line text string format describing the complete state of a chessboard.

A FEN string consists of 6 space-separated parts:
1. **Piece placement**: Layout of pieces rank-by-rank from 8 to 1 (e.g. `rnbqkbnr/pppppppp/...`).
2. **Active color**: `w` (White's turn) or `b` (Black's turn).
3. **Castling rights**: `K`, `Q`, `k`, `q` indicating who has castling privileges.
4. **En passant target**: Coordinate of the square that a pawn can capture en passant.
5. **Halfmove clock**: Number of halfmoves since the last capture or pawn advance (used for the 50-move draw rule).
6. **Fullmove number**: Counter incremented after Black moves.

Having a FEN representation is extremely useful because we can instantly reconstruct any complex board setup in a single line of text for tests, debugging, or load-game sessions.

---

## 4. Why We Verify Equivalence in Parallel First

In software development, swapping out a core data provider is a high-risk operation. If we immediately replaced our `Board` class with `ChessEngineService` in the UI rendering code, any minor index mapping error (e.g. mapping files backwards, rank offsets off by one) would result in a broken UI.

Instead, we follow the **Parallel Run** practice:
1. We keep our UI drawing from `Board` exactly as before.
2. We run the new `ChessEngineService` in the background.
3. We write a unit test to prove that they return identical pieces for all 64 squares at the starting position.
4. Once we prove equivalence, we can confidently swap the UI data source in Day 21, knowing the plumbing is correct.

---

Congratulations on completing Day 20! You have successfully mastered package integration, adapters, parallel testing, and FEN notations.
