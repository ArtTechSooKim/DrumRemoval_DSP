%% ============================================================
%% Full Drum Removal v1 - Integrated
%% 
%% 통합 전략:
%% - Kick Removal (v5): 50-120Hz
%% - Snare Removal (v1): 150-300Hz + 3-10kHz
%% - Hi-Hat Removal (v1): 6-20kHz
%% 
%% 처리 순서:
%% 1. 각 드럼 독립적으로 detection
%% 2. STFT에서 모든 드럼 동시 제거
%% 3. 겹치는 대역은 가장 강한 감쇠 적용
%% ============================================================

%% STEP 0 - Load Audio
input_path = "F:\GitHub\DrumRemoval_DSP\OriginalSongs\ZZZ Camillia Golden Week OST_ CityDay [Zenless Zone Zero].mp3";
output_path = "F:\GitHub\DrumRemoval_DSP\FilteredSong\CityDay_all_drums_removed_v1.wav";

[x, fs] = audioread(input_path);
x = mean(x, 2);

fprintf('=== Full Drum Removal v1 ===\n');
fprintf('파일 로드: %.2f초, %dHz\n', length(x)/fs, fs);

%% STEP 1 - STFT Analysis
win_len = 2048;
hop = 512;
nfft = 4096;
win = hann(win_len);
overlap = win_len - hop;

[S, f, t] = stft(x, fs, 'Window', win, 'OverlapLength', overlap, 'FFTLength', nfft);
magS = abs(S);

fprintf('STFT 완료: %d frames x %d freq bins\n', size(S,2), size(S,1));

%% ============================================================
%% STEP 2 - KICK DETECTION (v5 기반)
%% ============================================================
fprintf('\n[1/3] Kick Detection...\n');

% Kick 대역
kick_fund_band = (f >= 50 & f <= 120);
kick_sub_band = (f >= 30 & f <= 50);
kick_click_band = (f >= 1000 & f <= 3000);

% 에너지 계산
energy_kick_fund = sum(magS(kick_fund_band, :), 1);
energy_kick_sub = sum(magS(kick_sub_band, :), 1);
energy_kick_click = sum(magS(kick_click_band, :), 1);

% Normalize
energy_kick_fund_norm = energy_kick_fund / max(energy_kick_fund);
energy_kick_sub_norm = energy_kick_sub / max(energy_kick_sub);
energy_kick_click_norm = energy_kick_click / max(energy_kick_click);

% Kick score
kick_score = 0.6 * energy_kick_fund_norm + ...
             0.2 * energy_kick_sub_norm + ...
             0.2 * energy_kick_click_norm;

% Threshold
kick_threshold = prctile(kick_score, 70);
kick_frames = kick_score > kick_threshold;

fprintf('  킥 프레임: %d/%d (%.1f%%)\n', ...
    sum(kick_frames), length(kick_frames), ...
    100*sum(kick_frames)/length(kick_frames));

%% ============================================================
%% STEP 3 - SNARE DETECTION (v1 기반)
%% ============================================================
fprintf('[2/3] Snare Detection...\n');

% Snare 대역
snare_body_band = (f >= 150 & f <= 300);
snare_mid_band = (f >= 1000 & f <= 3000);
snare_wire_band = (f >= 3000 & f <= 10000);

% 에너지 계산
energy_snare_body = sum(magS(snare_body_band, :), 1);
energy_snare_mid = sum(magS(snare_mid_band, :), 1);
energy_snare_wire = sum(magS(snare_wire_band, :), 1);

% Normalize
energy_snare_body_norm = energy_snare_body / max(energy_snare_body);
energy_snare_mid_norm = energy_snare_mid / max(energy_snare_mid);
energy_snare_wire_norm = energy_snare_wire / max(energy_snare_wire);

% Snare score
snare_score = 0.2 * energy_snare_body_norm + ...
              0.2 * energy_snare_mid_norm + ...
              0.6 * energy_snare_wire_norm;

% Threshold
snare_threshold = prctile(snare_score, 70);
snare_frames = snare_score > snare_threshold;

fprintf('  스네어 프레임: %d/%d (%.1f%%)\n', ...
    sum(snare_frames), length(snare_frames), ...
    100*sum(snare_frames)/length(snare_frames));

%% ============================================================
%% STEP 4 - HI-HAT DETECTION (v1 기반)
%% ============================================================
fprintf('[3/3] Hi-Hat Detection...\n');

