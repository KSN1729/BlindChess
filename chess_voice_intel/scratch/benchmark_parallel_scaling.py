import time
import shutil
import os
from audio_pipeline import AudioPipeline

TEST_DIR = "tests/benchmark_scaling_out"

def main():
    print("==================================================")
    print("STARTING PARALLEL SCALING BENCHMARK")
    print("==================================================")
    
    samples = [{"spokenText": f"knight to f {i}", "canonicalMove": "g1f3", "category": "opening", "variationType": "formal", "boardId": f"board_{i}"} for i in range(40)]
    
    for workers in [1, 2, 4]:
        if os.path.exists(TEST_DIR):
            shutil.rmtree(TEST_DIR)
        os.makedirs(TEST_DIR, exist_ok=True)
        
        t0 = time.perf_counter()
        results = AudioPipeline.process_batch(samples, TEST_DIR, max_workers=workers, resume=False)
        t1 = time.perf_counter()
        
        duration = t1 - t0
        throughput = len(samples) / duration
        print(f"Workers: {workers} -> Time: {duration:.3f}s, Throughput: {throughput:.2f} samples/sec")
        
    if os.path.exists(TEST_DIR):
        shutil.rmtree(TEST_DIR)
        
if __name__ == "__main__":
    main()
