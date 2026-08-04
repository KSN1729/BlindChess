import os
import json
import sys

# Windows native sound player
try:
    import winsound
    WINSOUND_AVAILABLE = True
except ImportError:
    WINSOUND_AVAILABLE = False

DEMO_DIR = "demo_audio_dataset"
SUMMARY_FILE = "demo_validation_summary.json"

def play_audio(filepath: str):
    if not WINSOUND_AVAILABLE:
        print("[WARNING] winsound library not available (Windows only). Cannot play audio.")
        return
    if not os.path.exists(filepath):
        print(f"[ERROR] Audio file not found: {filepath}")
        return
    try:
        # SND_FILENAME plays WAV files synchronously
        winsound.PlaySound(filepath, winsound.SND_FILENAME)
    except Exception as e:
        print(f"[ERROR] Failed to play audio: {e}")

def load_samples():
    if not os.path.exists(SUMMARY_FILE):
        print(f"[ERROR] Validation report {SUMMARY_FILE} not found. Please run: python generate_demo_dataset.py")
        sys.exit(1)
    with open(SUMMARY_FILE, "r") as f:
        return json.load(f)

def print_help():
    print("\nNavigation Controls:")
    print("  [Number] : Select and play a specific sample (1 - 110)")
    print("  n        : Play next sample")
    print("  p        : Play previous sample")
    print("  r        : Replay current sample")
    print("  l        : List all phrases")
    print("  h        : Show this help menu")
    print("  q / exit : Exit the application")

def main():
    samples = load_samples()
    if not samples:
        print("[ERROR] No samples loaded.")
        sys.exit(1)
        
    current_index = 0
    
    print("==================================================")
    print("BLINDCHESS TERMINAL AUDIO DEMO PLAYER")
    print("==================================================")
    print(f"Loaded {len(samples)} validated speech samples.")
    print_help()
    
    while True:
        s = samples[current_index]
        audio_path = os.path.join(DEMO_DIR, s["filename"])
        metadata_path = audio_path + ".json"
        
        # Load meta JSON
        meta = {}
        if os.path.exists(metadata_path):
            with open(metadata_path, "r") as f:
                meta = json.load(f)
                
        print("\n--------------------------------------------------")
        print(f"Sample {current_index + 1}/{len(samples)}")
        print(f"Spoken Text:  \"{s['phrase']}\"")
        print(f"Category:     {s['category'].upper()}")
        print(f"Duration:     {meta.get('duration', s.get('duration', 0.0)):.3f}s")
        print(f"Speaker ID:   {meta.get('speakerId', 'N/A')}")
        print(f"Checksum:     {s.get('checksum', 'N/A')}")
        print("--------------------------------------------------")
        
        print("Playing audio...")
        play_audio(audio_path)
        
        # User input loop
        cmd = input("\nEnter command: ").strip().lower()
        
        if cmd in ["q", "quit", "exit"]:
            print("Exiting. Thank you!")
            break
        elif cmd == "n":
            current_index = (current_index + 1) % len(samples)
        elif cmd == "p":
            current_index = (current_index - 1) % len(samples)
        elif cmd == "r":
            continue
        elif cmd == "h":
            print_help()
            input("\nPress Enter to continue...")
        elif cmd == "l":
            print("\n=== Phrase List ===")
            for idx, item in enumerate(samples):
                print(f"  {idx + 1:3d}. [{item['category']}] \"{item['phrase']}\"")
            print("===================")
            input("\nPress Enter to continue...")
        else:
            # Check if it is a number
            try:
                val = int(cmd)
                if 1 <= val <= len(samples):
                    current_index = val - 1
                else:
                    print(f"[WARNING] Invalid index. Select between 1 and {len(samples)}.")
                    time.sleep(1)
            except ValueError:
                print("[WARNING] Unknown command. Press 'h' for help.")
                time.sleep(1)

if __name__ == "__main__":
    import time
    main()
