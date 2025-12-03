%% ============================================================
%% JustRemoveFullDrum.m
%% Full Drum Removal (Brutal Punch-Out Filter)
%%
%% 목적:
%% - 분석된 모든 드럼 주파수 대역을 직접 0으로 설정
%% - 음악 손상 상관 없음
%% ============================================================

clear; clc;

%% STEP 0 — Load File
input_path = "F:\GitHub\DrumRemoval_DSP\OriginalSongs\ZZZ Camillia Golden Week OST_ CityDay [Zenless Zone Zero].mp3";
output_path = "F:\GitHub\DrumRemoval_DSP\FilteredSong\CityDay_full_drum_removed_BRUTAL.wav";

[x, fs] = audioread(input_path);
x = mean(x,2);
fprintf("Loaded %.2f sec audio @ %d Hz\n", length(x)/fs, fs);

%% STEP 1 — STFT
win_len = 2048;
hop = 512;
nfft = 4096;
win = hann(win_len);
overlap = win_len - hop;

[S, f, t] = stft(x, fs, ...
    'Window', win, ...
    'OverlapLength', overlap, ...
    'FFTLength', nfft);

fprintf("STFT Complete: %d freq bins × %d frames\n", length(f), length(t));

%% STEP 2 — Brutal Zeroing of Drum Frequencies
% 드럼 중심 대역만 제거
kick_band   = (f >= 40  & f <= 150);    % 킥 펀더멘탈
snare_band  = (f >= 150 & f <= 350);    % 스네어 바디
wire_band   = (f >= 3000 & f <= 8000);  % 스네어 와이어 + 일부 HH
hihat_band  = (f >= 9000 & f <= 18000); % 하이햇

drum_mask = kick_band | snare_band | wire_band | hihat_band;
fprintf("Zeroing %d / %d freq bins (%.1f%% of spectrum)\n", ...
    sum(drum_mask), length(f), 100 * sum(drum_mask)/length(f));

% Apply brutal removal
S_filtered = S;
S_filtered(drum_mask, :) = 0;

%% STEP 3 — iSTFT
x_filtered = istft(S_filtered, fs, ...
    'Window', win, ...
    'OverlapLength', overlap, ...
    'FFTLength', nfft);

x_filtered = real(x_filtered);

% Length fix
if length(x_filtered) > length(x)
    x_filtered = x_filtered(1:length(x));
end


%% STEP 4 — Save

audiowrite(output_path, x_filtered, fs);

fprintf("Saved: %s\n", output_path);