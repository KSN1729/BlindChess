# Production Offline Audio Generation Pipeline

This document outlines the architecture, installation, configuration, and limitations of the **Production Offline Audio Generation Pipeline**.

---

## 1. Directory Structure

The offline audio pipeline resides under `c:/FlutterProjects/BlindChess/chess_voice_intel/`:

- `audio_generator.py`: Lazy-loads the Piper ONNX model and resamples raw audio to 16kHz mono.
- `audio_validator.py`: Audits WAV parameters (PCM, bit depth, channel counts) and signals (silence/clipping/truncation).
- `audio_metadata.py`: Computes SHA-256 and writes sidecar metadata JSONs.
- `audio_pipeline.py`: Main driver providing resumable batch generation.
- `piper_voices/`: Directory storing downloaded Piper `.onnx` and `.json` model files.

---

## 2. Piper Installation & Voice Model

### Installation
The pipeline uses the official `piper-tts` package:
```bash
pip install piper-tts
```

### Voice Download
The selected voice is **`en_US-lessac-medium`** (which has an output sample rate of 22050Hz). It is downloaded locally via:
```bash
python -m piper.download_voices --download-dir piper_voices en_US-lessac-medium
```

---

## 3. Resample & Normalization Logic
Since the Piper voice model outputs at **22,050 Hz**, the `AudioGenerator` runs a custom linear interpolation resampler in pure Python (no dependencies, fully Python 3.13 compatible) to downsample the output to the target specification:
- **Format**: WAV
- **Sample Rate**: 16,000 Hz (16 kHz)
- **Channels**: 1 (mono)
- **Bit Depth**: 16-bit PCM

---

## 4. Known Limitations & Scaling Bottlenecks
- **GIL & CPU Contention**: Parallel processing using multiple threads does not scale linearly and can be slower due to thread context-switching and model reloading overhead.
- **Recommendation**: For large-scale generations, load the model once on a single thread or use multi-process workers instead of thread pools.
