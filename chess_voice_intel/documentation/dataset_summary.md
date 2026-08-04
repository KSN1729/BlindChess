# Demo Dataset Summary

This document presents a summary of the generated 110-sample speech audio demonstration dataset.

---

## 1. Dataset Statistics

- **Total Samples**: 110
- **Total Duration**: 163.477 seconds
- **Average Duration**: 1.486 seconds
- **Disk Footprint (Audio)**: **4.32 MB** (excluding JSON metadata files).
- **Disk Footprint (Total)**: **4.45 MB** (including JSON metadata sidecars).

---

## 2. Voice & Audio Parameters

- **Voice Model**: `en_US-lessac-medium.onnx` (Piper ONNX)
- **Sample Rate**: 16,000 Hz (16 kHz)
- **Channels**: 1 (mono)
- **Bit Depth**: 16-bit PCM WAV

---

## 3. Validation Results
- **Audio Validation Success Rate**: **100.00%** (110 / 110 validated successfully).
- **Validation Criteria**:
  - Sample rate matches exactly 16000Hz.
  - Channels count matches exactly 1 (mono).
  - Bit depth matches exactly 16-bit PCM.
  - Duration is over 0.2 seconds.
  - No silence (max amplitude > 10).
  - No clipping (clipping rate < 5%).
  - Cryptographic checksum matches stored metadata JSON sidecar.
