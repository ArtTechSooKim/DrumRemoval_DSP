%% ============================================================
%% HPSS_Guided_DrumRemoval.m
%% 
%% 핵심: Percussive 신호에서 실제 드럼 주파수를 자동 분석!
%% - 하드코딩 없이 이 곡의 드럼 특성을 학습
%% ============================================================

clear; clc;

%% STEP 0 — File Paths
input_path  = "F:\GitHub\DrumRemoval_DSP\OriginalSongs\ZZZ Camillia Golden Week OST_ CityDay [Zenless Zone Zero].mp3";
out_final   = "F:\GitHub\DrumRemoval_DSP\FilteredSong\CityDay_HPSS_Guided.wav";

[x, fs] = audioread(input_path);
x = mean(x, 2);

fprintf("=== HPSS-Guided Drum Removal ===\n");
fprintf("=== Auto Frequency Detection ===\n\n");
fprintf("Loaded: %.2f sec @ %d Hz\n", length(x)/fs, fs);

%% STEP 1 — STFT
win_len = 2048;
hop     = 512;
nfft    = 4096;
win     = hann(win_len, "periodic");
overlap = win_len - hop;

[S, f, t] = stft(x, fs, "Window", win, "OverlapLength", overlap, "FFTLength", nfft);
magS = abs(S);
phaseS = angle(S);
eps_val = 1e-9;

fprintf("STFT: %d freq × %d time frames\n", length(f), length(t));

%% ================================================================
%% PHASE 1: HPSS로 Percussive 성분 추출
%% ================================================================
fprintf("\n=== Phase 1: HPSS Separation ===\n");

H = medfilt1(magS, 31, [], 2);
P = medfilt1(magS, 31, [], 1);

P_mask = P ./ (H + P + eps_val);
magP = magS .* P_mask;  % 드럼만 있는 스펙트럼!

fprintf("Percussive extraction complete.\n");

%% ================================================================
%% PHASE 2: Percussive 스펙트럼에서 드럼 주파수 자동 분석
%% ================================================================
fprintf("\n=== Phase 2: Auto Drum Frequency Analysis ===\n");

% --- 2.1 Onset 검출 (드럼 히트 순간 찾기) ---
% Spectral flux: 프레임 간 에너지 변화량
spectral_flux = sum(max(diff(magP, 1, 2), 0), 1);
spectral_flux = [0, spectral_flux];  % 길이 맞추기
spectral_flux_norm = spectral_flux / max(spectral_flux + eps_val);

% Onset threshold (상위 20%를 드럼 히트로)
onset_thresh = prctile(spectral_flux_norm, 80);
[onset_peaks, onset_locs] = findpeaks(spectral_flux_norm, ...
    'MinPeakHeight', onset_thresh, ...
    'MinPeakDistance', round(0.05 * fs / hop));  % 최소 50ms 간격

fprintf("  Detected %d drum onsets\n", length(onset_locs));

% --- 2.2 드럼 히트 순간의 스펙트럼 수집 ---
% 각 onset에서의 주파수 스펙트럼을 모아서 분석
drum_spectra = zeros(length(f), length(onset_locs));
for i = 1:length(onset_locs)
    drum_spectra(:, i) = magP(:, onset_locs(i));
end

% 평균 드럼 스펙트럼
avg_drum_spectrum = mean(drum_spectra, 2);
avg_drum_spectrum_norm = avg_drum_spectrum / max(avg_drum_spectrum);

% --- 2.3 주파수 대역별 피크 자동 검출 ---
fprintf("\n  === Auto-detected Drum Frequencies ===\n");

% 저주파 영역 (20-300Hz) - 킥 + 스네어 바디
low_freq_range = (f >= 20 & f <= 300);
low_spectrum = avg_drum_spectrum_norm;
low_spectrum(~low_freq_range) = 0;

