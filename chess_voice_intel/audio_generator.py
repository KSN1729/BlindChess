import os
import math
import struct
import wave
import threading
from typing import Dict, Any
from piper import PiperVoice

class AudioGenerator:
    """
    Production-quality offline text-to-speech generator using Piper ONNX.
    Spec: 16kHz, mono, 16-bit PCM WAV.
    """
    _local = threading.local()
    MODEL_PATH = "piper_voices/en_US-lessac-medium.onnx"

    @classmethod
    def _get_voice(cls) -> PiperVoice:
        """Lazily loads and caches the PiperVoice model per thread to optimize speed and thread safety."""
        if not hasattr(cls._local, "voice") or cls._local.voice is None:
            if not os.path.exists(cls.MODEL_PATH):
                raise FileNotFoundError(
                    f"Piper voice model not found at {cls.MODEL_PATH}. "
                    "Please run: python -m piper.download_voices en_US-lessac-medium"
                )
            cls._local.voice = PiperVoice.load(cls.MODEL_PATH)
        return cls._local.voice

    @staticmethod
    def _resample_wav(input_path: str, output_path: str, target_rate: int = 16000):
        """
        Pure-Python linear interpolation resampler. Resamples mono 16-bit PCM WAV
        from the source rate (e.g. 22050Hz) to target_rate (16000Hz).
        """
        with wave.open(input_path, "rb") as in_wav:
            channels = in_wav.getnchannels()
            sampwidth = in_wav.getsampwidth()
            framerate = in_wav.getframerate()
            n_frames = in_wav.getnframes()
            frames = in_wav.readframes(n_frames)

        # Unpack PCM 16-bit frames (short integers)
        num_samples = len(frames) // (sampwidth * channels)
        samples = struct.unpack(f"<{num_samples}h", frames)

        # Resampling ratio
        ratio = framerate / target_rate
        new_num_samples = int(num_samples * target_rate / framerate)
        new_samples = []

        for i in range(new_num_samples):
            old_idx = i * ratio
            low_idx = int(math.floor(old_idx))
            high_idx = min(num_samples - 1, low_idx + 1)
            weight = old_idx - low_idx
            
            # Linear interpolation formula
            val = int((1.0 - weight) * samples[low_idx] + weight * samples[high_idx])
            new_samples.append(val)

        new_frames = struct.pack(f"<{new_num_samples}h", *new_samples)

        with wave.open(output_path, "wb") as out_wav:
            out_wav.setnchannels(1)      # Mono
            out_wav.setsampwidth(2)     # 16-bit PCM
            out_wav.setframerate(target_rate)
            out_wav.writeframes(new_frames)

    @classmethod
    def generate_audio(cls, text: str, output_path: str) -> Dict[str, Any]:
        """
        Synthesizes text using Piper, resamples to 16kHz mono, and saves to output_path.
        """
        os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
        
        # Clean text for natural reading pronunciation
        clean_text = text.replace("=", " promote to ").replace("+", " giving check").replace("#", " delivering checkmate")
        
        voice = cls._get_voice()
        temp_wav = output_path + ".temp.wav"
        
        # Synthesize to temp 22050Hz WAV
        with wave.open(temp_wav, "wb") as temp_file:
            voice.synthesize_wav(clean_text, temp_file)
            
        # Resample to finalized 16kHz WAV
        cls._resample_wav(temp_wav, output_path, target_rate=16000)
        
        if os.path.exists(temp_wav):
            os.remove(temp_wav)
            
        # Read final duration
        with wave.open(output_path, "rb") as w:
            duration = w.getnframes() / w.getframerate()
            
        return {
            "output_path": output_path,
            "duration_seconds": duration,
            "sample_rate_hz": 16000,
            "channels": 1,
            "bit_depth": 16
        }
