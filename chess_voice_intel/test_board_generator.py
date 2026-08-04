import pytest
import chess
import time
from board_generator import BoardGenerator

CATEGORIES = [
    "opening",
    "middlegame",
    "endgame",
    "promotion",
    "castling",
    "en_passant",
    "check",
    "checkmate_in_one",
    "ambiguous_rook",
    "ambiguous_bishop",
    "ambiguous_knight"
]

def test_generic_sample_fields():
    """Verify that all samples conform to the BoardSample schema."""
    for category in CATEGORIES:
        sample = BoardGenerator.generate_sample(category)
        
        assert "fen" in sample
        assert "sideToMove" in sample
        assert "legalMoves" in sample
        assert "sanMoves" in sample
        assert "category" in sample
        assert "metadata" in sample
        assert "generationReason" in sample
        
        # Verify FEN legality
        board = chess.Board(sample["fen"])
        assert board.is_valid()
        assert len(sample["legalMoves"]) > 0
        assert sample["sideToMove"] in ["white", "black"]
        
        # Metadata checks
        metadata = sample["metadata"]
        assert "pieceCount" in metadata
        assert "hasCastlingRights" in metadata
        assert "isCheck" in metadata
        assert metadata["pieceCount"] == len(board.piece_map())
        assert metadata["isCheck"] == board.is_check()

def test_opening_properties():
    sample = BoardGenerator.generate_sample("opening")
    board = chess.Board(sample["fen"])
    # Openings typically have full starting or near-starting piece sets
    assert len(board.piece_map()) >= 28

def test_endgame_properties():
    sample = BoardGenerator.generate_sample("endgame")
    board = chess.Board(sample["fen"])
    assert len(board.piece_map()) <= 8

def test_promotion_properties():
    sample = BoardGenerator.generate_sample("promotion")
    board = chess.Board(sample["fen"])
    # Verify a legal promotion move exists
    has_promotion = any(m.promotion is not None for m in board.legal_moves)
    assert has_promotion, "No promotion moves found in promotion sample!"

def test_castling_properties():
    sample = BoardGenerator.generate_sample("castling")
    board = chess.Board(sample["fen"])
    # Verify a legal castling move exists
    has_castling = any(board.is_castling(m) for m in board.legal_moves)
    assert has_castling, "No castling moves found in castling sample!"

def test_en_passant_properties():
    sample = BoardGenerator.generate_sample("en_passant")
    board = chess.Board(sample["fen"])
    # Verify a legal en-passant move exists
    has_ep = any(board.is_en_passant(m) for m in board.legal_moves)
    assert has_ep, "No en-passant moves found in en_passant sample!"

def test_check_properties():
    sample = BoardGenerator.generate_sample("check")
    board = chess.Board(sample["fen"])
    assert board.is_check()

def test_checkmate_in_one_properties():
    sample = BoardGenerator.generate_sample("checkmate_in_one")
    board = chess.Board(sample["fen"])
    
    # Helper to check if a move delivers checkmate
    def delivers_mate(b, m):
        temp = b.copy()
        temp.push(m)
        return temp.is_checkmate()
        
    has_mate_in_one = any(delivers_mate(board, m) for m in board.legal_moves)
    assert has_mate_in_one, "No checkmate-in-one move found!"

def test_ambiguous_rook_properties():
    sample = BoardGenerator.generate_sample("ambiguous_rook")
    board = chess.Board(sample["fen"])
    
    # Verify target square has multiple rook moves targeting it
    target_counts = {}
    for m in board.legal_moves:
        p = board.piece_at(m.from_square)
        if p and p.piece_type == chess.ROOK:
            target_counts[m.to_square] = target_counts.get(m.to_square, 0) + 1
            
    has_ambiguity = any(count > 1 for count in target_counts.values())
    assert has_ambiguity, "No ambiguous rook moves found!"

def test_ambiguous_bishop_properties():
    sample = BoardGenerator.generate_sample("ambiguous_bishop")
    board = chess.Board(sample["fen"])
    
    target_counts = {}
    for m in board.legal_moves:
        p = board.piece_at(m.from_square)
        if p and p.piece_type == chess.BISHOP:
            target_counts[m.to_square] = target_counts.get(m.to_square, 0) + 1
            
    has_ambiguity = any(count > 1 for count in target_counts.values())
    assert has_ambiguity, "No ambiguous bishop moves found!"

def test_ambiguous_knight_properties():
    sample = BoardGenerator.generate_sample("ambiguous_knight")
    board = chess.Board(sample["fen"])
    
    target_counts = {}
    for m in board.legal_moves:
        p = board.piece_at(m.from_square)
        if p and p.piece_type == chess.KNIGHT:
            target_counts[m.to_square] = target_counts.get(m.to_square, 0) + 1
            
    has_ambiguity = any(count > 1 for count in target_counts.values())
    assert has_ambiguity, "No ambiguous knight moves found!"

def test_generation_latency():
    """Verify that average generation time is well under the 50ms requirement."""
    start_time = time.perf_counter()
    count = 100
    for _ in range(count):
        cat = CATEGORIES[_ % len(CATEGORIES)]
        BoardGenerator.generate_sample(cat)
    elapsed = time.perf_counter() - start_time
    avg_ms = (elapsed / count) * 1000.0
    print(f"\nAverage generation latency: {avg_ms:.3f} ms")
    assert avg_ms < 50.0, f"Average latency too high: {avg_ms:.3f} ms"
