import time
import json
import psutil
import os
import math
import re
import random
import chess
from collections import Counter
from board_generator import BoardGenerator
from speech_generator import SpeechGenerator
from speech_validator import SpeechValidator

CATEGORIES = [
    "opening", "middlegame", "endgame", "promotion", "castling",
    "en_passant", "check", "checkmate_in_one", "ambiguous_rook",
    "ambiguous_bishop", "ambiguous_knight"
]

def calculate_entropy(text_list):
    """Calculates Shannon entropy of the vocabulary in a list of texts."""
    words = []
    for text in text_list:
        words.extend(text.lower().split())
    if not words:
        return 0.0
    counter = Counter(words)
    total_words = len(words)
    entropy = -sum((count / total_words) * math.log2(count / total_words) for count in counter.values())
    return entropy

def calculate_lexical_diversity(text_list):
    """Calculates Type-Token Ratio (TTR) as a measure of lexical diversity."""
    words = []
    for text in text_list:
        words.extend(text.lower().split())
    if not words:
        return 0.0
    unique_words = set(words)
    return len(unique_words) / len(words)

def run_nlp_robustness_tests():
    """Stress-tests the SpeechValidator using various linguistic perturbations."""
    # Test cases: (input_phrase, expected_uci, category)
    # Using starting board for convenience
    board = chess.Board()
    test_cases = [
        # Capitalization
        ("KNIGHT TO F3", "g1f3", "capitalization"),
        ("Knight To F3", "g1f3", "capitalization"),
        # Punctuation
        ("knight to f3?!", "g1f3", "punctuation"),
        ("knight to f3.", "g1f3", "punctuation"),
        # Spacing
        ("knight   to    f3", "g1f3", "spacing"),
        # Synonyms
        ("horse to f3", "g1f3", "synonyms"),
        ("horse f3", "g1f3", "synonyms"),
        # Phonetic spelling
        ("knight to foxtrot three", "g1f3", "phonetic"),
        ("foxtrot three", "f2f3", "phonetic"),  # pawn
        # Spoken numbers
        ("knight from one to f3", "g1f3", "spoken_numbers"),
        # Case with disambiguation
        # Setup board with two rooks on a1 and h1
        ("rook from alpha to d1", "a1d1", "phonetic_disambiguation")
    ]
    
    # Custom board for disambiguation tests
    board_dis = chess.Board("6k1/8/8/8/8/8/4K3/R6R w - - 0 1")
    
    success_count = 0
    total_count = len(test_cases)
    
    for phrase, expected_uci, cat in test_cases:
        active_board = board_dis if "disambiguation" in cat else board
        is_valid, reason, resolved_uci = SpeechValidator.validate_and_resolve(active_board, phrase)
        if is_valid and resolved_uci == expected_uci:
            success_count += 1
        else:
            print(f"Failed Robustness: '{phrase}' expected {expected_uci}, got {resolved_uci} (Reason: {reason})")
            
    return success_count / total_count if total_count > 0 else 0.0

def run_diversity_audit():
    print("==================================================")
    print("STARTING DATASET QUALITY & DIVERSITY AUDIT")
    print("==================================================")
    
    t_start = time.perf_counter()
    
    # Trackers for style diversity
    styles_data = {
        "formal": [], "conversational": [], "minimal": [], "natural": [], "verbose": []
    }
    
    # Category trackers
    categories_count = Counter()
    total_moves_processed = 0
    total_samples = 0
    all_phrases = []
    
    board_count = 0
    
    # Run loop to get 100,000 legal moves
    while total_moves_processed < 100000:
        cat = CATEGORIES[board_count % len(CATEGORIES)]
        board_sample = BoardGenerator.generate_sample(cat)
        
        fen = board_sample["fen"]
        board = chess.Board(fen)
        legal_move_count = board.legal_moves.count()
        if legal_move_count == 0:
            continue
            
        samples = SpeechGenerator.generate_speech_samples(board_sample)
        
        for s in samples:
            spoken = s["spokenText"]
            style = s["variationType"]
            move_cat = s["category"]
            
            if style in styles_data:
                styles_data[style].append(spoken)
            all_phrases.append(spoken)
            categories_count[move_cat] += 1
            total_samples += 1
            
        total_moves_processed += legal_move_count
        board_count += 1
        
        if board_count % 500 == 0:
            print(f"Audited {total_moves_processed} legal moves...")
            
    t_end = time.perf_counter()
    total_time = t_end - t_start
    
    # Calculate style metrics
    style_report = {}
    for style, texts in styles_data.items():
        uniq = len(set(texts))
        total = len(texts)
        dup_rate = ((total - uniq) / total) * 100.0 if total > 0 else 0.0
        entropy = calculate_entropy(texts)
        lexical = calculate_lexical_diversity(texts)
        avg_len = sum(len(t.split()) for t in texts) / total if total > 0 else 0.0
        
        style_report[style] = {
            "total_phrases": total,
            "unique_phrases": uniq,
            "duplicate_rate_percent": dup_rate,
            "vocabulary_entropy_bits": entropy,
            "lexical_diversity": lexical,
            "avg_phrase_length_words": avg_len
        }
        
    # NLP Robustness recovery rate
    robustness_rate = run_nlp_robustness_tests()
    
    # Compile full report
    full_report = {
        "boards_processed": board_count,
        "total_moves_audited": total_moves_processed,
        "total_samples_generated": total_samples,
        "average_phrases_per_move": total_samples / total_moves_processed,
        "overall_lexical_diversity": calculate_lexical_diversity(all_phrases),
        "overall_vocabulary_entropy_bits": calculate_entropy(all_phrases),
        "style_diversity": style_report,
        "category_distribution": dict(categories_count),
        "nlp_robustness_recovery_rate": robustness_rate,
        "performance": {
            "total_audit_time_seconds": total_time,
            "throughput_samples_per_second": total_samples / total_time
        }
    }
    
    print("\n==================================================")
    print("AUDIT RESULTS SUMMARY")
    print("==================================================")
    print(f"Total Moves Audited:       {total_moves_processed}")
    print(f"Total Samples Generated:   {total_samples}")
    print(f"Overall Lexical Diversity: {full_report['overall_lexical_diversity']:.4f}")
    print(f"ASR Robustness Recovery:   {robustness_rate * 100.0:.2f}%")
    print("==================================================")
    
    with open("speech_audit_diversity_results.json", "w") as f:
        json.dump(full_report, f, indent=2)
    print("Saved audit report to speech_audit_diversity_results.json")

if __name__ == "__main__":
    run_diversity_audit()
