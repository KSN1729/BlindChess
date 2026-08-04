import pytest
import chess
from speech_sample import SpeechSample
from speech_variations import generate_variations
from speech_validator import SpeechValidator
from speech_generator import SpeechGenerator

def test_speech_sample_creation():
    sample = SpeechSample(
        spokenText="knight to f3",
        canonicalMove="g1f3",
        SAN="Nf3",
        UCI="g1f3",
        category="opening",
        language="en",
        variationType="formal",
        metadata={"difficulty": "easy"},
        generationReason="test"
    )
    d = sample.to_dict()
    assert d["spokenText"] == "knight to f3"
    assert d["canonicalMove"] == "g1f3"

def test_validator_basic_resolving():
    board = chess.Board() # Starting board
    # Test valid move resolving
    is_valid, reason, uci = SpeechValidator.validate_and_resolve(board, "knight to f3")
    assert is_valid
    assert uci == "g1f3"

    # Test invalid piece mapping
    is_valid, reason, uci = SpeechValidator.validate_and_resolve(board, "queen to f3")
    assert not is_valid
    assert "does not match" in reason

    # Test invalid destination
    is_valid, reason, uci = SpeechValidator.validate_and_resolve(board, "pawn to e5")
    assert not is_valid

def test_castling_speech():
    board = chess.Board("r3k2r/8/8/8/8/8/8/R3K2R w Kkq - 0 1")
    move_kingside = chess.Move.from_uci("e1g1")
    vars_kingside = generate_variations(board, move_kingside, "O-O")
    
    # Castling variations must contain castle terms
    assert any("castle" in text for text, _ in vars_kingside)
    
    # Validate each variation maps to exact castling move
    for text, _ in vars_kingside:
        is_valid, reason, uci = SpeechValidator.validate_and_resolve(board, text)
        assert is_valid
        assert uci == "e1g1"

def test_promotion_speech():
    board = chess.Board("8/P7/8/k7/8/K7/8/8 w - - 0 1")
    move_promo = chess.Move.from_uci("a7a8q")
    vars_promo = generate_variations(board, move_promo, "a8=Q")
    
    assert any("queen" in text for text, _ in vars_promo)
    
    for text, _ in vars_promo:
        is_valid, reason, uci = SpeechValidator.validate_and_resolve(board, text)
        assert is_valid, f"Failed for {text}: {reason}"
        assert uci == "a7a8q"

def test_en_passant_speech():
    board = chess.Board("rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 2")
    move_ep = chess.Move.from_uci("e5d6")
    vars_ep = generate_variations(board, move_ep, "exd6")
    
    assert any("en passant" in text for text, _ in vars_ep)
    
    for text, _ in vars_ep:
        is_valid, reason, uci = SpeechValidator.validate_and_resolve(board, text)
        assert is_valid, f"Failed for {text}: {reason}"
        assert uci == "e5d6"

def test_check_speech():
    board = chess.Board("3r2k1/1p3ppp/pq6/8/8/8/PPP2PPP/3R2K1 w - - 0 1")
    move_check = chess.Move.from_uci("d1d8")
    vars_check = generate_variations(board, move_check, "Rxd8+")
    
    assert any("check" in text for text, _ in vars_check)
    
    for text, _ in vars_check:
        is_valid, reason, uci = SpeechValidator.validate_and_resolve(board, text)
        assert is_valid, f"Failed for {text}: {reason}"
        assert uci == "d1d8"

def test_checkmate_speech():
    board = chess.Board("6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1")
    move_mate = chess.Move.from_uci("d1d8")
    vars_mate = generate_variations(board, move_mate, "Rd8#")
    
    assert any("mate" in text or "checkmate" in text for text, _ in vars_mate)
    
    for text, _ in vars_mate:
        is_valid, reason, uci = SpeechValidator.validate_and_resolve(board, text)
        assert is_valid, f"Failed for {text}: {reason}"
        assert uci == "d1d8"

def test_disambiguation_speech():
    board = chess.Board("6k1/8/8/8/8/8/4K3/R6R w - - 0 1")
    # Rook on a1 to d1
    move_a = chess.Move.from_uci("a1d1")
    vars_a = generate_variations(board, move_a, "Rad1")
    
    # Must specify 'from a' or 'on the a file'
    assert any("from a" in text or "a rook" in text for text, _ in vars_a)
    
    for text, _ in vars_a:
        is_valid, reason, uci = SpeechValidator.validate_and_resolve(board, text)
        assert is_valid, f"Failed for {text}: {reason}"
        assert uci == "a1d1"

def test_generator_orchestration():
    board_sample = {
        "fen": "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
        "category": "opening",
        "generationReason": "test starting board"
    }
    
    samples = SpeechGenerator.generate_speech_samples(board_sample)
    assert len(samples) > 0
    
    # Assert fields are correct
    for s in samples:
        assert "spokenText" in s
        assert "canonicalMove" in s
        assert "variationType" in s
        assert s["language"] == "en"
        assert s["category"] in ["opening", "capture", "castling", "en_passant", "promotion", "check"]
