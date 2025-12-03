%% ============================================================
%% Hi-Hat Removal v1 - STFT Based
%% 
%% 분석 결과:
%% - 주파수: 6-20kHz (특히 10-15kHz 핵심)
%% - 하이햇 에너지가 전체 대비 3배 이상 (6-20kHz)
%% - Duration: 매우 짧음 (평균 39.5ms)
%% - 발생 빈도: 매우 높음 (16분음표)
%% 
%% 전략:
%% 1. 고주파 에너지 기반 detection (6-20kHz)
%% 2. 10-15kHz 중심으로 제거
%% 3. 15-20kHz는 매우 강하게 제거 (하이햇만 있음)
%% ============================================================

%% STEP 0 - Load Audio
input_path = "F:\GitHub\DrumRemoval_DSP\OriginalSongs\ZZZ Camillia Golden Week OST_ CityDay [Zenless Zone Zero].mp3";
output_path = "F:\GitHub\DrumRemoval_DSP\FilteredSong\HIHAT\CityDay_hihat_removed_v1.wav";

[x, fs] = audioread(input_path);
x = mean(x, 2);

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

%% STEP 2 - Hi-Hat Detection
% 분석 결과: 6-20kHz 전체가 중요, 특히 10-15kHz 핵심

% 2-1) Hi-Hat 주파수 대역
hihat_low_band = (f >= 6000 & f <= 10000);    % Low (스네어와 겹침)
hihat_mid_band = (f >= 10000 & f <= 15000);   % Mid (핵심!)
hihat_high_band = (f >= 15000 & f <= 20000);  % High (하이햇만)

% 에너지 계산
energy_low = sum(magS(hihat_low_band, :), 1);
energy_mid = sum(magS(hihat_mid_band, :), 1);
energy_high = sum(magS(hihat_high_band, :), 1);

% Normalize
energy_low_norm = energy_low / max(energy_low);
energy_mid_norm = energy_mid / max(energy_mid);
energy_high_norm = energy_high / max(energy_high);

% 2-2) Hi-Hat detection score
% 분석 결과 기반: Mid가 가장 중요
hihat_score = 0.3 * energy_low_norm + ...
              0.5 * energy_mid_norm + ...     % Mid 비중 증가
              0.2 * energy_high_norm;

% 2-3) Adaptive threshold
hihat_threshold = prctile(hihat_score, 75);  % 상위 25%
hihat_frames = hihat_score > hihat_threshold;

fprintf('하이햇 프레임 감지: %d/%d (%.1f%%)\n', ...
    sum(hihat_frames), length(hihat_frames), ...
    100*sum(hihat_frames)/length(hihat_frames));

%% STEP 3 - Multi-band Hi-Hat Removal
S_filtered = S;

% 주파수 대역 정의 (더 세분화)
band_5_6k = (f >= 5000 & f <= 6000);        % Pre hi-hat
band_6_8k = (f >= 6000 & f <= 8000);        % Low 1
band_8_10k = (f >= 8000 & f <= 10000);      % Low 2
band_10_12k = (f >= 10000 & f <= 12000);    % Mid 1
band_12_15k = (f >= 12000 & f <= 15000);    % Mid 2
band_15_18k = (f >= 15000 & f <= 18000);    % High 1
band_18_20k = (f >= 18000 & f <= 20000);    % High 2
band_20_22k = (f >= 20000 & f <= 22050);    % Very high

% 감쇠 강도 (주파수 올라갈수록 강하게)
atten_5_6k = 0.50;      % 50% (보수적)
atten_6_8k = 0.75;      % 75%
atten_8_10k = 0.80;     % 80%
atten_10_12k = 0.88;    % 88% (핵심 대역)
atten_12_15k = 0.90;    % 90% (핵심 대역)
atten_15_18k = 0.93;    % 93% (하이햇만)
atten_18_20k = 0.95;    % 95% (하이햇만)
atten_20_22k = 0.92;    % 92%

% Temporal window (하이햇은 짧아서 작게)
temporal_window = 1;  % ±1 frame만

for i = 1:length(t)
    if hihat_frames(i)
        % 현재 프레임 처리
        S_filtered(band_5_6k, i) = S_filtered(band_5_6k, i) * (1 - atten_5_6k);
        S_filtered(band_6_8k, i) = S_filtered(band_6_8k, i) * (1 - atten_6_8k);
        S_filtered(band_8_10k, i) = S_filtered(band_8_10k, i) * (1 - atten_8_10k);
        S_filtered(band_10_12k, i) = S_filtered(band_10_12k, i) * (1 - atten_10_12k);
        S_filtered(band_12_15k, i) = S_filtered(band_12_15k, i) * (1 - atten_12_15k);
        S_filtered(band_15_18k, i) = S_filtered(band_15_18k, i) * (1 - atten_15_18k);
        S_filtered(band_18_20k, i) = S_filtered(band_18_20k, i) * (1 - atten_18_20k);
        S_filtered(band_20_22k, i) = S_filtered(band_20_22k, i) * (1 - atten_20_22k);
        
        % 주변 프레임 (하이햇은 짧아서 약하게만)
        for offset = -temporal_window:temporal_window
            idx = i + offset;
            if idx >= 1 && idx <= length(t) && offset ~= 0
                weight = 0.3;  % 30%만 (하이햇은 짧음)
                S_filtered(band_10_12k, idx) = S_filtered(band_10_12k, idx) * (1 - atten_10_12k * weight);
                S_filtered(band_12_15k, idx) = S_filtered(band_12_15k, idx) * (1 - atten_12_15k * weight);
                S_filtered(band_15_18k, idx) = S_filtered(band_15_18k, idx) * (1 - atten_15_18k * weight);
                S_filtered(band_18_20k, idx) = S_filtered(band_18_20k, idx) * (1 - atten_18_20k * weight);
            end
        end
    end