% Hi-Hat 대역
hihat_low_band = (f >= 6000 & f <= 10000);
hihat_mid_band = (f >= 10000 & f <= 15000);
hihat_high_band = (f >= 15000 & f <= 20000);

% 에너지 계산
energy_hihat_low = sum(magS(hihat_low_band, :), 1);
energy_hihat_mid = sum(magS(hihat_mid_band, :), 1);
energy_hihat_high = sum(magS(hihat_high_band, :), 1);

% Normalize
energy_hihat_low_norm = energy_hihat_low / max(energy_hihat_low);
energy_hihat_mid_norm = energy_hihat_mid / max(energy_hihat_mid);
energy_hihat_high_norm = energy_hihat_high / max(energy_hihat_high);

% Hi-Hat score
hihat_score = 0.3 * energy_hihat_low_norm + ...
              0.5 * energy_hihat_mid_norm + ...
              0.2 * energy_hihat_high_norm;

% Threshold
hihat_threshold = prctile(hihat_score, 75);
hihat_frames = hihat_score > hihat_threshold;

fprintf('  하이햇 프레임: %d/%d (%.1f%%)\n', ...
    sum(hihat_frames), length(hihat_frames), ...
    100*sum(hihat_frames)/length(hihat_frames));

%% ============================================================
%% STEP 5 - INTEGRATED MULTI-BAND REMOVAL
%% ============================================================
fprintf('\n통합 드럼 제거 처리 중...\n');

S_filtered = S;

% 모든 주파수 대역 정의
% Kick 대역
band_kick_sub = (f >= 25 & f <= 50);
band_kick_fund = (f >= 50 & f <= 130);
band_kick_harm = (f >= 130 & f <= 350);
band_kick_click = (f >= 800 & f <= 3500);

% Snare 대역
band_snare_body = (f >= 150 & f <= 300);
band_snare_body_ext = (f >= 300 & f <= 500);
band_snare_mid = (f >= 1000 & f <= 3000);
band_snare_wire = (f >= 3000 & f <= 10000);
band_snare_wire_high = (f >= 10000 & f <= 15000);

% Hi-Hat 대역
band_hihat_pre = (f >= 5000 & f <= 6000);
band_hihat_low1 = (f >= 6000 & f <= 8000);
band_hihat_low2 = (f >= 8000 & f <= 10000);
band_hihat_mid1 = (f >= 10000 & f <= 12000);
band_hihat_mid2 = (f >= 12000 & f <= 15000);
band_hihat_high1 = (f >= 15000 & f <= 18000);
band_hihat_high2 = (f >= 18000 & f <= 20000);
band_hihat_very_high = (f >= 20000 & f <= 22050);

% 감쇠 강도 (각 악기별)
% Kick
atten_kick_sub = 0.97;
atten_kick_fund = 0.95;
atten_kick_harm = 0.85;
atten_kick_click = 0.88;

% Snare
atten_snare_body = 0.75;
atten_snare_body_ext = 0.60;
atten_snare_mid = 0.80;
atten_snare_wire = 0.92;
atten_snare_wire_high = 0.85;

% Hi-Hat
atten_hihat_pre = 0.50;
atten_hihat_low1 = 0.75;
atten_hihat_low2 = 0.80;
atten_hihat_mid1 = 0.88;
atten_hihat_mid2 = 0.90;
atten_hihat_high1 = 0.93;
atten_hihat_high2 = 0.95;
atten_hihat_very_high = 0.92;

