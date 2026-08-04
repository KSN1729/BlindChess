import wave
import struct
import math

def resample_wav(input_path: str, output_path: str, target_rate: int = 16000):
    with wave.open(input_path, "rb") as in_wav:
        channels = in_wav.getnchannels()
        sampwidth = in_wav.getsampwidth()
        framerate = in_wav.getframerate()
        n_frames = in_wav.getnframes()
        frames = in_wav.readframes(n_frames)
        
    print(f"Original: rate={framerate}, channels={channels}, width={sampwidth}, frames={n_frames}")
    
    # 1. Unpack to integers
    num_samples = len(frames) // (sampwidth * channels)
    # We assume mono for now (piper is mono)
    samples = struct.unpack(f"<{num_samples}h", frames)
    
    # 2. Resample
    ratio = framerate / target_rate
    new_num_samples = int(num_samples * target_rate / framerate)
    new_samples = []
    
    for i in range(new_num_samples):
        old_idx = i * ratio
        low_idx = int(math.floor(old_idx))
        high_idx = min(num_samples - 1, low_idx + 1)
        weight = old_idx - low_idx
        
        # Linear interpolation
        val = int((1.0 - weight) * samples[low_idx] + weight * samples[high_idx])
        new_samples.append(val)
        
    # 3. Pack to bytes
    new_frames = struct.pack(f"<{new_num_samples}h", *new_samples)
    
    with wave.open(output_path, "wb") as out_wav:
        out_wav.setnchannels(1)
        out_wav.setsampwidth(2)
        out_wav.setframerate(target_rate)
        out_wav.writeframes(new_frames)
        
    print(f"Resampled: rate={target_rate}, frames={new_num_samples}")

def main():
    resample_wav("scratch/piper_test.wav", "scratch/piper_resampled.wav")
    with wave.open("scratch/piper_resampled.wav", "rb") as w:
        print(f"Verified Rate: {w.getframerate()}")
        print(f"Verified Channels: {w.getnchannels()}")
        print(f"Verified Duration: {w.getnframes() / w.getframerate():.3f}s")

if __name__ == "__main__":
    main()
