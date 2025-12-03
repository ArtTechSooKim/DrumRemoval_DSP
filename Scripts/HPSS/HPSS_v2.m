%% ============================================================
%% HPSS_v2.m — Harmonic/Percussive Separation + Booster
%% ============================================================

clear; clc;

%% STEP 0 — Load File
input_path  = "F:\GitHub\DrumRemoval_DSP\OriginalSongs\ZZZ Camillia Golden Week OST_ CityDay [Zenless Zone Zero].mp3";
out_harm    = "F:\GitHub\DrumRemoval_DSP\FilteredSong\HPSS\CityDay_HPSS_harm_v2.wav";
out_perc    = "F:\GitHub\DrumRemoval_DSP\FilteredSong\HPSS\CityDay_HPSS_perc_v2.wav";
out_nodrum  = "F:\GitHub\DrumRemoval_DSP\FilteredSong\HPSS\CityDay_HPSS_noDrums_v2.wav";

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
%% HPSS Processing (Median Filter)
%% ===============================

time_win = 15;
freq_win = 15;

H = medfilt1(magS, time_win, [], 2);   % time-direction
P = medfilt1(magS, freq_win, [], 1);   % freq-direction

eps_val = 1e-9;

H_mask = H ./ (H + P + eps_val);
P_mask = P ./ (H + P + eps_val);

S_harm = S .* H_mask;
S_perc = S .* P_mask;

%% ===============================
%% iSTFT (with real + length fix)
%% ===============================
x_harm = real( istft(S_harm, fs, "Window", win, "OverlapLength", overlap, "FFTLength", nfft) );
x_perc = real( istft(S_perc, fs, "Window", win, "OverlapLength", overlap, "FFTLength", nfft) );

L = length(x);
x_harm = fix_length(x_harm, L);
x_perc = fix_length(x_perc, L);

x_nodrum = x_harm;     % harmonic = no drums

%% ========================================
%% STEP X — BOOST MIX (A/B/C 옵션 제공)
%% ========================================

%% ----------------------------------------
%% (A) HARD GAIN BOOST (DEFAULT: ENABLED)
%% ----------------------------------------

% hard_gain = 10.0;   % 크면 클수록 전체 볼륨 증가 (5~20 추천)
% y = x_nodrum * hard_gain;
% 
% % Soft limiter to prevent clipping
% limit = 0.95;
% y(y >  limit) =  limit;
% y(y < -limit) = -limit;


%% ----------------------------------------
%% (B) RMS NORMALIZATION (DISABLED)
%% ----------------------------------------
% 
% target_rms = 0.20;
% current_rms = sqrt(mean(x_nodrum.^2));
% 
% gain_factor = target_rms / current_rms;
% 
% y = x_nodrum * gain_factor;
% 

%% ----------------------------------------
%% (C) HARD GAIN + RMS + LIMITER COMBO (DISABLED)
%% ----------------------------------------
gain = 5.0;
z = x_nodrum * gain;

% RMS normalize
target_rms = 0.25;
current_rms = sqrt(mean(z.^2));
z = z * (target_rms / current_rms);

% Limiter
limit2 = 0.95;
z(z >  limit2) =  limit2;
z(z < -limit2) = -limit2;

% 최종 출력은 y
y = z;

%% Save boosted no-drum version
x_nodrum_boost = y;

%% ===============================
%% Normalize harm/percussive only
%% ===============================
x_harm = x_harm / max(abs(x_harm) + eps_val) * 0.95;
x_perc = x_perc / max(abs(x_perc) + eps_val) * 0.95;

%% ===============================
%% Save Files
%% ===============================
audiowrite(out_harm,   x_harm,         fs);
audiowrite(out_perc,   x_perc,         fs);
audiowrite(out_nodrum, x_nodrum_boost, fs);

fprintf("\n=== HPSS v2 DONE ===\n");
fprintf("Harmonic  → %s\n", out_harm);
fprintf("Percussive→ %s\n", out_perc);
fprintf("No-Drums  → %s\n", out_nodrum);

%% ===============================
%% Length Fix Function
%% ===============================
function y = fix_length(y, L)
    if length(y) > L
        y = y(1:L);
    else
        y = [y; zeros(L-length(y),1)];
    end
end
