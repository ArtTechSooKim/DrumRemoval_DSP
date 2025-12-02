%% ============================================================
%% Kick Drum Removal Prototype v1_1 (Fundamental + Harmonic)
%% ============================================================

%% STEP 0 — Load Audio File
[x, fs] = audioread("OriginalSongs/ZZZ Camillia Golden Week OST_ CityDay [Zenless Zone Zero].mp3");
x = mean(x, 2);

%% STEP 1 — STFT
win = hann(1024);
hop = 512;
nfft = 2048;

[S, f, t] = stft(x, fs, 'Window', win, 'OverlapLength', hop, 'FFTLength', nfft);
magS = abs(S);

%% STEP 2 — Kick Frequency Bands (개선 버전)
% Fundamental (≈97Hz) → 80~120Hz
kick_fund_band = (f >= 80 & f <= 120);    

% Harmonic 2 (193.8Hz) → 170~220Hz
kick_harm_band = (f >= 170 & f <= 220);

% Combined kick band
kick_band = kick_fund_band | kick_harm_band;

%% STEP 3 — Kick Energy Profile
kick_energy = sum(magS(kick_band, :), 1);
kick_norm = kick_energy / max(kick_energy);

%% STEP 4 — Kick detection
atten_strength = 0.7;
kick_mask = kick_norm > 0.35;

%% STEP 5 — Apply attenuation
S_filtered = S;
for i = 1:length(t)
    if kick_mask(i)
        S_filtered(kick_band, i) = S_filtered(kick_band, i) * (1 - atten_strength);
    end
end

%% STEP 6 — iSTFT
x_filtered = istft(S_filtered, fs, ...
    'Window', win, 'OverlapLength', hop, 'FFTLength', nfft);

x_filtered = x_filtered / max(abs(x_filtered));
x_filtered = real(x_filtered);

%% STEP 7 — Save to FilteredSong folder
audiowrite("FilteredSong/CityDay_kick_removed_v1_1.wav", x_filtered, fs);

fprintf("Saved: CityDay_kick_removed_v1_1.wav\n");
