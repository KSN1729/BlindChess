import wave
from piper import PiperVoice

def main():
    model_path = "piper_voices/en_US-lessac-medium.onnx"
    print("Loading voice model...")
    voice = PiperVoice.load(model_path)
    
    print("Synthesizing audio...")
    output_file = "scratch/piper_test.wav"
    with wave.open(output_file, "wb") as wav_file:
        voice.synthesize_wav("knight to f3", wav_file)
        
    print(f"Done! Audio saved to {output_file}")
    
    # Read properties
    with wave.open(output_file, "rb") as w:
        print(f"Channels: {w.getnchannels()}")
        print(f"Sample width: {w.getsampwidth()}")
        print(f"Frame rate: {w.getframerate()}")
        print(f"Duration: {w.getnframes() / w.getframerate():.3f} seconds")

if __name__ == "__main__":
    main()
