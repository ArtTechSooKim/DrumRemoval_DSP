%% ============================================================
%% HPSS_v3.m — Enhanced Multi-Pass HPSS with Margin Masking
%% ============================================================
%% 개선사항:
%% 1. Multi-pass HPSS (2단계 분리)
%% 2. Margin 기반 Hard Mask (더 공격적인 분리)
%% 3. 저주파 베이스 보존 처리
%% 4. 트랜지언트 감쇠 추가
%% ============================================================

clear; clc;

%% STEP 0 — Load File
input_path  = "F:\GitHub\DrumRemoval_DSP\FilteredSong\HPSS\CityDay_HPSS_noDrums_v3_x9.wav";
out_harm    = "F:\GitHub\DrumRemoval_DSP\FilteredSong\HPSS\CityDay_HPSS_harm_v3_x10.wav";
out_perc    = "F:\GitHub\DrumRemoval_DSP\FilteredSong\HPSS\CityDay_HPSS_perc_v3_x10.wav";
out_nodrum  = "F:\GitHub\DrumRemoval_DSP\FilteredSong\HPSS\CityDay_HPSS_noDrums_v3_x10.wav";

[x, fs] = audioread(input_path);
x = mean(x, 2);  % mono

fprintf("Loaded: %.2f sec @ %d Hz\n", length(x)/fs, fs);

%% STEP 1 — STFT Parameters
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
phaseS = angle(S);

fprintf("STFT shape: %d freq × %d time\n", length(f), length(t));

%% ===============================
%% PASS 1: Coarse HPSS (큰 윈도우)
%% ===============================
fprintf("\n=== PASS 1: Coarse Separation ===\n");

time_win1 = 31;   % 홀수로 설정 (median filter 요구사항)
freq_win1 = 31;

H1 = medfilt1(magS, time_win1, [], 2);   % time-direction smoothing
P1 = medfilt1(magS, freq_win1, [], 1);   % freq-direction smoothing

%% ===============================
%% PASS 2: Fine HPSS (작은 윈도우)
%% ===============================
fprintf("=== PASS 2: Fine Separation ===\n");

time_win2 = 11;
freq_win2 = 11;

H2 = medfilt1(magS, time_win2, [], 2);
P2 = medfilt1(magS, freq_win2, [], 1);

% 두 패스 결합 (가중 평균)
alpha = 0.6;  % coarse 패스 가중치
H = alpha * H1 + (1 - alpha) * H2;
P = alpha * P1 + (1 - alpha) * P2;

%% ===============================
%% Margin-based Hard Masking
%% ===============================
fprintf("=== Applying Margin Mask ===\n");

% margin: H와 P의 비율 차이가 클수록 확실한 분리
% margin > 1: 하모닉 확실
% margin < 1: 퍼커시브 확실
eps_val = 1e-9;

margin = 2.0;  % 마진 파라미터 (클수록 공격적)

ratio = H ./ (P + eps_val);

% Soft mask with margin enhancement
H_mask = (ratio .^ margin) ./ ((ratio .^ margin) + 1);
P_mask = 1 ./ ((ratio .^ margin) + 1);

% 추가: 매우 낮은 P 영역은 완전히 Harmonic으로
H_mask(ratio > 3) = 1.0;
P_mask(ratio > 3) = 0.0;

% 매우 높은 P 영역은 완전히 Percussive로
H_mask(ratio < 0.33) = 0.0;
P_mask(ratio < 0.33) = 1.0;

%% ===============================
%% 저주파 베이스 보존 (40-100Hz)
%% ===============================
fprintf("=== Bass Preservation ===\n");

bass_idx = (f >= 30 & f <= 80);
bass_boost = 0.7;  % 베이스 영역 harmonic mask 보강

H_mask(bass_idx, :) = max(H_mask(bass_idx, :), bass_boost);
P_mask(bass_idx, :) = min(P_mask(bass_idx, :), 1 - bass_boost);

%% ===============================
%% 하이햇 영역 추가 억제 (8-16kHz)
%% ===============================
fprintf("=== Hi-hat Suppression ===\n");

hihat_idx = (f >= 8000 & f <= 16000);
hihat_suppress = 1.3;  % 하이햇 영역 percussive mask 강화

P_mask(hihat_idx, :) = min(P_mask(hihat_idx, :) * hihat_suppress, 1.0);
H_mask(hihat_idx, :) = max(1 - P_mask(hihat_idx, :), 0);

%% ===============================
%% Apply Masks
%% ===============================
S_harm = magS .* H_mask .* exp(1j * phaseS);
S_perc = magS .* P_mask .* exp(1j * phaseS);

%% ===============================
%% iSTFT (with real + length fix)
%% ===============================
fprintf("=== Inverse STFT ===\n");

x_harm = real(istft(S_harm, fs, "Window", win, "OverlapLength", overlap, "FFTLength", nfft));
x_perc = real(istft(S_perc, fs, "Window", win, "OverlapLength", overlap, "FFTLength", nfft));

L = length(x);
x_harm = fix_length(x_harm, L);
x_perc = fix_length(x_perc, L);

%% ===============================
%% Transient Suppression (시간 도메인)
%% ===============================
fprintf("=== Transient Suppression ===\n");

% Envelope follower로 급격한 트랜지언트 감쇠
env_win = round(0.005 * fs);  % 5ms 윈도우
env = movmean(abs(x_harm), env_win);
env_smooth = movmean(env, env_win * 10);  % 더 부드러운 envelope

% 트랜지언트 비율 계산
transient_ratio = env ./ (env_smooth + eps_val);
transient_ratio = min(transient_ratio, 3.0);  % 최대 3배로 제한

% 급격한 트랜지언트 억제 (ratio가 높으면 드럼일 가능성)
suppress_factor = 1 ./ (1 + 0.3 * (transient_ratio - 1));
x_nodrum = x_harm .* suppress_factor;

%% ===============================
%% Volume Boost (C 방식 개선)
%% ===============================
fprintf("=== Volume Normalization ===\n");

% Step 1: Gain
gain = 4.0;
y = x_nodrum * gain;

% Step 2: RMS normalization
target_rms = 0.22;
current_rms = sqrt(mean(y.^2));
y = y * (target_rms / current_rms);

% Step 3: Soft Limiter (tanh 기반)
limit = 0.95;
y = limit * tanh(y / limit);

x_nodrum_final = y;

%% ===============================
%% Normalize harm/perc for reference
%% ===============================
x_harm = x_harm / max(abs(x_harm) + eps_val) * 0.95;
x_perc = x_perc / max(abs(x_perc) + eps_val) * 0.95;

%% ===============================
%% Save Files
%% ===============================
audiowrite(out_harm,   x_harm,         fs);
audiowrite(out_perc,   x_perc,         fs);
audiowrite(out_nodrum, x_nodrum_final, fs);

fprintf("\n=== HPSS v3 DONE ===\n");
fprintf("Harmonic   → %s\n", out_harm);
fprintf("Percussive → %s\n", out_perc);
fprintf("No-Drums   → %s\n", out_nodrum);

%% ===============================
%% Statistics
%% ===============================
fprintf("\n=== Output Statistics ===\n");
fprintf("No-Drums RMS: %.4f\n", sqrt(mean(x_nodrum_final.^2)));
fprintf("No-Drums Max: %.4f\n", max(abs(x_nodrum_final)));

%% ===============================
%% Length Fix Function
%% ===============================
function y = fix_length(y, L)
    if length(y) > L
        y = y(1:L);
    else
        y = [y; zeros(L - length(y), 1)];
    end
end