% Frame-by-frame 처리
for i = 1:length(t)
    % KICK 제거
    if kick_frames(i)
        S_filtered(band_kick_sub, i) = S_filtered(band_kick_sub, i) * (1 - atten_kick_sub);
        S_filtered(band_kick_fund, i) = S_filtered(band_kick_fund, i) * (1 - atten_kick_fund);
        S_filtered(band_kick_harm, i) = S_filtered(band_kick_harm, i) * (1 - atten_kick_harm);
        S_filtered(band_kick_click, i) = S_filtered(band_kick_click, i) * (1 - atten_kick_click);
    end
    
    % SNARE 제거
    if snare_frames(i)
        S_filtered(band_snare_body, i) = S_filtered(band_snare_body, i) * (1 - atten_snare_body);
        S_filtered(band_snare_body_ext, i) = S_filtered(band_snare_body_ext, i) * (1 - atten_snare_body_ext);
        S_filtered(band_snare_mid, i) = S_filtered(band_snare_mid, i) * (1 - atten_snare_mid);
        S_filtered(band_snare_wire, i) = S_filtered(band_snare_wire, i) * (1 - atten_snare_wire);
        S_filtered(band_snare_wire_high, i) = S_filtered(band_snare_wire_high, i) * (1 - atten_snare_wire_high);
    end
    
    % HI-HAT 제거
    if hihat_frames(i)
        S_filtered(band_hihat_pre, i) = S_filtered(band_hihat_pre, i) * (1 - atten_hihat_pre);
        S_filtered(band_hihat_low1, i) = S_filtered(band_hihat_low1, i) * (1 - atten_hihat_low1);
        S_filtered(band_hihat_low2, i) = S_filtered(band_hihat_low2, i) * (1 - atten_hihat_low2);
        S_filtered(band_hihat_mid1, i) = S_filtered(band_hihat_mid1, i) * (1 - atten_hihat_mid1);
        S_filtered(band_hihat_mid2, i) = S_filtered(band_hihat_mid2, i) * (1 - atten_hihat_mid2);
        S_filtered(band_hihat_high1, i) = S_filtered(band_hihat_high1, i) * (1 - atten_hihat_high1);
        S_filtered(band_hihat_high2, i) = S_filtered(band_hihat_high2, i) * (1 - atten_hihat_high2);
        S_filtered(band_hihat_very_high, i) = S_filtered(band_hihat_very_high, i) * (1 - atten_hihat_very_high);
    end
end

%% STEP 6 - Spectral Smoothing
fprintf('Spectral smoothing...\n');
for i = 3:size(S_filtered, 2)-2
    S_filtered(:, i) = 0.4 * S_filtered(:, i) + ...
                       0.2 * S_filtered(:, i-1) + ...
                       0.2 * S_filtered(:, i+1) + ...
                       0.1 * S_filtered(:, i-2) + ...
                       0.1 * S_filtered(:, i+2);
end

%% STEP 7 - iSTFT
fprintf('iSTFT 변환 중...\n');
x_filtered = istft(S_filtered, fs, ...
    'Window', win, 'OverlapLength', overlap, 'FFTLength', nfft);

x_filtered = real(x_filtered);

% Length matching
if length(x_filtered) > length(x)
    x_filtered = x_filtered(1:length(x));
elseif length(x_filtered) < length(x)
    x_filtered = [x_filtered; zeros(length(x) - length(x_filtered), 1)];
end

% Normalize
x_filtered = x_filtered / max(abs(x_filtered)) * 0.95;

%% STEP 8 - Save Output
audiowrite(output_path, x_filtered, fs);

fprintf('\n=== Full Drum Removal 완료 ===\n');
fprintf('출력 파일: %s\n', output_path);

%% STEP 9 - Comprehensive Visualization
fprintf('시각화 생성 중...\n');

figure('Position', [100, 100, 1600, 1000]);

% 9-1) Detection Results
subplot(3,3,1);
plot(t, kick_score, 'b', 'LineWidth', 1); hold on;
plot(t, snare_score, 'r', 'LineWidth', 1);
plot(t, hihat_score, 'g', 'LineWidth', 1);
xlim([60, 70]);
xlabel('Time (s)');
ylabel('Detection Score');
title('Drum Detection Scores');
legend('Kick', 'Snare', 'Hi-Hat');
grid on;

% 9-2) Original Spectrogram (Full)
subplot(3,3,2);
imagesc(t, f(f<=10000), 20*log10(magS(f<=10000, :) + eps));
axis xy;
colorbar;
caxis([-80, 0]);
xlim([60, 70]);
title('Original (0-10kHz)');
xlabel('Time (s)');
ylabel('Frequency (Hz)');

% 9-3) Filtered Spectrogram (Full)
subplot(3,3,3);
magS_filt = abs(S_filtered);
imagesc(t, f(f<=10000), 20*log10(magS_filt(f<=10000, :) + eps));
axis xy;
colorbar;
caxis([-80, 0]);
xlim([60, 70]);
title('Filtered (0-10kHz)');
xlabel('Time (s)');
ylabel('Frequency (Hz)');

% 9-4) Low Freq (Kick/Snare Body)
subplot(3,3,4);
imagesc(t, f(f<=500), 20*log10(magS(f<=500, :) + eps));
axis xy;
colorbar;
caxis([-80, 0]);
xlim([60, 70]);
title('Original Low (0-500Hz)');
xlabel('Time (s)');
ylabel('Frequency (Hz)');

