import os
import hashlib
import json
from typing import Dict, Any, Tuple
from audio_generator import AudioGenerator
from audio_validator import AudioValidator
from audio_metadata import AudioMetadataManager

class AudioPipeline:
    """
    Orchestration Engine converting a validated SpeechSample into a high-quality WAV audio file,
    providing full resumability, validation checks, and metadata generation.
    """

    @staticmethod
    def get_output_filename(spoken_text: str) -> str:
        """Generates a stable, collision-free, path-safe filename from the spoken text."""
        h = hashlib.md5(spoken_text.encode("utf-8")).hexdigest()
        return f"speech_{h}.wav"

    @staticmethod
    def process_speech_sample(
        speech_sample: Dict[str, Any],
        output_dir: str,
        resume: bool = True
    ) -> Tuple[bool, str, Dict[str, Any]]:
        """
        Processes a single SpeechSample.
        If resume=True and file exists & validates, skips generation.
        Returns (success, reason/message, metadata_dict).
        """
        spoken_text = speech_sample["spokenText"]
        filename = AudioPipeline.get_output_filename(spoken_text)
        audio_path = os.path.join(output_dir, filename)
        metadata_path = audio_path + ".json"
        
        board_id = speech_sample.get("boardId", hashlib.md5(spoken_text.encode("utf-8")).hexdigest()[:8])
        speaker_id = "en_US-lessac-medium"
        
        # 1. Resumability: check if already exists and passes validation
        if resume and os.path.exists(audio_path) and os.path.exists(metadata_path):
            is_valid, reason = AudioValidator.validate_audio_file(audio_path)
            if is_valid:
                try:
                    with open(metadata_path, "r") as f:
                        meta = json.load(f)
                    # Verify checksum matching
                    current_checksum = AudioValidator.compute_sha256(audio_path)
                    if meta.get("checksum") == current_checksum:
                        return True, "Resumed: skipped generation", meta
                except Exception:
                    pass  # If reading metadata failed, regenerate

        # 2. Generation Step
        try:
            audio_info = AudioGenerator.generate_audio(spoken_text, audio_path)
        except Exception as e:
            return False, f"TTS generation failed: {e}", {}

        # 3. Audio Validation Step
        is_valid, reason = AudioValidator.validate_audio_file(audio_path)
        if not is_valid:
            if os.path.exists(audio_path):
                os.remove(audio_path)
            return False, f"Validation failed: {reason}", {}

        # 4. Metadata sidecar generation
        try:
            meta = AudioMetadataManager.generate_and_save_metadata(
                audio_filepath=audio_path,
                speech_sample=speech_sample,
                board_id=board_id,
                duration=audio_info["duration_seconds"],
                speaker_id=speaker_id
            )
        except Exception as e:
            if os.path.exists(audio_path):
                os.remove(audio_path)
            return False, f"Metadata sidecar generation failed: {e}", {}

        return True, "Generated and validated successfully", meta

    @staticmethod
    def process_batch(
        samples: list,
        output_dir: str,
        max_workers: int = 4,
        resume: bool = True
    ) -> list:
        """Processes a batch of speech samples in parallel using thread pools."""
        from concurrent.futures import ThreadPoolExecutor, as_completed
        
        os.makedirs(output_dir, exist_ok=True)
        ordered_results = [None] * len(samples)
        
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = {
                executor.submit(AudioPipeline.process_speech_sample, s, output_dir, resume): i
                for i, s in enumerate(samples)
            }
            
            completed_count = 0
            for fut in as_completed(futures):
                idx = futures[fut]
                try:
                    success, msg, meta = fut.result()
                    ordered_results[idx] = (success, msg, meta)
                except Exception as e:
                    ordered_results[idx] = (False, f"Unhandled thread pool exception: {e}", {})
                
                completed_count += 1
                if completed_count % max(1, len(samples) // 10) == 0 or completed_count == len(samples):
                    print(f"Audio generation progress: {completed_count}/{len(samples)} ({completed_count/len(samples)*100.0:.1f}%)")
                    
        return ordered_results