[low_peaks, low_locs] = findpeaks(low_spectrum, ...
    'MinPeakHeight', 0.3, ...
    'MinPeakProminence', 0.1);

% 가장 강한 저주파 피크들 = 킥 주파수
if ~isempty(low_locs)
    kick_center_freq = f(low_locs(1));  % 가장 강한 피크
    % 피크 주변으로 대역 설정 (±50% bandwidth)
    kick_low = kick_center_freq * 0.5;
    kick_high = kick_center_freq * 2.0;
    fprintf("  KICK: Center=%.1f Hz, Band=[%.1f - %.1f Hz]\n", ...
        kick_center_freq, kick_low, kick_high);
else
    % Fallback
    kick_center_freq = 80;
    kick_low = 40;
    kick_high = 160;
    fprintf("  KICK: (fallback) [%.1f - %.1f Hz]\n", kick_low, kick_high);
end

% 중주파 영역 (200-600Hz) - 스네어 바디
mid_freq_range = (f >= 200 & f <= 600);
mid_spectrum = avg_drum_spectrum_norm;
mid_spectrum(~mid_freq_range) = 0;

[mid_peaks, mid_locs] = findpeaks(mid_spectrum, ...
    'MinPeakHeight', 0.2, ...
    'MinPeakProminence', 0.05);

if ~isempty(mid_locs)
    snare_center_freq = f(mid_locs(1));
    snare_low = snare_center_freq * 0.6;
    snare_high = snare_center_freq * 1.8;
    fprintf("  SNARE BODY: Center=%.1f Hz, Band=[%.1f - %.1f Hz]\n", ...
        snare_center_freq, snare_low, snare_high);
else
    snare_center_freq = 250;
    snare_low = 150;
    snare_high = 450;
    fprintf("  SNARE BODY: (fallback) [%.1f - %.1f Hz]\n", snare_low, snare_high);
end

% 고주파 영역 (2000-20000Hz) - 스네어 와이어 + 하이햇
high_freq_range = (f >= 2000 & f <= 20000);
high_spectrum = avg_drum_spectrum_norm;
high_spectrum(~high_freq_range) = 0;

[high_peaks, high_locs] = findpeaks(high_spectrum, ...
    'MinPeakHeight', 0.15, ...
    'MinPeakProminence', 0.05);

if ~isempty(high_locs)
    % 고주파 피크들의 범위로 대역 설정
    high_freqs = f(high_locs);
    hihat_low = min(high_freqs) * 0.7;
    hihat_high = max(high_freqs) * 1.3;
    hihat_center = mean(high_freqs);
    fprintf("  HI-HAT/WIRE: Center=%.1f Hz, Band=[%.1f - %.1f Hz]\n", ...
        hihat_center, hihat_low, hihat_high);
else
    hihat_low = 5000;
    hihat_high = 16000;
    fprintf("  HI-HAT/WIRE: (fallback) [%.1f - %.1f Hz]\n", hihat_low, hihat_high);
end

%% ================================================================
%% PHASE 3: 드럼 타입별 이벤트 분류
%% ================================================================
fprintf("\n=== Phase 3: Drum Event Classification ===\n");

% 각 onset에서 어떤 드럼인지 분류
kick_band_auto = (f >= kick_low & f <= kick_high);
snare_band_auto = (f >= snare_low & f <= snare_high);
hihat_band_auto = (f >= hihat_low & f <= hihat_high);

kick_events = [];
snare_events = [];
hihat_events = [];

for i = 1:length(onset_locs)
    loc = onset_locs(i);
    spectrum = magP(:, loc);
    
    % 각 대역의 에너지 비율
    kick_energy = sum(spectrum(kick_band_auto));
    snare_energy = sum(spectrum(snare_band_auto));
    hihat_energy = sum(spectrum(hihat_band_auto));
    total_energy = kick_energy + snare_energy + hihat_energy + eps_val;
    
    kick_ratio = kick_energy / total_energy;
    snare_ratio = snare_energy / total_energy;
    hihat_ratio = hihat_energy / total_energy;
    
    % 가장 높은 비율의 드럼 타입으로 분류
    [~, drum_type] = max([kick_ratio, snare_ratio, hihat_ratio]);
    
    switch drum_type
        case 1
            kick_events = [kick_events, loc];
        case 2
            snare_events = [snare_events, loc];
        case 3
            hihat_events = [hihat_events, loc];
    end
