import pytest
import chess
import random
import re
from board_generator import BoardGenerator
from speech_generator import SpeechGenerator
from speech_validator import SpeechValidator

CATEGORIES = [
    "opening", "middlegame", "endgame", "promotion", "castling",
    "en_passant", "check", "checkmate_in_one", "ambiguous_rook",
    "ambiguous_bishop", "ambiguous_knight"
]

def test_end_to_end_pipeline():
    """
    Verifies that the entire pipeline flows from BoardGenerator -> SpeechGenerator -> SpeechValidator
    successfully across all categories.
    """
    for cat in CATEGORIES:
        # 1. Generate Board Sample
        sample = BoardGenerator.generate_sample(cat)
        assert sample["fen"] is not None
        
        board = chess.Board(sample["fen"])
        
        # 2. Generate Speech Samples
        speech_samples = SpeechGenerator.generate_speech_samples(sample)
        assert len(speech_samples) > 0, f"No speech samples generated for category {cat}"
        
        # 3. Validate Every Single Sample
        for s in speech_samples:
            spoken = s["spokenText"]
            canonical = s["canonicalMove"]
            san = s["SAN"]
            uci = s["UCI"]
            category = s["category"]
            style = s["variationType"]
            meta = s["metadata"]
            
            # Assert schema preservation
            assert spoken
            assert canonical == uci
            assert san
            assert category
            assert style
            assert meta
            assert meta["style"] == style
            assert meta["moveCategory"] == category
            
            # Semantic Validation
            is_valid, reason, resolved_uci = SpeechValidator.validate_and_resolve(board, spoken)
            assert is_valid, f"Validation failed for '{spoken}' in category {cat}: {reason}"
            assert resolved_uci == uci, f"UCI mismatch: expected {uci}, got {resolved_uci} for '{spoken}'"

def test_randomized_fuzzing_robustness():
    """
    Property-based fuzzing testing: feeds highly perturbed voice commands into SpeechValidator
    and asserts zero crashes, zero false acceptances, and correct resolution.
    """
    board = chess.Board() # Standard starting position
    base_phrase = "knight to f3"
    expected_uci = "g1f3"
    
    # Homophones mapping for fuzzing
    homophones = {
        "knight": ["knight", "night", "horse", "the horse", "my knight"],
        "to": ["to", "goes to", "play to", "move to"],
        "f3": ["f3", "f 3", "f-3", "foxtrot three", "foxtrot 3", "foxtrot-three"]
    }
    
    noise_words = ["uh", "um", "please", "let's", "can you", "go ahead", "and"]
    punctuations = [".", "?", "!", ",", "", "?!"]
    
    for _ in range(500):
        # 1. Select random synonyms/homophones
        p_knight = random.choice(homophones["knight"])
        p_to = random.choice(homophones["to"])
        p_f3 = random.choice(homophones["f3"])
        
        # Assemble base
        parts = [p_knight, p_to, p_f3]
        
        # 2. Inject random noise words
        if random.random() < 0.4:
            parts.insert(0, random.choice(noise_words))
        if random.random() < 0.4:
            parts.append(random.choice(noise_words))
            
        text = " ".join(parts)
        
        # 3. Random capitalization & mixed case
        if random.random() < 0.3:
            text = text.upper()
        elif random.random() < 0.3:
            # Mixed capitalization
            text = "".join(c.upper() if random.random() < 0.5 else c.lower() for c in text)
            
        # 4. Random punctuation
        text += random.choice(punctuations)
        
        # 5. Multiple spacing
        if random.random() < 0.3:
            text = re.sub(r"\s+", " " * random.randint(2, 5), text)
            
        # Execute validator
        try:
            is_valid, reason, resolved_uci = SpeechValidator.validate_and_resolve(board, text)
            if is_valid:
                assert resolved_uci == expected_uci, f"False acceptance: resolved '{text}' to {resolved_uci} instead of {expected_uci}"
        except Exception as e:
            pytest.fail(f"SpeechValidator crashed on fuzzed input '{text}' with exception: {e}")
