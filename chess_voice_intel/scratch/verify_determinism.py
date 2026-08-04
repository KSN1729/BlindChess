import os
import hashlib
from audio_generator import AudioGenerator

def compute_sha256(filepath: str) -> str:
    sha256 = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(8192):
            sha256.update(chunk)
    return sha256.hexdigest()

def main():
    print("==================================================")
    print("VERIFYING PIPER DETERMINISM")
    print("==================================================")
    
    text = "knight to f3"
    path1 = "scratch/det_test_1.wav"
    path2 = "scratch/det_test_2.wav"
    
    if os.path.exists(path1):
        os.remove(path1)
    if os.path.exists(path2):
        os.remove(path2)
        
    print("Generating Run 1...")
    AudioGenerator.generate_audio(text, path1)
    hash1 = compute_sha256(path1)
    print(f"Run 1 Hash: {hash1}")
    
    print("Generating Run 2...")
    AudioGenerator.generate_audio(text, path2)
    hash2 = compute_sha256(path2)
    print(f"Run 2 Hash: {hash2}")
    
    is_matching = hash1 == hash2
    print(f"Hashes Match: {is_matching}")
    print("==================================================")
    
    if os.path.exists(path1):
        os.remove(path1)
    if os.path.exists(path2):
        os.remove(path2)

if __name__ == "__main__":
    main()
