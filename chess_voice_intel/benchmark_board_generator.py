import time
import os
import psutil
import json
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

def run_benchmarks():
    print("==================================================")
    print("STARTING BOARD GENERATION LATENCY BENCHMARK SWEEP")
    print("==================================================")
    
    process = psutil.Process(os.getpid())
    mem_before = process.memory_info().rss / (1024 * 1024) # MB
    
    results = {}
    total_runs = 500
    
    for category in CATEGORIES:
        latencies = []
        
        # Warmup
        for _ in range(5):
            BoardGenerator.generate_sample(category)
            
        for _ in range(total_runs):
            t_start = time.perf_counter()
            BoardGenerator.generate_sample(category)
            t_end = time.perf_counter()
            latencies.append((t_end - t_start) * 1000.0) # ms
            
        avg_lat = sum(latencies) / len(latencies)
        min_lat = min(latencies)
        max_lat = max(latencies)
        
        results[category] = {
            "avg": avg_lat,
            "min": min_lat,
            "max": max_lat
        }
        
        print(f"Category: {category:<20} | Avg: {avg_lat:6.3f}ms | Min: {min_lat:6.3f}ms | Max: {max_lat:6.3f}ms")
        
    mem_after = process.memory_info().rss / (1024 * 1024) # MB
    mem_diff = mem_after - mem_before
    
    fastest = min(results.keys(), key=lambda k: results[k]["avg"])
    slowest = max(results.keys(), key=lambda k: results[k]["avg"])
    
    summary = {
        "runs_per_category": total_runs,
        "results": results,
        "memory_before_mb": mem_before,
        "memory_after_mb": mem_after,
        "memory_diff_mb": mem_diff,
        "fastest_category": fastest,
        "slowest_category": slowest
    }
    
    print("--------------------------------------------------")
    print(f"Fastest Generator: {fastest} ({results[fastest]['avg']:.3f} ms)")
    print(f"Slowest Generator: {slowest} ({results[slowest]['avg']:.3f} ms)")
    print(f"Process Memory Before: {mem_before:.2f} MB")
    print(f"Process Memory After:  {mem_after:.2f} MB (Delta: {mem_diff:+.2f} MB)")
    print("==================================================")
    
    with open("benchmark_results.json", "w") as f:
        json.dump(summary, f, indent=2)
    print("Saved benchmark metrics to benchmark_results.json")

if __name__ == "__main__":
    run_benchmarks()
