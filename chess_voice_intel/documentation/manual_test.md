# Manual Testing & User Acceptance Guide

This guide provides step-by-step instructions to manually review and verify the generated speech audio dataset using the terminal demo player.

---

## Step 1: Pre-requisites & Model Download
Ensure you have the Piper package installed and the model downloaded locally:
```bash
pip install piper-tts
python -m piper.download_voices --download-dir piper_voices en_US-lessac-medium
```

---

## Step 2: Generate the Demo Dataset
Generate the 110-sample WAV dataset by running:
```bash
python generate_demo_dataset.py
```
This writes the WAV files to `demo_audio_dataset/` and creates the `demo_validation_summary.json` record file.

---

## Step 3: Launch the Interactive Demo Player
Start the terminal audio player:
```bash
python demo_audio_player.py
```

---

## Step 4: Navigation & Verification
- **List Phrases**: Press `l` to view all 110 phrases with their numbers.
- **Play Selectively**: Input a number (e.g. `27`) to jump directly to that phrase and play its audio.
- **Listen & Navigate**: Press `n` for the next sample, `p` for the previous, and `r` to replay.
- **Verify Metadata**: Check that the duration, category, and SHA-256 checksum printed in the terminal align with the audio characteristics.
- **Pronunciation Quality**: Listen for correct coordinate spelling (e.g., e4, f3, a8) and pieces synonyms.
