import time
import json
import psutil
import os
import hashlib
import random
import chess
from board_generator import BoardGenerator
from speech_generator import SpeechGenerator
from speech_validator import SpeechValidator

CATEGORIES = [
    "opening", "middlegame", "endgame", "promotion", "castling",
    "en_passant", "check", "checkmate_in_one", "ambiguous_rook",
    "ambiguous_bishop", "ambiguous_knight"
]

def get_memory_usage():
    process = psutil.Process(os.getpid())
    return process.memory_info().rss / (1024 * 1024) # MB

def run_large_scale_test():
    print("==================================================")
    print("STARTING 100,000 LEGAL MOVES SPEECH SWEEP & BENCHMARK")
    print("==================================================")
    
    mem_start = get_memory_usage()
    t_start = time.perf_counter()
    
    total_moves_processed = 0
    total_samples_generated = 0
    total_rejected = 0
    rejection_reasons = {}
    
    # Store hashes of spokenText to compute unique/duplicate count with low memory footprint
    seen_hashes = set()
    
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
        
        # Verify and audit every generated sample
        for s in samples:
            spoken = s.get("spokenText", "")
            canonical = s.get("canonicalMove", "")
            scat = s.get("category", "")
            style = s.get("variationType", "")
            meta = s.get("metadata", {})
            
            # Check basic structure
            if not spoken or not canonical or not scat or not style or not meta:
                total_rejected += 1
                reason = "missing_fields"
                rejection_reasons[reason] = rejection_reasons.get(reason, 0) + 1
                continue
                
            # Run validator check
            is_valid, reason, resolved_uci = SpeechValidator.validate_and_resolve(board, spoken)
            if not is_valid:
                total_rejected += 1
                rejection_reasons[reason] = rejection_reasons.get(reason, 0) + 1
                continue
            elif resolved_uci != canonical:
                total_rejected += 1
                reason = "resolved_uci_mismatch"
                rejection_reasons[reason] = rejection_reasons.get(reason, 0) + 1
                continue
                
            # Add to uniqueness tracker
            h = hashlib.md5(spoken.encode("utf-8")).digest()
            seen_hashes.add(h)
            total_samples_generated += 1
            
        total_moves_processed += legal_move_count
        board_count += 1
        
        if board_count % 500 == 0:
            print(f"Processed {board_count} boards ({total_moves_processed} legal moves)...")
            
    t_end = time.perf_counter()
    mem_end = get_memory_usage()
    
    total_time = t_end - t_start
    avg_latency = sum(latencies) / len(latencies)
    min_latency = min(latencies)
    max_latency = max(latencies)
    
    unique_phrases = len(seen_hashes)
    duplicate_phrases = total_samples_generated - unique_phrases
    dup_rate = (duplicate_phrases / total_samples_generated) * 100.0 if total_samples_generated > 0 else 0.0
    
    throughput_moves_sec = total_moves_processed / total_time
    throughput_samples_sec = total_samples_generated / total_time
    
    report = {
        "boards_processed": board_count,
        "total_moves_processed": total_moves_processed,
        "total_samples_generated": total_samples_generated,
        "total_rejected": total_rejected,
        "rejection_reasons": rejection_reasons,
        "unique_phrases": unique_phrases,
        "duplicate_phrases": duplicate_phrases,
        "duplicate_rate_percent": dup_rate,
        "avg_phrases_per_move": total_samples_generated / total_moves_processed,
        "validation_success_rate_percent": ((total_samples_generated) / (total_samples_generated + total_rejected)) * 100.0,
        "latency_stats": {
            "avg_ms": avg_latency,
            "min_ms": min_latency,
            "max_ms": max_latency
        },
        "throughput": {
            "moves_per_second": throughput_moves_sec,
            "samples_per_second": throughput_samples_sec
        },
        "memory": {
            "start_mb": mem_start,
            "end_mb": mem_end,
            "delta_mb": mem_end - mem_start
        }
    }
    
    print("\n==================================================")
    print("SPEECH SWEEP RESULTS SUMMARY")
    print("==================================================")
    print(f"Total Boards Processed:    {board_count}")
    print(f"Total Legal Moves Audited: {total_moves_processed}")
    print(f"Total Samples Generated:   {total_samples_generated}")
    print(f"Validation Success Rate:   {report['validation_success_rate_percent']:.3f}%")
    print(f"Unique Phrases Count:      {unique_phrases}")
    print(f"Duplicate Rate:            {dup_rate:.2f}%")
    print(f"Avg Phrases per Move:      {report['avg_phrases_per_move']:.2f}")
    print(f"Average Latency per Board: {avg_latency:.3f} ms")
    print(f"Throughput (Moves/Sec):    {throughput_moves_sec:.1f}")
    print(f"Throughput (Samples/Sec):  {throughput_samples_sec:.1f}")
    print(f"Memory Footprint Delta:    {mem_end - mem_start:.2f} MB")
    print("==================================================")
    
    with open("large_scale_speech_results.json", "w") as f:
        json.dump(report, f, indent=2)
    print("Saved results to large_scale_speech_results.json")

if __name__ == "__main__":
    run_large_scale_test()