end

fprintf("  Classified: %d kicks, %d snares, %d hi-hats\n", ...
    length(kick_events), length(snare_events), length(hihat_events));

%% ================================================================
%% PHASE 4: 자동 검출된 주파수로 정밀 마스킹
%% ================================================================
fprintf("\n=== Phase 4: Precision Masking with Auto-detected Frequencies ===\n");

S_filtered = S;

% 감쇠 파라미터
kick_atten = 0.90;
snare_atten = 0.85;
hihat_atten = 0.80;

% Spread (프레임 단위)
spread_kick = 3;
spread_snare = 2;
spread_hihat = 1;

% --- 킥 마스킹 (자동 검출된 주파수 사용) ---
for idx = 1:length(kick_events)
    center = kick_events(idx);
    start_frame = max(1, center - spread_kick);
    end_frame = min(length(t), center + spread_kick);
    
    for fr = start_frame:end_frame
        dist = abs(fr - center);
        weight = kick_atten * exp(-0.5 * (dist / spread_kick)^2);
        S_filtered(kick_band_auto, fr) = S_filtered(kick_band_auto, fr) * (1 - weight);
    end
end
fprintf("  Kick masking: %d events in [%.0f-%.0f Hz]\n", ...
    length(kick_events), kick_low, kick_high);

% --- 스네어 마스킹 ---
for idx = 1:length(snare_events)
    center = snare_events(idx);
    start_frame = max(1, center - spread_snare);
    end_frame = min(length(t), center + spread_snare);
    
    for fr = start_frame:end_frame
        dist = abs(fr - center);
        weight = snare_atten * exp(-0.5 * (dist / spread_snare)^2);
        S_filtered(snare_band_auto, fr) = S_filtered(snare_band_auto, fr) * (1 - weight);
    end
end
fprintf("  Snare masking: %d events in [%.0f-%.0f Hz]\n", ...
    length(snare_events), snare_low, snare_high);

% --- 하이햇 마스킹 ---
for idx = 1:length(hihat_events)
    center = hihat_events(idx);
    start_frame = max(1, center - spread_hihat);
    end_frame = min(length(t), center + spread_hihat);
    
    for fr = start_frame:end_frame
        dist = abs(fr - center);
        weight = hihat_atten * exp(-0.5 * (dist / spread_hihat)^2);
        S_filtered(hihat_band_auto, fr) = S_filtered(hihat_band_auto, fr) * (1 - weight);
    end
end
fprintf("  Hi-hat masking: %d events in [%.0f-%.0f Hz]\n", ...
    length(hihat_events), hihat_low, hihat_high);

%% ================================================================
%% PHASE 5: Residual HPSS 보정
%% ================================================================
fprintf("\n=== Phase 5: Residual HPSS Cleanup ===\n");

magS_filtered = abs(S_filtered);
phaseS_filtered = angle(S_filtered);

H2 = medfilt1(magS_filtered, 21, [], 2);
P2 = medfilt1(magS_filtered, 21, [], 1);

margin = 3.0;
ratio = H2 ./ (P2 + eps_val);
H_mask_final = (ratio .^ margin) ./ ((ratio .^ margin) + 1);

blend = 0.4;
final_mask = blend * H_mask_final + (1 - blend);

S_final = magS_filtered .* final_mask .* exp(1j * phaseS_filtered);

%% ================================================================
%% PHASE 6: iSTFT 및 후처리
%% ================================================================
fprintf("\n=== Phase 6: Reconstruction ===\n");

