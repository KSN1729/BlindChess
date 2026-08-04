import sys
import json
import os
from audio_pipeline import AudioPipeline

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"success": False, "error": "Missing text argument"}))
        sys.exit(1)
        
    text = sys.argv[1]
    board_id = sys.argv[2] if len(sys.argv) > 2 else "board_default"
    category = sys.argv[3] if len(sys.argv) > 3 else "move"
    
    # Map typical spoken text to a realistic canonical move
    text_clean = text.strip().lower()
    canonical_move = "e2e4"  # default
    
    if "f3" in text_clean:
        canonical_move = "g1f3"
    elif "kingside" in text_clean or "e1g1" in text_clean:
        canonical_move = "e1g1"
    elif "queenside" in text_clean or "e1c1" in text_clean:
        canonical_move = "e1c1"
    elif "f7" in text_clean:
        canonical_move = "d1h5"
    elif "promote to queen" in text_clean or "e8q" in text_clean:
        canonical_move = "e7e8q"
    elif "d4" in text_clean:
        canonical_move = "d2d4"
    elif "c4" in text_clean:
        canonical_move = "f1c4"
    elif "d1" in text_clean:
        canonical_move = "h1d1"
        
    sample = {
        "spokenText": text,
        "canonicalMove": canonical_move,
        "category": category,
        "variationType": "formal",
        "boardId": board_id
    }
    
    # Generate into 'cached_speech' directory
    current_dir = os.path.dirname(os.path.abspath(__file__))
    output_dir = os.path.join(current_dir, "cached_speech")
    os.makedirs(output_dir, exist_ok=True)
    
    try:
        success, msg, meta = AudioPipeline.process_speech_sample(sample, output_dir, resume=True)
        if success:
            filename = AudioPipeline.get_output_filename(text)
            audio_path = os.path.join(output_dir, filename)
            meta["audioPath"] = audio_path
            
            # Keep cache sidecar synchronized with the new mapping
            if meta.get("canonicalMove") != canonical_move:
                meta["canonicalMove"] = canonical_move
                metadata_path = audio_path + ".json"
                try:
                    with open(metadata_path, "w") as f:
                        json.dump(meta, f, indent=2)
                except Exception:
                    pass
            
            print(json.dumps({"success": True, "metadata": meta}))
        else:
            print(json.dumps({"success": False, "error": msg}))
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))

if __name__ == "__main__":
    main()
