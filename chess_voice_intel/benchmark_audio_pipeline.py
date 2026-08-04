import time
import json
import psutil
import os
import shutil
import math
from audio_pipeline import AudioPipeline

TEST_BENCHMARK_DIR = "tests/benchmark_audio_out"

def get_percentile(data, percentile):
    size = len(data)
    return sorted(data)[int(math.ceil((size * percentile) / 100)) - 1]

def run_benchmarks():
    print("==================================================")
    print("STARTING AUDIO GENERATION PIPELINE BENCHMARKS")
    print("==================================================")
    
    if os.path.exists(TEST_BENCHMARK_DIR):
        shutil.rmtree(TEST_BENCHMARK_DIR)
    os.makedirs(TEST_BENCHMARK_DIR, exist_ok=True)
    
    # 100 dummy samples to benchmark
    samples = []
    for i in range(100):
        samples.append({
            "spokenText": f"knight to f {i}",
            "canonicalMove": f"g1f3",
            "category": "opening",
            "variationType": "formal",
            "boardId": f"board_{i}"
        })
        
    process = psutil.Process(os.getpid())
    mem_before = process.memory_info().rss / (1024 * 1024)
    cpu_before = psutil.cpu_percent(interval=None)
    
    latencies = []
    t_start = time.perf_counter()
    
    for s in samples:
        t0 = time.perf_counter()
        success, msg, meta = AudioPipeline.process_speech_sample(s, TEST_BENCHMARK_DIR, resume=False)
        t1 = time.perf_counter()
        
        assert success, f"Pipeline failed: {msg}"
        latencies.append((t1 - t0) * 1000.0) # ms
        
    t_end = time.perf_counter()
    mem_after = process.memory_info().rss / (1024 * 1024)
    cpu_after = psutil.cpu_percent(interval=None)
    
    total_time = t_end - t_start
    avg_latency = sum(latencies) / len(latencies)
    min_latency = min(latencies)
    max_latency = max(latencies)
    p95_latency = get_percentile(latencies, 95)
    
    # Calculate disk usage
    total_size = sum(os.path.getsize(os.path.join(TEST_BENCHMARK_DIR, f)) for f in os.listdir(TEST_BENCHMARK_DIR))
    disk_usage_kb = total_size / 1024
    
    metrics = {
        "boards_processed": len(samples),
        "total_time_seconds": total_time,
        "throughput_samples_per_second": len(samples) / total_time,
        "latency_stats": {
            "avg_ms": avg_latency,
            "min_ms": min_latency,
            "max_ms": max_latency,
            "p95_ms": p95_latency
        },
        "cpu": {
            "before_percent": cpu_before,
            "after_percent": cpu_after
        },
        "memory": {
            "before_mb": mem_before,
            "after_mb": mem_after,
            "delta_mb": mem_after - mem_before
        },
        "disk": {
            "total_bytes": total_size,
            "total_kb": disk_usage_kb
        }
    }
    
    print(f"Average Latency:          {avg_latency:.3f} ms")
    print(f"95th Percentile Latency:  {p95_latency:.3f} ms")
    print(f"Min Latency:              {min_latency:.3f} ms")
    print(f"Max Latency:              {max_latency:.3f} ms")
    print(f"Throughput:               {metrics['throughput_samples_per_second']:.1f} samples/sec")
    print(f"Memory Footprint Delta:    {mem_after - mem_before:.2f} MB")
    print(f"Disk Space Consumption:   {disk_usage_kb:.2f} KB (100 files)")
    print("==================================================")
    
    with open("audio_benchmark_results.json", "w") as f:
        json.dump(metrics, f, indent=2)
    print("Saved results to audio_benchmark_results.json")
    
    # Clean up
    if os.path.exists(TEST_BENCHMARK_DIR):
        shutil.rmtree(TEST_BENCHMARK_DIR)

if __name__ == "__main__":
    run_benchmarks()
