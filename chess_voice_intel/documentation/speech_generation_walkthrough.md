# Speech Generation Walkthrough

This document provides a walkthrough of how the Speech Generation Engine works.

## 1. Quick Start

To generate speech samples for a chess board FEN:

```python
import chess
from speech_generator import SpeechGenerator

board_sample = {
    "fen": "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
    "category": "opening",
    "generationReason": "Starting position"
}

speech_samples = SpeechGenerator.generate_speech_samples(board_sample)
print(f"Generated {len(speech_samples)} speech samples.")
```

## 2. Interactive Verification

To manually check if a voice command resolves to a legal move:

```python
from speech_validator import SpeechValidator
import chess

board = chess.Board() # Start board
is_valid, reason, uci = SpeechValidator.validate_and_resolve(board, "knight from g1 to f3")
print("Is Valid:", is_valid)
print("UCI Move:", uci)
```