% 9-5) Low Freq Filtered
subplot(3,3,5);
imagesc(t, f(f<=500), 20*log10(magS_filt(f<=500, :) + eps));
axis xy;
colorbar;
caxis([-80, 0]);
xlim([60, 70]);
title('Filtered Low (0-500Hz)');
xlabel('Time (s)');
ylabel('Frequency (Hz)');

% 9-6) Spectrum Comparison
subplot(3,3,6);
avg_orig = mean(magS, 2);
avg_filt = mean(magS_filt, 2);
plot(f, 20*log10(avg_orig + eps), 'b', 'LineWidth', 1.5); hold on;
plot(f, 20*log10(avg_filt + eps), 'r', 'LineWidth', 1.5);
xlim([0, 20000]);
ylim([-80, 40]);
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title('Average Spectrum');
legend('Original', 'All Drums Removed');
grid on;

% 9-7) High Freq (Hi-Hat)
subplot(3,3,7);
high_idx = (f >= 5000 & f <= 20000);
imagesc(t, f(high_idx), 20*log10(magS(high_idx, :) + eps));
axis xy;
colorbar;
caxis([-80, 0]);
xlim([60, 70]);
title('Original High (5-20kHz)');
xlabel('Time (s)');
ylabel('Frequency (Hz)');

% 9-8) High Freq Filtered
subplot(3,3,8);
imagesc(t, f(high_idx), 20*log10(magS_filt(high_idx, :) + eps));
axis xy;
colorbar;
caxis([-80, 0]);
xlim([60, 70]);
title('Filtered High (5-20kHz)');
xlabel('Time (s)');
ylabel('Frequency (Hz)');

% 9-9) Drum Detection Mask
subplot(3,3,9);
% 수정: 시간(초)을 프레임 인덱스로 올바르게 변환
frame_start = find(t >= 60, 1);
frame_end = find(t >= 70, 1);
if isempty(frame_end)
    frame_end = length(t);
end

time_axis = 1:length(t);
plot(time_axis(kick_frames), ones(sum(kick_frames),1)*3, 'b.', 'MarkerSize', 5); hold on;
plot(time_axis(snare_frames), ones(sum(snare_frames),1)*2, 'r.', 'MarkerSize', 5);
plot(time_axis(hihat_frames), ones(sum(hihat_frames),1)*1, 'g.', 'MarkerSize', 5);
xlim([frame_start, frame_end]);
ylim([0, 4]);
yticks([1, 2, 3]);
yticklabels({'Hi-Hat', 'Snare', 'Kick'});
xlabel('Frame Index');
title('Detected Drum Events');
grid on;

sgtitle('Full Drum Removal v1 - Comprehensive Analysis');

saveas(gcf, 'F:\GitHub\DrumRemoval_DSP\Graphs\full_drum_removal_v1_result.png');

fprintf('시각화 완료!\n');

%% STEP 10 - 정량 분석
fprintf('\n=== 제거 효과 분석 ===\n');

analysis_bands = {
    'Kick Sub (25-50Hz)', 25, 50;
    'Kick Fund (50-130Hz)', 50, 130;
    'Snare Body (150-300Hz)', 150, 300;
    'Snare Wire (3-10kHz)', 3000, 10000;
    'Hi-Hat Mid (10-15kHz)', 10000, 15000;
    'Hi-Hat High (15-20kHz)', 15000, 20000;
};

fprintf('\n%-30s | %-10s\n', '대역', '제거율');
fprintf('%s\n', repmat('-', 1, 50));

for b = 1:size(analysis_bands, 1)
    band_name = analysis_bands{b, 1};
    low_f = analysis_bands{b, 2};
    high_f = analysis_bands{b, 3};
    
    band_mask = (f >= low_f & f <= high_f);
    
    orig_energy = mean(magS(band_mask, :), 'all');
    filt_energy = mean(magS_filt(band_mask, :), 'all');
    
    reduction = (1 - filt_energy/orig_energy) * 100;
    
    fprintf('%-30s | %9.2f%%\n', band_name, reduction);
end

% 전체 RMS 비교
rms_orig = sqrt(mean(x.^2));
rms_filt = sqrt(mean(x_filtered.^2));
rms_reduction = (1 - rms_filt/rms_orig) * 100;

fprintf('\n전체 RMS 감소: %.2f%%\n', rms_reduction);

fprintf('\n=== 전체 드럼 제거 v1 완료! ===\n');