# DrumRemoval_DSP  
### MATLAB Digital Signal Processing Project for Full Drum Removal

This project implements a custom **digital signal processing (DSP) pipeline** in MATLAB designed to remove **full drum components**—kick, snare, toms, and cymbals—from mixed music signals.  
It uses **transient detection, spectral decomposition, harmonic suppression, and adaptive gain shaping** to isolate and suppress percussive elements without significantly damaging the harmonic content of the music.

---

## 🎧 **Project Overview**

Modern music mixes often have tightly compressed and layered drum tracks that are difficult to remove without damaging the rest of the audio.  
This project explores a multi-stage DSP approach to suppress drum energy using:

- **STFT-based spectral analysis**  
- **Transient (attack) detection**  
- **Adaptive envelope shaping**  
- **Harmonic cancellation and notch filtering**  
- **Dynamic gain filtering**  
- **Spectrogram comparison and evaluation**

The goal is to design an algorithmic method to isolate and subtract drum elements while preserving the rest of the track as much as possible.

---

## 📁 **Repository Structure**

DrumRemoval_DSP/
│
├── src/ # MATLAB source code (algorithm, functions, scripts)
├── audio_original/ # Original songs used for testing
├── audio_filtered/ # Output audio after drum removal
├── images/ # Spectrograms, waveform comparisons, etc.
├── docs/ # Research notes, algorithm flow, explanations
│
├── README.md
├── LICENSE (MIT)
└── .gitignore

yaml
코드 복사

You may need to create some of these folders locally if they do not exist yet.

---

## 🔧 **Core DSP Techniques Used**

### **1. Transient Detection**
Detect high-energy, short-duration drum attacks using:
- Full-wave rectified envelope  
- Low-pass smoothing  
- Threshold-based peak detection  
- Adaptive attack window estimation  

### **2. Spectral Decomposition**
Use STFT to analyze frequency-time bins:
- Identify drum-dominant regions  
- Detect broadband and metallic components (snare & cymbal)  
- Track low-frequency fundamental & harmonics (kick & toms)

### **3. Harmonic Cancellation**
Suppress harmonics of detected drum hits by:
- Adaptive notch filtering  
- Gain reduction around spectral peaks  
- Local frequency masking

### **4. Adaptive Gain Shaping**
Reduce energy during transient windows without harming non-drum content by:
- Envelope-controlled gain curves  
- Smooth attack/release shapes  
- Multiband shaping (low/mid/high)

---

## 📊 **Results & Evaluation**

Evaluation uses:

- Before/after **spectrogram comparison**  
- Residual drum energy measurement  
- Listening tests  
- Stability and artifact checking  

Spectrogram examples will be uploaded in the `/images` directory.

---

## ▶️ **How to Run**

1. Clone this repository  
2. Open MATLAB  
3. Run the main script (e.g., `drum_removal_main.m`)  
4. Place the input `.wav` file in `audio_original/`  
5. The processed result will be saved in `audio_filtered/`

Requirements:
- MATLAB R2022a or later  
- Signal Processing Toolbox (recommended but not strictly required)

---

## 🧪 **Future Work**

- Multiband Wiener filtering  
- CNN-based drum onset classifier (optional extension)  
- Better cymbal suppression using HF spectral gating  
- Integrating algorithm into Unity (for interactive drumming game)  
- VR Drum practice with Quest 3 (experimental)

---

## 📄 **License**

This project is released under the **MIT License**, allowing free use, modification, and distribution.

---

## ✍️ **Author**

**김수 (Soo Kim)**  
Chung-Ang University – Art & Technology  
Sound Technology Final Project

Feel free to contact me for collaboration or research discussion!