x_filtered = real(istft(S_final, fs, ...
    "Window", win, "OverlapLength", overlap, "FFTLength", nfft));

L = length(x);
x_filtered = fix_length(x_filtered, L);

% Volume boost
gain = 3.5;
y = x_filtered * gain;

target_rms = 0.22;
current_rms = sqrt(mean(y.^2));
y = y * (target_rms / current_rms);

limit = 0.95;
y = limit * tanh(y / limit);

%% ================================================================
%% STEP 7: Save Output
%% ================================================================
audiowrite(out_final, y, fs);

fprintf("\n========================================\n");
fprintf("=== HPSS-Guided Drum Removal Complete ===\n");
fprintf("========================================\n");
fprintf("Output: %s\n", out_final);
fprintf("\nAuto-detected frequencies:\n");
fprintf("  KICK:   [%.0f - %.0f Hz]\n", kick_low, kick_high);
fprintf("  SNARE:  [%.0f - %.0f Hz]\n", snare_low, snare_high);
fprintf("  HI-HAT: [%.0f - %.0f Hz]\n", hihat_low, hihat_high);

%% ================================================================
%% Visualization
%% ================================================================
figure('Position', [100, 100, 1400, 900]);

% 1. 평균 드럼 스펙트럼 (자동 검출 결과)
subplot(2,2,1);
plot(f, avg_drum_spectrum_norm, 'b', 'LineWidth', 1.5);
hold on;
xline(kick_low, 'r--', 'LineWidth', 1.5);
xline(kick_high, 'r--', 'LineWidth', 1.5);
xline(snare_low, 'g--', 'LineWidth', 1.5);
xline(snare_high, 'g--', 'LineWidth', 1.5);
xline(hihat_low, 'm--', 'LineWidth', 1.5);
xline(hihat_high, 'm--', 'LineWidth', 1.5);
xlim([0, 20000]);
xlabel('Frequency (Hz)');
ylabel('Normalized Magnitude');
title('Auto-detected Drum Spectrum (R=Kick, G=Snare, M=HiHat)');
set(gca, 'XScale', 'log');
grid on;

% 2. Drum events timeline
subplot(2,2,2);
stem(t(kick_events), ones(size(kick_events)), 'r', 'Marker', 'none', 'LineWidth', 1.5);
hold on;
stem(t(snare_events), 0.7*ones(size(snare_events)), 'g', 'Marker', 'none', 'LineWidth', 1.5);
stem(t(hihat_events), 0.4*ones(size(hihat_events)), 'm', 'Marker', 'none', 'LineWidth', 1);
xlim([0, min(30, t(end))]);
ylim([0, 1.2]);
xlabel('Time (s)');
ylabel('Event Type');
title('Detected Drum Events (first 30s)');
legend('Kick', 'Snare', 'Hi-hat', 'Location', 'best');

% 3. Original low-freq
subplot(2,2,3);
imagesc(t, f(f <= 500), 20*log10(magS(f <= 500, :) + eps_val));
axis xy; colorbar; caxis([-80, 0]);
title('Original (0-500Hz)');
xlabel('Time (s)'); ylabel('Freq (Hz)');

% 4. Filtered low-freq
subplot(2,2,4);
imagesc(t, f(f <= 500), 20*log10(abs(S_final(f <= 500, :)) + eps_val));
axis xy; colorbar; caxis([-80, 0]);
title('Filtered (0-500Hz)');
xlabel('Time (s)'); ylabel('Freq (Hz)');

saveas(gcf, 'F:\GitHub\DrumRemoval_DSP\Graphs\HPSS_Guided_auto_analysis.png');
fprintf("Graph saved!\n");

%% Helper function
function y = fix_length(y, L)
    if length(y) > L
        y = y(1:L);
    else
        y = [y; zeros(L - length(y), 1)];
    end
end