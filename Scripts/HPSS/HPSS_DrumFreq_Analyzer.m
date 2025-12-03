%% ============================================================
%% HPSS_DrumFrequency_Analyzer.m
%% 
%% 원본 음악에서 HPSS로 Percussive 추출 → 드럼 주파수 분석
%% 결과를 kick_removal 코드에 복붙해서 사용
%% ============================================================

clear; clc;

%% STEP 0 — Load Original Audio
input_path = "F:\GitHub\DrumRemoval_DSP\OriginalSongs\ZZZ Camillia Golden Week OST_ CityDay [Zenless Zone Zero].mp3";

[x, fs] = audioread(input_path);
x = mean(x, 2);

fprintf("=== HPSS Drum Frequency Analyzer ===\n");
fprintf("Loaded: %.2f sec @ %d Hz\n\n", length(x)/fs, fs);

%% STEP 1 — STFT
win_len = 2048;
hop     = 512;
nfft    = 4096;
win     = hann(win_len, "periodic");
overlap = win_len - hop;

[S, f, t] = stft(x, fs, "Window", win, "OverlapLength", overlap, "FFTLength", nfft);
magS = abs(S);
eps_val = 1e-9;

%% STEP 2 — HPSS로 Percussive 추출
fprintf("=== HPSS Separation ===\n");

time_win = 15;  % HPSS_v2.m과 동일
freq_win = 15;

H = medfilt1(magS, time_win, [], 2);   % Harmonic
P = medfilt1(magS, freq_win, [], 1);   % Percussive

P_mask = P ./ (H + P + eps_val);
magP = magS .* P_mask;  % Percussive 스펙트럼 (드럼만!)

fprintf("Percussive extraction complete.\n\n");

%% STEP 3 — 평균 Percussive 스펙트럼 계산
avg_perc = mean(magP, 2);  % 시간축 평균
avg_perc_norm = avg_perc / max(avg_perc);

%% STEP 4 — 주파수 대역별 피크 검출
fprintf("=== Auto-detected Drum Frequencies ===\n\n");

% --- KICK (20-300 Hz) ---
kick_range = (f >= 20 & f <= 300);
kick_spectrum = avg_perc_norm;
kick_spectrum(~kick_range) = 0;

[kick_peaks, kick_locs] = findpeaks(kick_spectrum, ...
    'MinPeakHeight', 0.2, ...
    'MinPeakProminence', 0.05, ...
    'SortStr', 'descend');

fprintf("KICK (20-300 Hz):\n");
if ~isempty(kick_locs)
    num_show = min(3, length(kick_locs));
    for i = 1:num_show
        fprintf("  Peak %d: %.1f Hz (magnitude: %.3f)\n", i, f(kick_locs(i)), kick_peaks(i));
    end
    kick_center = f(kick_locs(1));
    kick_low = kick_center * 0.5;
    kick_high = kick_center * 2.0;
    fprintf("  → 추천 대역: [%.0f - %.0f Hz]\n\n", kick_low, kick_high);
else
    kick_low = 40; kick_high = 150;
    fprintf("  피크 없음. Fallback: [40 - 150 Hz]\n\n");
end

% --- SNARE BODY (150-500 Hz) ---
snare_range = (f >= 150 & f <= 500);
snare_spectrum = avg_perc_norm;
snare_spectrum(~snare_range) = 0;

[snare_peaks, snare_locs] = findpeaks(snare_spectrum, ...
    'MinPeakHeight', 0.15, ...
    'MinPeakProminence', 0.03, ...
    'SortStr', 'descend');

fprintf("SNARE BODY (150-500 Hz):\n");
if ~isempty(snare_locs)
    num_show = min(3, length(snare_locs));
    for i = 1:num_show
        fprintf("  Peak %d: %.1f Hz (magnitude: %.3f)\n", i, f(snare_locs(i)), snare_peaks(i));
    end
    snare_center = f(snare_locs(1));
    snare_low = snare_center * 0.6;
    snare_high = snare_center * 2.0;
    fprintf("  → 추천 대역: [%.0f - %.0f Hz]\n\n", snare_low, snare_high);
else
    snare_low = 150; snare_high = 400;
    fprintf("  피크 없음. Fallback: [150 - 400 Hz]\n\n");
end

