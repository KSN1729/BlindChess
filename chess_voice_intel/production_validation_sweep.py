import time
import json
import psutil
import os
import math
import re
import random
import hashlib
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
    words = []
    for text in text_list:
        words.extend(text.lower().split())
    if not words:
        return 0.0
    unique_words = set(words)
    return len(unique_words) / len(words)

def run_comprehensive_robustness_test():
    """
    Exhaustive stress-testing of SpeechValidator under 15 distinct ASR and linguistic perturbations.
    """
    board = chess.Board()
    board_dis = chess.Board("6k1/8/8/8/8/8/4K3/R6R w - - 0 1")
    board_one_rook = chess.Board("6k1/8/8/8/8/8/4K3/7R w - - 0 1")
    
    test_cases = [
        # 1. Capitalization
        ("KNIGHT TO F3", "g1f3", "capitalization", board),
        # 2. Punctuation removal
        ("knight to f3?!", "g1f3", "punctuation", board),
        ("knight to f3.", "g1f3", "punctuation", board),
        # 3. Multiple spaces
        ("knight    to   f3", "g1f3", "spacing", board),
        # 4. Hyphens
        ("knight-to-f3", "g1f3", "hyphens", board),
        # 5. Coordinate spacing
        ("knight to f 3", "g1f3", "coordinate_spacing", board),
        # 6. Coordinate punctuation
        ("knight to f-3", "g1f3", "coordinate_punctuation", board),
        # 7. ASR spelling mistakes
        ("night to f3", "g1f3", "asr_spelling", board),
        ("see three", "c2c3", "asr_spelling", board), # pawn to c3
        # 8. Common pronunciation variants
        ("horse to f3", "g1f3", "pronunciation_variants", board),
        # 9. Phonetic alphabet
        ("knight to foxtrot three", "g1f3", "phonetic", board),
        # 10. Piece synonyms
        ("castle to d1", "h1d1", "piece_synonyms", board_one_rook), # rook is castle
        # 11. Spoken numbers
        ("knight from one to f3", "g1f3", "spoken_numbers", board),
        # 12. Coordinate words
        ("knight to charlie three", "b1c3", "coordinate_words", board),
        # 13. Whitespace corruption
        ("   knight to f3   ", "g1f3", "whitespace_corruption", board),
        # 14. Mixed capitalization
        ("KnIgHt To F3", "g1f3", "mixed_capitalization", board),
        # 15. Noise-like token insertion
        ("uh knight to f3 please", "g1f3", "noise_insertion", board)
    ]
    
    success_count = 0
    failures = []
    
    for phrase, expected_uci, category, active_board in test_cases:
        is_valid, reason, resolved_uci = SpeechValidator.validate_and_resolve(active_board, phrase)
        if is_valid and resolved_uci == expected_uci:
            success_count += 1
        else:
            failures.append((phrase, category, reason))
            
    recovery_rate = success_count / len(test_cases)
    return recovery_rate, failures

def run_master_production_validation():
    print("==================================================")
    print("STARTING MASTER PRODUCTION VALIDATION SWEEP")
    print("==================================================")
    
    process = psutil.Process(os.getpid())
    mem_start = process.memory_info().rss / (1024 * 1024)
    
    t_start = time.perf_counter()
    
    styles_data = {
        "formal": [], "conversational": [], "minimal": [], "natural": [], "verbose": []
    }
    categories_count = Counter()
    
    total_moves_processed = 0
    total_samples = 0
    total_rejected = 0
    all_phrases = []
    
    board_count = 0
    latencies = []
    
    while total_moves_processed < 100000:
        cat = CATEGORIES[board_count % len(CATEGORIES)]
        board_sample = BoardGenerator.generate_sample(cat)
        
        fen = board_sample["fen"]
        board = chess.Board(fen)
        legal_move_count = board.legal_moves.count()
        if legal_move_count == 0:
            continue
            
        t0 = time.perf_counter()
        samples = SpeechGenerator.generate_speech_samples(board_sample)
        t1 = time.perf_counter()
        
        latencies.append((t1 - t0) * 1000.0) # ms
        
        for s in samples:
            spoken = s["spokenText"]
            style = s["variationType"]
            move_cat = s["category"]
            
            # Audit sanity checks
            if not spoken or not s["canonicalMove"] or not move_cat or not style or not s["metadata"]:
                total_rejected += 1
                continue
                
            # Unambiguity verify
            is_valid, reason, resolved_uci = SpeechValidator.validate_and_resolve(board, spoken)
            if not is_valid or resolved_uci != s["canonicalMove"]:
                total_rejected += 1
                continue
                
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
    mem_end = process.memory_info().rss / (1024 * 1024)
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
        
    robustness_rate, failures = run_comprehensive_robustness_test()
    
    # Print out robustness failures if any
    for fail_phrase, fail_cat, fail_reason in failures:
         print(f"Robustness Fail: '{fail_phrase}' ({fail_cat}) -> {fail_reason}")
         
    avg_latency = sum(latencies) / len(latencies)
    min_latency = min(latencies)
    max_latency = max(latencies)
    
    unique_phrases_total = len(set(all_phrases))
    duplicate_rate_total = ((total_samples - unique_phrases_total) / total_samples) * 100.0 if total_samples > 0 else 0.0
    
    throughput_moves_sec = total_moves_processed / total_time
    throughput_samples_sec = total_samples / total_time
    
    report = {
        "boards_processed": board_count,
        "total_moves_audited": total_moves_processed,
        "total_samples_generated": total_samples,
        "total_rejected": total_rejected,
        "average_phrases_per_move": total_samples / total_moves_processed,
        "overall_vocabulary_entropy_bits": calculate_entropy(all_phrases),
        "overall_lexical_diversity": calculate_lexical_diversity(all_phrases),
        "overall_unique_phrases": unique_phrases_total,
        "overall_duplicate_rate_percent": duplicate_rate_total,
        "style_diversity": style_report,
        "category_distribution": dict(categories_count),
        "nlp_robustness_recovery_rate": robustness_rate,
        "performance": {
            "total_audit_time_seconds": total_time,
            "average_latency_per_board_ms": avg_latency,
            "min_latency_ms": min_latency,
            "max_latency_ms": max_latency,
            "throughput_moves_per_second": throughput_moves_sec,
            "throughput_samples_per_second": throughput_samples_sec
        },
        "memory": {
            "start_mb": mem_start,
            "end_mb": mem_end,
            "delta_mb": mem_end - mem_start
        }
    }
    
    with open("production_validation_results.json", "w") as f:
        json.dump(report, f, indent=2)
    print("Saved results to production_validation_results.json")
    
    print("\n==================================================")
    print("MASTER AUDIT COMPLETED")
    print("==================================================")
    print(f"Total Moves Processed:     {total_moves_processed}")
    print(f"Total Samples Generated:   {total_samples}")
    print(f"Validation Success Rate:   {((total_samples) / (total_samples + total_rejected)) * 100.0:.3f}%")
    print(f"ASR Robustness Recovery:   {robustness_rate * 100.0:.2f}%")
    print(f"Average Board Latency:     {avg_latency:.3f} ms")
    print(f"Memory Footprint Delta:    {mem_end - mem_start:.2f} MB")
    print("==================================================")

if __name__ == "__main__":
    run_master_production_validation()
