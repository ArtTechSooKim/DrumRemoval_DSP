%% HPSS_v1 - Correct Version (No Drum Zeroing!)

clear; clc;

%% STEP 0 — Load File
input_path  = "F:\GitHub\DrumRemoval_DSP\OriginalSongs\ZZZ Camillia Golden Week OST_ CityDay [Zenless Zone Zero].mp3";
out_harm    = "F:\GitHub\DrumRemoval_DSP\FilteredSong\HPSS\CityDay_HPSS_harm_v1.wav";
out_perc    = "F:\GitHub\DrumRemoval_DSP\FilteredSong\HPSS\CityDay_HPSS_perc_v1.wav";
out_nodrum  = "F:\GitHub\DrumRemoval_DSP\FilteredSong\HPSS\CityDay_HPSS_noDrums_v1.wav";

[x, fs] = audioread(input_path);
x = mean(x, 2);

fprintf("Loaded: %.2f sec @ %d Hz\n", length(x)/fs, fs);

%% STEP 1 — STFT
win_len = 2048;
hop     = 512;
nfft    = 4096;
win     = hann(win_len, "periodic");
overlap = win_len - hop;

[S, f, t] = stft(x, fs, ...
    "Window", win, ...
    "OverlapLength", overlap, ...
    "FFTLength", nfft);

magS = abs(S);

fprintf("STFT shape: %d freq × %d time\n", length(f), length(t));

%% ===============================
%% HPSS Processing
%% ===============================

time_win = 15;
freq_win = 15;

H = medfilt1(magS, time_win, [], 2);   % Harmonic: smooth along time (2nd dim)
P = medfilt1(magS, freq_win, [], 1);   % Percussive: smooth along freq (1st dim)

eps_val = 1e-9;

H_mask = H ./ (H + P + eps_val);
P_mask = P ./ (H + P + eps_val);

S_harm = S .* H_mask;
S_perc = S .* P_mask;

%% ===============================
%% iSTFT (real + length fix)
%% ===============================

x_harm = real( istft(S_harm, fs, "Window", win, "OverlapLength", overlap, "FFTLength", nfft) );
x_perc = real( istft(S_perc, fs, "Window", win, "OverlapLength", overlap, "FFTLength", nfft) );

L = length(x);
x_harm = fix_length(x_harm, L);
x_perc = fix_length(x_perc, L);

x_nodrum = x_harm;     % harmonic = no drums


%% ===============================
%% Normalize and Save
%% ===============================
x_harm   = x_harm   / max(abs(x_harm)+eps_val) * 0.95;
x_perc   = x_perc   / max(abs(x_perc)+eps_val) * 0.95;
x_nodrum = x_nodrum / max(abs(x_nodrum)+eps_val) * 0.95;

audiowrite(out_harm,   x_harm, fs);
audiowrite(out_perc,   x_perc, fs);
audiowrite(out_nodrum, x_nodrum, fs);

fprintf("Saved!\n");

%% ===============================
%% Length Fix
%% ===============================
function y = fix_length(y, L)
    if length(y) > L
        y = y(1:L);
    else
        y = [y; zeros(L-length(y), 1)];
    end
end
