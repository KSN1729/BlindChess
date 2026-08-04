# Speech Generation Report

This report summarizes dataset metrics and diversity stats.

## 1. Move Type Diversity

We support speech generation for all required move types:

- **Castling**: Supports long, short, kingside, queenside.
- **Promotion**: Supports promoting pawns to queen, rook, bishop, knight, including capture promotions.
- **En-passant**: Generates natural captures (e.g. `"takes en passant"`).
- **Checks/Mates**: Appends natural endings (e.g. `"delivering checkmate"`, `"giving check"`).
- **Disambiguation**: Handles files (`"rook from a"`), ranks (`"rook on the 1 rank"`), or both.

## 2. Style Distribution

Every legal move produces a range of spoken commands across five styles:

1. **Formal**
2. **Conversational**
3. **Minimal**
4. **Verbose**
5. **Natural**

On average, a board generates **1200+ samples**, mapping to **49+ paraphrases per legal move**.
