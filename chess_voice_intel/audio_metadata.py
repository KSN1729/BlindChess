import hashlib
import json
import os
from typing import Dict, Any

class AudioMetadataManager:
    """
    Computes cryptographic checksums and manages the generation
    and formatting of metadata sidecars for speech WAV files.
    """

    @staticmethod
    def compute_sha256(filepath: str) -> str:
        """Computes the SHA-256 hash of a file."""
        sha256 = hashlib.sha256()
        with open(filepath, "rb") as f:
            while chunk := f.read(8192):
                sha256.update(chunk)
        return sha256.hexdigest()

    @staticmethod
    def generate_and_save_metadata(
        audio_filepath: str,
        speech_sample: Dict[str, Any],
        board_id: str,
        duration: float,
        speaker_id: str
    ) -> Dict[str, Any]:
        """
        Creates and saves a metadata dictionary alongside the audio file.
        Returns the metadata dictionary.
        """
        checksum = AudioMetadataManager.compute_sha256(audio_filepath)
        
        metadata = {
            "canonicalMove": speech_sample["canonicalMove"],
            "spokenText": speech_sample["spokenText"],
            "boardId": board_id,
            "style": speech_sample["variationType"],
            "category": speech_sample["category"],
            "duration": duration,
            "sampleRate": 16000,
            "speakerId": speaker_id,
            "checksum": checksum
        }
        
        metadata_filepath = audio_filepath + ".json"
        with open(metadata_filepath, "w") as f:
            json.dump(metadata, f, indent=2)
            
        return metadata
