# End-to-End Production Demonstration Guide

This guide explains how to install, launch, and test the master offline speech synthesis demonstration.

---

## 1. Setup Instructions
Verify that the `piper-tts` package is installed and the voice model has been downloaded locally:
```bash
pip install piper-tts
python -m piper.download_voices --download-dir piper_voices en_US-lessac-medium
```

---

## 2. Launching the Demo
Run the main demonstration file:
```bash
python demo.py
```

---

## 3. Expected Output Lifecycle

1. **Step 1: Batch Generation & Validation**: Prints a progress bar `[██████████████████] 100.0%` as it synthesizes the 20 SpeechSamples. If files already exist in `demo_audio_dataset/`, it quickly skips them via resumability caching.
2. **Step 2: Specification Audit Table**: Outputs a formatted console table listing the sample number, text, rate (16000Hz), channels (1), bit depth (16-bit), duration, status (PASS/FAIL), and note tags.
3. **Step 3: Interactive Player**: Prompts the user to selectively play WAV files by typing numbers (1-20) or navigating via `n` (next), `p` (previous), and `r` (replay).

---

## 4. Troubleshooting
- **No Sound Output (winsound warning)**: The demo uses Python's built-in `winsound` library to play WAVs on Windows. On non-Windows platforms, audio playback will be bypassed (printing a warning), but the batch generation and spec validation steps will still run and pass cleanly.
- **Different WAV Lengths/Hashes**: Piper uses stochastic noise models. Regenerating audio for the same phrase will produce slightly different frame counts and binary SHA-256 hashes, which is expected.