% --- HI-HAT / SNARE WIRE (2-16 kHz) ---
hihat_range = (f >= 2000 & f <= 16000);
hihat_spectrum = avg_perc_norm;
hihat_spectrum(~hihat_range) = 0;

[hihat_peaks, hihat_locs] = findpeaks(hihat_spectrum, ...
    'MinPeakHeight', 0.08, ...
    'MinPeakProminence', 0.02, ...
    'SortStr', 'descend');

fprintf("HI-HAT / SNARE WIRE (2-16 kHz):\n");
if ~isempty(hihat_locs)
    num_show = min(5, length(hihat_locs));
    for i = 1:num_show
        fprintf("  Peak %d: %.1f Hz (magnitude: %.3f)\n", i, f(hihat_locs(i)), hihat_peaks(i));
    end
    hihat_low = min(f(hihat_locs)) * 0.7;
    hihat_high = max(f(hihat_locs)) * 1.3;
    fprintf("  → 추천 대역: [%.0f - %.0f Hz]\n\n", hihat_low, hihat_high);
else
    hihat_low = 5000; hihat_high = 16000;
    fprintf("  피크 없음. Fallback: [5000 - 16000 Hz]\n\n");
end

%% ============================================================
%% 결과 출력: kick_removal 코드에 복붙할 값
%% ============================================================
fprintf("==================================================\n");
fprintf("=== kick_removal 코드에 넣을 값 (복사해서 붙여넣기) ===\n");
fprintf("==================================================\n\n");

fprintf("kick_band   = (f >= %.0f & f <= %.0f);    %% 킥\n", kick_low, kick_high);
fprintf("snare_band  = (f >= %.0f & f <= %.0f);   %% 스네어 바디\n", snare_low, snare_high);
fprintf("hihat_band  = (f >= %.0f & f <= %.0f);  %% 하이햇\n", hihat_low, hihat_high);

%% STEP 5 — Visualization
figure('Position', [100, 100, 1200, 800]);

% 1. 전체 스펙트럼 (log scale)
subplot(2,1,1);
semilogx(f(f > 0), avg_perc_norm(f > 0), 'b-', 'LineWidth', 1.5);
hold on;

% 피크 표시
if ~isempty(kick_locs)
    scatter(f(kick_locs), kick_peaks, 100, 'r', 'filled', 'DisplayName', 'Kick');
end
if ~isempty(snare_locs)
    scatter(f(snare_locs), snare_peaks, 100, 'g', 'filled', 'DisplayName', 'Snare');
end
if ~isempty(hihat_locs)
    scatter(f(hihat_locs), hihat_peaks, 80, 'm', 'filled', 'DisplayName', 'Hi-hat');
end

xlim([20, 20000]);
xlabel('Frequency (Hz)');
ylabel('Normalized Magnitude');
title('Average Percussive Spectrum (HPSS) - Full Range');
legend('Location', 'best');
grid on;

% 2. 저주파 디테일 (0-1000 Hz)
subplot(2,1,2);
low_mask = (f <= 1000 & f > 0);
plot(f(low_mask), avg_perc_norm(low_mask), 'b-', 'LineWidth', 1.5);
hold on;

% 검출된 대역 표시
xline(kick_low, 'r--', 'LineWidth', 2);
xline(kick_high, 'r--', 'LineWidth', 2);
xline(snare_low, 'g--', 'LineWidth', 2);
xline(snare_high, 'g--', 'LineWidth', 2);

% 피크 표시
if ~isempty(kick_locs)
    valid_kick = kick_locs(f(kick_locs) <= 1000);
    scatter(f(valid_kick), avg_perc_norm(valid_kick), 100, 'r', 'filled');
end
if ~isempty(snare_locs)
    valid_snare = snare_locs(f(snare_locs) <= 1000);
    scatter(f(valid_snare), avg_perc_norm(valid_snare), 100, 'g', 'filled');
end

xlim([0, 1000]);
xlabel('Frequency (Hz)');
ylabel('Normalized Magnitude');
title('Percussive Spectrum (0-1000 Hz) - Kick & Snare Detail');
legend('Spectrum', 'Kick band', '', 'Snare band', 'Location', 'best');
grid on;

saveas(gcf, 'F:\GitHub\DrumRemoval_DSP\Graphs\HPSS_DrumFrequency_Analysis.png');
fprintf("\n그래프 저장: HPSS_DrumFrequency_Analysis.png\n");