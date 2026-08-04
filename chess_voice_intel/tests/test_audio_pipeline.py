import os
import shutil
import pytest
import wave
import struct
import time
from audio_generator import AudioGenerator
from audio_validator import AudioValidator
from audio_metadata import AudioMetadataManager
from audio_pipeline import AudioPipeline

TEST_OUTPUT_DIR = "tests/test_audio_out"

@pytest.fixture(autouse=True)
def setup_and_teardown():
    os.makedirs(TEST_OUTPUT_DIR, exist_ok=True)
    yield
    if os.path.exists(TEST_OUTPUT_DIR):
        shutil.rmtree(TEST_OUTPUT_DIR)

def test_wav_synthesis():
    filepath = os.path.join(TEST_OUTPUT_DIR, "piper_test.wav")
    text = "knight to f3"
    
    info = AudioGenerator.generate_audio(text, filepath)
    assert os.path.exists(filepath)
    assert info["channels"] == 1
    assert info["sample_rate_hz"] == 16000
    assert info["bit_depth"] == 16
    
    # Read properties directly from WAV
    with wave.open(filepath, "rb") as w:
        assert w.getnchannels() == 1
        assert w.getsampwidth() == 2
        assert w.getframerate() == 16000

def test_audio_validator_valid():
    filepath = os.path.join(TEST_OUTPUT_DIR, "valid_test.wav")
    AudioGenerator.generate_audio("move rook to d1", filepath)
    
    is_valid, reason = AudioValidator.validate_audio_file(filepath)
    assert is_valid, f"Validation failed: {reason}"

def test_audio_validator_silence():
    filepath = os.path.join(TEST_OUTPUT_DIR, "silent_test.wav")
    
    # Write a silent WAV (all zeros)
    with wave.open(filepath, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(16000)
        # 1 second of silence
        w.writeframes(struct.pack("<16000h", *[0]*16000))
        
    is_valid, reason = AudioValidator.validate_audio_file(filepath)
    assert not is_valid
    assert "silent" in reason

def test_audio_validator_truncated():
    filepath = os.path.join(TEST_OUTPUT_DIR, "truncated_test.wav")
    
    # Write a very short WAV (0.05 seconds)
    with wave.open(filepath, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(16000)
        w.writeframes(struct.pack("<800h", *[100]*800))
        
    is_valid, reason = AudioValidator.validate_audio_file(filepath)
    assert not is_valid
    assert "duration too short" in reason

def test_metadata_generation():
    filepath = os.path.join(TEST_OUTPUT_DIR, "meta_test.wav")
    AudioGenerator.generate_audio("pawn to e4", filepath)
    
    sample = {
        "spokenText": "pawn to e4",
        "canonicalMove": "e2e4",
        "category": "opening",
        "variationType": "formal"
    }
    
    meta = AudioMetadataManager.generate_and_save_metadata(
        audio_filepath=filepath,
        speech_sample=sample,
        board_id="board123",
        duration=1.2,
        speaker_id="en_US-lessac-medium"
    )
    
    assert meta["spokenText"] == "pawn to e4"
    assert meta["canonicalMove"] == "e2e4"
    assert meta["duration"] == 1.2
    assert "checksum" in meta
    
    # Assert JSON file exists
    assert os.path.exists(filepath + ".json")

def test_pipeline_resumability():
    sample = {
        "spokenText": "castle kingside",
        "canonicalMove": "e1g1",
        "category": "castling",
        "variationType": "formal"
    }
    
    # First generation
    success1, msg1, meta1 = AudioPipeline.process_speech_sample(sample, TEST_OUTPUT_DIR, resume=True)
    assert success1
    assert "Generated" in msg1
    
    # Capture modification time
    filename = AudioPipeline.get_output_filename(sample["spokenText"])
    filepath = os.path.join(TEST_OUTPUT_DIR, filename)
    mtime_before = os.path.getmtime(filepath)
    
    # Second generation (resume=True)
    success2, msg2, meta2 = AudioPipeline.process_speech_sample(sample, TEST_OUTPUT_DIR, resume=True)
    assert success2
    assert "Resumed" in msg2
    
    mtime_after = os.path.getmtime(filepath)
    assert mtime_before == mtime_after  # File was NOT modified

def test_pipeline_recovery_corrupt():
    sample = {
        "spokenText": "castle queenside",
        "canonicalMove": "e1c1",
        "category": "castling",
        "variationType": "formal"
    }
    
    filename = AudioPipeline.get_output_filename(sample["spokenText"])
    filepath = os.path.join(TEST_OUTPUT_DIR, filename)
    
    # Write a corrupt/truncated WAV manually
    with wave.open(filepath, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(16000)
        w.writeframes(struct.pack("<100h", *[50]*100))  # 100 frames is too short
        
    with open(filepath + ".json", "w") as f:
        f.write("{}")  # Empty metadata
        
    # Execute pipeline: it should detect corruption, delete it, and regenerate a valid one
    success, msg, meta = AudioPipeline.process_speech_sample(sample, TEST_OUTPUT_DIR, resume=True)
    assert success
    assert "Generated" in msg  # Should have regenerated
    
    # Verify final audio is valid
    is_valid, reason = AudioValidator.validate_audio_file(filepath)
    assert is_valid

def test_pipeline_parallel_batch():
    samples = [
        {
            "spokenText": f"pawn to e {i}",
            "canonicalMove": "e2e4",
            "category": "opening",
            "variationType": "formal",
            "boardId": f"board_{i}"
        }
        for i in range(5)
    ]
    
    results = AudioPipeline.process_batch(samples, TEST_OUTPUT_DIR, max_workers=2, resume=True)
    assert len(results) == 5
    for success, msg, meta in results:
        assert success
        assert meta["speakerId"] == "en_US-lessac-medium"
        assert meta["sampleRate"] == 16000
