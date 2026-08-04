import os
import wave
import struct
import hashlib
from typing import Tuple

class AudioValidator:
    """
    Validates audio files against target WAV specifications (16kHz, mono, 16-bit PCM)
    and checks for signal issues (silence, clipping, truncation).
    """

    @staticmethod
    def validate_audio_file(filepath: str) -> Tuple[bool, str]:
        """
        Validates the WAV file.
        Returns (is_valid, reason).
        """
        if not os.path.exists(filepath):
            return False, f"File does not exist: {filepath}"
            
        file_size = os.path.getsize(filepath)
        if file_size < 44:  # Minimum standard WAV header size
            return False, f"File is too small to be a valid WAV ({file_size} bytes)"

        try:
            with wave.open(filepath, "rb") as wav_file:
                channels = wav_file.getnchannels()
                sampwidth = wav_file.getsampwidth()
                framerate = wav_file.getframerate()
                n_frames = wav_file.getnframes()
                
                # 1. Verify WAV Spec parameters
                if channels != 1:
                    return False, f"Invalid channels: expected 1 (mono), got {channels}"
                if sampwidth != 2:
                    return False, f"Invalid bit depth: expected 16-bit (width 2), got {sampwidth * 8}-bit"
                if framerate != 16000:
                    return False, f"Invalid sample rate: expected 16000Hz, got {framerate}Hz"
                if n_frames == 0:
                    return False, "WAV contains 0 audio frames"
                    
                # 2. Check for truncation (under 0.2 seconds duration)
                duration = n_frames / framerate
                if duration < 0.2:
                    return False, f"Audio duration too short ({duration:.3f}s)"

                # Read all frame data for amplitude checks
                frames_data = wav_file.readframes(n_frames)
                num_samples = len(frames_data) // 2
                
                # Unpack short integers (16-bit PCM values)
                samples = struct.unpack(f"<{num_samples}h", frames_data)
                
                if not samples:
                    return False, "Failed to decode WAV samples"

                # 3. Check for absolute silence (all values zero or near zero)
                max_amplitude = max(abs(s) for s in samples)
                if max_amplitude < 10:  # Threshold for noise floor silence
                    return False, f"Audio file is silent (max amplitude: {max_amplitude})"

                # 4. Check for clipping (extreme amplification clipping at maximum bounds)
                clip_count = sum(1 for s in samples if s >= 32766 or s <= -32767)
                clip_rate = clip_count / len(samples)
                if clip_rate > 0.05:  # Over 5% clipping rate is rejected
                    return False, f"Excessive clipping detected: {clip_rate * 100.0:.2f}%"

        except Exception as e:
            return False, f"WAV parser exception: {e}"

        return True, "Valid WAV"

    @staticmethod
    def compute_sha256(filepath: str) -> str:
        """Computes the SHA-256 hash of a file."""
        sha256 = hashlib.sha256()
        with open(filepath, "rb") as f:
            while chunk := f.read(8192):
                sha256.update(chunk)
        return sha256.hexdigest()

    @staticmethod
    def validate_checksum(filepath: str, expected_checksum: str) -> bool:
        """Returns True if the file's SHA-256 matches the expected checksum."""
        try:
            return AudioValidator.compute_sha256(filepath) == expected_checksum
        except Exception:
            return False
