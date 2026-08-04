import os
import sys
import hashlib
import json
import wave
from typing import List, Dict, Any
from audio_pipeline import AudioPipeline
from audio_validator import AudioValidator

# ANSI color escape codes for terminal outputs
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
CYAN = "\033[96m"
RESET = "\033[0m"

# Windows native sound player wrapper
try:
    import winsound
    WINSOUND_AVAILABLE = True
except ImportError:
    WINSOUND_AVAILABLE = False

DEMO_DIR = "demo_audio_dataset"

# 20 diverse representative SpeechSamples
SAMPLES = [
    {"spokenText": "pawn to e4", "canonicalMove": "e2e4", "category": "opening", "variationType": "formal", "boardId": "b1"},
    {"spokenText": "knight to f3", "canonicalMove": "g1f3", "category": "opening", "variationType": "conversational", "boardId": "b2"},
    {"spokenText": "bishop to c4", "canonicalMove": "f1c4", "category": "opening", "variationType": "formal", "boardId": "b3"},
    {"spokenText": "rook to d1", "canonicalMove": "h1d1", "category": "middlegame", "variationType": "conversational", "boardId": "b4"},
    
    {"spokenText": "knight takes pawn on e4", "canonicalMove": "c3e4", "category": "capture", "variationType": "formal", "boardId": "b5"},
    {"spokenText": "bishop takes knight on c6", "canonicalMove": "b5c6", "category": "capture", "variationType": "conversational", "boardId": "b6"},
    {"spokenText": "queen takes pawn on f7", "canonicalMove": "f3f7", "category": "capture", "variationType": "verbose", "boardId": "b7"},
    
    {"spokenText": "queen to h5 giving check", "canonicalMove": "d1h5", "category": "check", "variationType": "formal", "boardId": "b8"},
    {"spokenText": "bishop to b5 giving check", "canonicalMove": "f1b5", "category": "check", "variationType": "conversational", "boardId": "b9"},
    {"spokenText": "rook to e8 giving check", "canonicalMove": "e1e8", "category": "check", "variationType": "verbose", "boardId": "b10"},
    
    {"spokenText": "queen to f7 delivering checkmate", "canonicalMove": "h5f7", "category": "checkmate_in_one", "variationType": "formal", "boardId": "b11"},
    {"spokenText": "rook to h8 delivering checkmate", "canonicalMove": "h1h8", "category": "checkmate_in_one", "variationType": "conversational", "boardId": "b12"},
    {"spokenText": "queen to g7 mate", "canonicalMove": "g5g7", "category": "checkmate_in_one", "variationType": "minimal", "boardId": "b13"},
    
    {"spokenText": "castle kingside", "canonicalMove": "e1g1", "category": "castling", "variationType": "formal", "boardId": "b14"},
    {"spokenText": "castle queenside", "canonicalMove": "e1c1", "category": "castling", "variationType": "conversational", "boardId": "b15"},
    
    {"spokenText": "pawn to e8 promote to queen", "canonicalMove": "e7e8q", "category": "promotion", "variationType": "formal", "boardId": "b16"},
    {"spokenText": "pawn to d8 promote to rook", "canonicalMove": "d7d8r", "category": "promotion", "variationType": "conversational", "boardId": "b17"},
    
    {"spokenText": "rook from a to d1", "canonicalMove": "a1d1", "category": "ambiguous_rook", "variationType": "formal", "boardId": "b18"},
    
    {"spokenText": "move is invalid", "canonicalMove": "none", "category": "invalid_moves", "variationType": "formal", "boardId": "b19"},
    {"spokenText": "pawn cannot move there", "canonicalMove": "none", "category": "invalid_moves", "variationType": "conversational", "boardId": "b20"}
]

def play_audio(filepath: str):
    if not WINSOUND_AVAILABLE:
        print(f"{YELLOW}[WARNING]{RESET} winsound not available (Windows only). Cannot play audio.")
        return
    if not os.path.exists(filepath):
        print(f"{RED}[ERROR]{RESET} WAV file not found: {filepath}")
        return
    try:
        winsound.PlaySound(filepath, winsound.SND_FILENAME)
    except Exception as e:
        print(f"{RED}[ERROR]{RESET} Failed to play WAV: {e}")

