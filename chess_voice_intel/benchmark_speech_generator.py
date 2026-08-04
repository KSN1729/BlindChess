import time
import json
import psutil
import os
import random
from board_generator import BoardGenerator
from speech_generator import SpeechGenerator

CATEGORIES = [
    "opening", "middlegame", "endgame", "promotion", "castling",
    "en_passant", "check", "checkmate_in_one", "ambiguous_rook",
    "ambiguous_bishop", "ambiguous_knight"
]

def get_memory_usage():
    process = psutil.Process(os.getpid())
    return process.memory_info().rss / (1024 * 1024) # MB

def run_benchmarks():
    print("==================================================")
    print("STARTING SPEECH GENERATION LATENCY BENCHMARK SWEEP")
    print("==================================================")
    
    # Pre-generate 100 board samples to avoid mixing board generation latency with speech latency
    board_samples = []
    for i in range(100):
        cat = CATEGORIES[i % len(CATEGORIES)]
        sample = BoardGenerator.generate_sample(cat)
        board_samples.append(sample)
        
    mem_before = get_memory_usage()
    latencies = []
    total_samples = 0
    total_moves = 0
    
    t_start = time.perf_counter()
    for sample in board_samples:
        t0 = time.perf_counter()
        samples = SpeechGenerator.generate_speech_samples(sample)
        t1 = time.perf_counter()
        
        latencies.append((t1 - t0) * 1000.0) # ms
        total_samples += len(samples)
        # Deduce move count by looking at unique canonicalMove values in the samples list
        unique_moves = len(set(s["canonicalMove"] for s in samples))
        total_moves += unique_moves
        
    t_end = time.perf_counter()
    mem_after = get_memory_usage()
    
    avg_latency = sum(latencies) / len(latencies)
    min_latency = min(latencies)
    max_latency = max(latencies)
    
    avg_paraphrases = (total_samples / total_moves) if total_moves > 0 else 0.0
    samples_per_board = total_samples / len(board_samples)
    
    # Verify determinism: run SpeechGenerator twice on the same board with fixed random seed
    random.seed(42)
    run1 = SpeechGenerator.generate_speech_samples(board_samples[0])
    random.seed(42)
    run2 = SpeechGenerator.generate_speech_samples(board_samples[0])
    
    is_deterministic = (run1 == run2)
    
    summary = {
        "average_latency_ms": avg_latency,
        "min_latency_ms": min_latency,
        "max_latency_ms": max_latency,
        "memory_usage_before_mb": mem_before,
        "memory_usage_after_mb": mem_after,
        "memory_delta_mb": mem_after - mem_before,
        "avg_samples_per_board": samples_per_board,
        "avg_paraphrases_per_move": avg_paraphrases,
        "is_deterministic": is_deterministic
    }
    
    print(f"Average Latency:          {avg_latency:.3f} ms (Target < 10 ms)")
    print(f"Min Latency:              {min_latency:.3f} ms")
    print(f"Max Latency:              {max_latency:.3f} ms")
    print(f"Memory Usage Before:      {mem_before:.2f} MB")
    print(f"Memory Usage After:       {mem_after:.2f} MB")
    print(f"Memory Delta:             {mem_after - mem_before:.2f} MB (Target < 100 MB)")
    print(f"Average Samples/Board:    {samples_per_board:.1f}")
    print(f"Average Paraphrases/Move: {avg_paraphrases:.1f} (Target 10-50)")
    print(f"Output Deterministic:     {is_deterministic}")
    print("==================================================")
    
    with open("speech_benchmark_results.json", "w") as f:
        json.dump(summary, f, indent=2)
    print("Saved benchmark metrics to speech_benchmark_results.json")

if __name__ == "__main__":
    run_benchmarks()