end

%% STEP 4 - Spectral Smoothing
for i = 2:size(S_filtered, 2)-1
    % 3-point smoothing (하이햇은 짧아서 약하게)
    S_filtered(:, i) = 0.5 * S_filtered(:, i) + ...
                       0.25 * S_filtered(:, i-1) + ...
                       0.25 * S_filtered(:, i+1);
end

%% STEP 5 - iSTFT
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

%% STEP 6 - Save Output
audiowrite(output_path, x_filtered, fs);

fprintf('\n=== Hi-Hat Removal v1 완료 ===\n');
fprintf('출력 파일: %s\n', output_path);

%% STEP 7 - Visualization
figure('Position', [100, 100, 1400, 900]);

% 7-1) Hi-Hat detection
subplot(3,2,1);
plot(t, hihat_score, 'b', 'LineWidth', 1); hold on;
yline(hihat_threshold, 'r--', 'LineWidth', 2);
scatter(t(hihat_frames), hihat_score(hihat_frames), 20, 'g', 'filled');
xlim([60, 70]);
xlabel('Time (s)');
ylabel('Hi-Hat Score');
title(sprintf('Hi-Hat Detection (threshold=%.4f)', hihat_threshold));
legend('Hi-Hat Score', 'Threshold', 'Detected');
grid on;

% 7-2) Original Spectrogram (High Freq)
subplot(3,2,2);
high_idx = (f >= 5000 & f <= 20000);
imagesc(t, f(high_idx), 20*log10(magS(high_idx, :) + eps));
axis xy;
colorbar;
caxis([-80, 0]);
xlim([60, 70]);
title('Original: High Freq (5-20kHz)');
xlabel('Time (s)');
ylabel('Frequency (Hz)');

% 7-3) Filtered Spectrogram (High Freq)
subplot(3,2,3);
magS_filt = abs(S_filtered);
imagesc(t, f(high_idx), 20*log10(magS_filt(high_idx, :) + eps));
axis xy;
colorbar;
caxis([-80, 0]);
xlim([60, 70]);
title('Filtered: High Freq (5-20kHz)');
xlabel('Time (s)');
ylabel('Frequency (Hz)');

% 7-4) Energy timeline 비교
subplot(3,2,4);
plot(t, energy_low_norm, 'g', 'LineWidth', 1.5); hold on;
plot(t, energy_mid_norm, 'm', 'LineWidth', 1.5);
plot(t, energy_high_norm, 'c', 'LineWidth', 1.5);
xlim([60, 65]);
xlabel('Time (s)');
ylabel('Normalized Energy');
title('Hi-Hat Energy Timeline');
legend('Low (6-10kHz)', 'Mid (10-15kHz)', 'High (15-20kHz)');
grid on;

% 7-5) Spectrum comparison (전체)
subplot(3,2,5);
avg_orig = mean(magS, 2);
avg_filt = mean(magS_filt, 2);
plot(f, 20*log10(avg_orig + eps), 'b', 'LineWidth', 1.5); hold on;
plot(f, 20*log10(avg_filt + eps), 'r', 'LineWidth', 1.5);
xlim([0, 20000]);
ylim([-80, 40]);
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title('Average Spectrum Comparison');
legend('Original', 'Hi-Hat Removed');
grid on;

% 주요 대역 표시
xline(6000, 'g--', 'Alpha', 0.5);
xline(10000, 'g--', 'Alpha', 0.5);
xline(15000, 'g--', 'Alpha', 0.5);
xline(20000, 'g--', 'Alpha', 0.5);

% 7-6) Spectrum comparison (Hi-Hat band zoom)
subplot(3,2,6);
plot(f, 20*log10(avg_orig + eps), 'b', 'LineWidth', 2); hold on;
plot(f, 20*log10(avg_filt + eps), 'r', 'LineWidth', 2);
xlim([5000, 20000]);
ylim([-80, 20]);
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title('Hi-Hat Band Zoom (5-20kHz)');
legend('Original', 'Hi-Hat Removed');
grid on;

sgtitle('Hi-Hat Removal v1 Analysis');

saveas(gcf, 'F:\GitHub\DrumRemoval_DSP\Graphs\HIHAT\hihat_removal_v1_result.png');

fprintf('시각화 완료!\n');

%% STEP 8 - 정량 분석
fprintf('\n=== 주파수 대역별 제거율 ===\n');

bands_check = {
    'Pre Hi-Hat (5-6kHz)', 5000, 6000;
    'HH Low 1 (6-8kHz)', 6000, 8000;
    'HH Low 2 (8-10kHz)', 8000, 10000;
    'HH Mid 1 (10-12kHz)', 10000, 12000;
    'HH Mid 2 (12-15kHz)', 12000, 15000;
    'HH High 1 (15-18kHz)', 15000, 18000;
    'HH High 2 (18-20kHz)', 18000, 20000;
    'Very High (20-22kHz)', 20000, 22050;
};

for b = 1:size(bands_check, 1)
    band_name = bands_check{b, 1};
    low_f = bands_check{b, 2};
    high_f = bands_check{b, 3};
    
    band_mask = (f >= low_f & f <= high_f);
    
    orig_energy = mean(magS(band_mask, :), 'all');
    filt_energy = mean(magS_filt(band_mask, :), 'all');
    
    reduction = (1 - filt_energy/orig_energy) * 100;
    
    fprintf('%s: %.2f%% 제거\n', band_name, reduction);
end

fprintf('\n하이햇 제거 v1 완료!\n');