def print_progress_bar(iteration: int, total: int, prefix: str = "", length: int = 40):
    percent = f"{100.0 * (iteration / float(total)):.1f}"
    filled_length = int(length * iteration // total)
    bar = "#" * filled_length + "-" * (length - filled_length)
    sys.stdout.write(f"\r{prefix} |{bar}| {percent}% Complete")
    sys.stdout.flush()
    if iteration == total:
        sys.stdout.write("\n")

def run_synthesis_and_validation() -> List[Dict[str, Any]]:
    print(f"\n{CYAN}==================================================")
    print("STEP 1: BATCH GENERATION & SPEC VALIDATION")
    print(f"=================================================={RESET}")
    
    os.makedirs(DEMO_DIR, exist_ok=True)
    total = len(SAMPLES)
    validation_records = []
    
    print_progress_bar(0, total, prefix="Progress:", length=45)
    
    for idx, s in enumerate(SAMPLES):
        success, msg, meta = AudioPipeline.process_speech_sample(s, DEMO_DIR, resume=True)
        filename = AudioPipeline.get_output_filename(s["spokenText"])
        filepath = os.path.join(DEMO_DIR, filename)
        
        status = "FAIL"
        reason = msg
        rate, ch, width, dur, checksum = 0, 0, 0, 0.0, "N/A"
        
        if success:
            is_valid, val_reason = AudioValidator.validate_audio_file(filepath)
            if is_valid:
                status = "PASS"
                reason = "Valid WAV"
                checksum = AudioValidator.compute_sha256(filepath)
                # Read properties directly from WAV
                with wave.open(filepath, "rb") as w:
                    rate = w.getframerate()
                    ch = w.getnchannels()
                    width = w.getsampwidth() * 8
                    dur = w.getnframes() / rate
            else:
                reason = val_reason
                
        validation_records.append({
            "spokenText": s["spokenText"],
            "filename": filename,
            "category": s["category"],
            "rate": rate,
            "channels": ch,
            "width": width,
            "checksum": checksum[:16] + "...",
            "duration": dur,
            "status": status,
            "reason": reason
        })
        
        print_progress_bar(idx + 1, total, prefix="Progress:", length=45)
        
    return validation_records

def print_validation_table(records: List[Dict[str, Any]]):
    print(f"\n{CYAN}==================================================")
    print("STEP 2: PIPELINE SPECIFICATION AUDIT")
    print(f"=================================================={RESET}\n")
    
    # Header format
    header = f"{'Num':<3} | {'Spoken Text':<30} | {'Rate':<6} | {'Ch':<2} | {'Bit':<3} | {'Duration':<8} | {'Status':<5} | {'Notes':<18}"
    print(header)
    print("-" * len(header))
    
    for i, r in enumerate(records):
        color = GREEN if r["status"] == "PASS" else RED
        note = r["reason"][:18]
        row = f"{i+1:3d} | {r['spokenText'][:30]:<30} | {r['rate']:<6} | {r['channels']:<2} | {r['width']:<3} | {r['duration']:8.3f} | {color}{r['status']:<5}{RESET} | {note:<18}"
        print(row)
        
    print("\n" + "=" * len(header))
    passes = sum(1 for r in records if r["status"] == "PASS")
    print(f"Final Audit Summary: {GREEN if passes==len(records) else RED}{passes} / {len(records)} PASSED{RESET}")
    print("=" * len(header))

def print_menu():
    print(f"\n{CYAN}Demo Navigation Controls:{RESET}")
    print("  [1 - 20]  : Play a specific sample by number")
    print("  n         : Next sample")
    print("  p         : Previous sample")
    print("  r         : Replay current sample")
    print("  l         : List all phrases")
    print("  h         : Show help")
    print("  q / exit  : Quit demo")

def interactive_loop(records: List[Dict[str, Any]]):
    print(f"\n{CYAN}==================================================")
    print("STEP 3: INTERACTIVE USER VERIFICATION")
    print(f"=================================================={RESET}")
    
    current_index = 0
    print_menu()
    
    while True:
        r = records[current_index]
        audio_path = os.path.join(DEMO_DIR, r["filename"])
        
        print("\n--------------------------------------------------")
        print(f"Playing Sample {current_index + 1}/20")
        print(f"Text:      \"{r['spokenText']}\"")
        print(f"Category:  {r['category'].upper()}")
        print(f"Rate:      {r['rate']} Hz | Channels: {r['channels']} | Bit depth: {r['width']}-bit")
        print(f"Duration:  {r['duration']:.3f}s")
        print(f"SHA-256:   {r['checksum']}")
        print("--------------------------------------------------")
        
        play_audio(audio_path)
        
        cmd = input("\nEnter command: ").strip().lower()
        
        if cmd in ["q", "quit", "exit"]:
            print("\nExiting demonstration. Thank you!")
            break
        elif cmd == "n":
            current_index = (current_index + 1) % len(records)
        elif cmd == "p":
            current_index = (current_index - 1) % len(records)
        elif cmd == "r":
            continue
        elif cmd == "h":
            print_menu()
            input("\nPress Enter to continue...")
        elif cmd == "l":
            print(f"\n{CYAN}=== Demo Phrase List ==={RESET}")
            for idx, item in enumerate(records):
                print(f"  {idx + 1:2d}. [{item['category']}] \"{item['spokenText']}\"")
            print("========================")
            input("\nPress Enter to continue...")
        else:
            try:
                val = int(cmd)
                if 1 <= val <= len(records):
                    current_index = val - 1
                else:
                    print(f"{YELLOW}[WARNING] Select index between 1 and 20.{RESET}")
            except ValueError:
                print(f"{YELLOW}[WARNING] Unknown navigation command. Press 'h' for help.{RESET}")

if __name__ == "__main__":
    records = run_synthesis_and_validation()
    print_validation_table(records)
    interactive_loop(records)
