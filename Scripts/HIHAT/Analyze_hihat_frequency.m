%% ============================================================
%% Hi-Hat Frequency Analysis
%% CityDay 곡의 하이햇 주파수 특성 분석
%% ============================================================

%% STEP 1 - Load Audio
input_path = "F:\GitHub\DrumRemoval_DSP\OriginalSongs\ZZZ Camillia Golden Week OST_ CityDay [Zenless Zone Zero].mp3";
[x, fs] = audioread(input_path);
x = mean(x, 2);

fprintf('파일 로드: %.2f초, %dHz\n', length(x)/fs, fs);

%% STEP 2 - 분석 구간 선택
% 하이햇이 많은 구간
analysis_segments = [
    60, 70;    % 구간 1
    30, 40;    % 구간 2  
    90, 100;   % 구간 3
];

fprintf('\n=== 하이햇 분석 구간 ===\n');
for i = 1:size(analysis_segments, 1)
    fprintf('구간 %d: %.0f~%.0f초\n', i, analysis_segments(i,1), analysis_segments(i,2));
end

%% STEP 3 - STFT Analysis
win_len = 2048;
hop = 512;
nfft = 4096;
win = hann(win_len);
overlap = win_len - hop;

% 첫 번째 구간
start_t = analysis_segments(1, 1);
end_t = analysis_segments(1, 2);
start_idx = floor(start_t * fs);
end_idx = floor(end_t * fs);

x_segment = x(start_idx:end_idx);

[S, f, t] = stft(x_segment, fs, 'Window', win, 'OverlapLength', overlap, 'FFTLength', nfft);
magS = abs(S);

fprintf('STFT 완료: %d frames x %d bins\n', size(S,2), size(S,1));

%% STEP 4 - Hi-Hat 특성 추출
% 하이햇 특징:
% 1) 매우 짧은 duration (20-50ms)
% 2) 고주파 집중 (6-20kHz)
% 3) 밝고 crisp한 소리
% 4) 노이즈 성분 강함

% 주파수 대역 정의
hihat_low_band = (f >= 6000 & f <= 10000);    % Low hi-hat
hihat_mid_band = (f >= 10000 & f <= 15000);   % Mid hi-hat
hihat_high_band = (f >= 15000 & f <= 20000);  % High hi-hat (very bright)

% 비교용 대역
kick_band = (f >= 50 & f <= 120);
snare_wire_band = (f >= 3000 & f <= 10000);

% 에너지 계산
energy_hihat_low = sum(magS(hihat_low_band, :), 1);
energy_hihat_mid = sum(magS(hihat_mid_band, :), 1);
energy_hihat_high = sum(magS(hihat_high_band, :), 1);
energy_kick = sum(magS(kick_band, :), 1);
energy_snare_wire = sum(magS(snare_wire_band, :), 1);

% Normalize
energy_hihat_low_norm = energy_hihat_low / max(energy_hihat_low);
energy_hihat_mid_norm = energy_hihat_mid / max(energy_hihat_mid);
energy_hihat_high_norm = energy_hihat_high / max(energy_hihat_high);
energy_kick_norm = energy_kick / max(energy_kick);
energy_snare_wire_norm = energy_snare_wire / max(energy_snare_wire);

%% STEP 5 - Hi-Hat Detection
% 하이햇 score: 고주파 중심
hihat_score = 0.3 * energy_hihat_low_norm + ...
              0.4 * energy_hihat_mid_norm + ...
              0.3 * energy_hihat_high_norm;

hihat_threshold = prctile(hihat_score, 75);  % 상위 25%
hihat_frames = hihat_score > hihat_threshold;

fprintf('\n=== 하이햇 후보 프레임 ===\n');
fprintf('감지된 하이햇 프레임: %d/%d (%.1f%%)\n', ...
    sum(hihat_frames), length(hihat_frames), ...
    100*sum(hihat_frames)/length(hihat_frames));

%% STEP 6 - 하이햇 프레임의 평균 스펙트럼
hihat_spectrum = mean(magS(:, hihat_frames), 2);
full_spectrum = mean(magS, 2);

%% STEP 7 - Visualization
figure('Position', [100, 100, 1400, 1000]);

% 7-1) Spectrogram (6-20kHz) - Hi-hat 대역
subplot(3,2,1);
hihat_band_idx = (f >= 6000 & f <= 20000);
imagesc(t, f(hihat_band_idx), 20*log10(magS(hihat_band_idx, :) + eps));
axis xy;
colorbar;
caxis([-80, 0]);
title('Spectrogram: Hi-Hat Band (6-20kHz)');
xlabel('Time (s)');
ylabel('Frequency (Hz)');

% 7-2) Spectrogram (전체 고주파 0-20kHz)
subplot(3,2,2);
high_freq_idx = (f >= 0 & f <= 20000);
imagesc(t, f(high_freq_idx), 20*log10(magS(high_freq_idx, :) + eps));
axis xy;
colorbar;
caxis([-80, 0]);
title('Spectrogram: Full High Freq (0-20kHz)');
xlabel('Time (s)');
ylabel('Frequency (Hz)');

% 7-3) 에너지 timeline 비교
subplot(3,2,3);
plot(t, energy_kick_norm, 'b', 'LineWidth', 1.5); hold on;
plot(t, energy_snare_wire_norm, 'r', 'LineWidth', 1.5);
plot(t, energy_hihat_low_norm, 'g', 'LineWidth', 1.5);
plot(t, energy_hihat_mid_norm, 'm', 'LineWidth', 1.5);
plot(t, energy_hihat_high_norm, 'c', 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Normalized Energy');
title('Energy Timeline by Instrument');
legend('Kick (50-120Hz)', 'Snare Wire (3-10kHz)', ...
       'HH Low (6-10kHz)', 'HH Mid (10-15kHz)', 'HH High (15-20kHz)', ...
       'Location', 'best');
grid on;

% 7-4) Hi-Hat Score & Detection
subplot(3,2,4);
plot(t, hihat_score, 'b', 'LineWidth', 1); hold on;
yline(hihat_threshold, 'r--', 'LineWidth', 2);
scatter(t(hihat_frames), hihat_score(hihat_frames), 30, 'g', 'filled');
xlabel('Time (s)');
ylabel('Hi-Hat Score');
title(sprintf('Hi-Hat Detection (threshold=%.3f)', hihat_threshold));
legend('Hi-Hat Score', 'Threshold', 'Detected Frames');
grid on;

% 7-5) 전체 스펙트럼 비교
subplot(3,2,5);
plot(f, 20*log10(full_spectrum + eps), 'b', 'LineWidth', 1.5); hold on;
plot(f, 20*log10(hihat_spectrum + eps), 'r', 'LineWidth', 1.5);
xlim([0, 20000]);
ylim([-80, 40]);
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title('Full Spectrum Comparison');
legend('All Frames', 'Hi-Hat Frames Only');
grid on;

% 하이햇 대역 표시
xline(6000, 'g--', 'Alpha', 0.5);
xline(10000, 'g--', 'Alpha', 0.5);
xline(15000, 'g--', 'Alpha', 0.5);
xline(20000, 'g--', 'Alpha', 0.5);
text(8000, 35, 'HH Low', 'Color', 'g');
text(12500, 35, 'HH Mid', 'Color', 'g');
text(17500, 35, 'HH High', 'Color', 'g');

% 7-6) 고주파 확대 (6-20kHz)
subplot(3,2,6);
plot(f, 20*log10(full_spectrum + eps), 'b', 'LineWidth', 2); hold on;
plot(f, 20*log10(hihat_spectrum + eps), 'r', 'LineWidth', 2);
xlim([5000, 20000]);
ylim([-80, 20]);
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title('Hi-Hat Band Zoom (5-20kHz)');
legend('All Frames', 'Hi-Hat Frames Only');
grid on;

sgtitle('Hi-Hat Frequency Analysis');

saveas(gcf, 'F:\GitHub\DrumRemoval_DSP\Graphs\HIHAT\hihat_frequency_analysis.png');

fprintf('\n시각화 완료!\n');

%% STEP 8 - 주파수 대역별 상세 분석
fprintf('\n=== 주파수 대역별 에너지 분석 ===\n');

bands_to_check = {
    'Kick (50-120Hz)', 50, 120;
    'Snare Body (150-300Hz)', 150, 300;
    'Snare Wire (3-6kHz)', 3000, 6000;
    'HH Low (6-10kHz)', 6000, 10000;
    'HH Mid (10-15kHz)', 10000, 15000;
    'HH High (15-20kHz)', 15000, 20000;
    'Very High (20-22kHz)', 20000, 22050;  % Nyquist까지
};

fprintf('\n%-30s | %-15s | %-15s | %-10s\n', '대역', '전체 평균', '하이햇 평균', '비율');
fprintf('%s\n', repmat('-', 1, 80));

for i = 1:size(bands_to_check, 1)
    band_name = bands_to_check{i, 1};
    low_f = bands_to_check{i, 2};
    high_f = bands_to_check{i, 3};
    
    band_mask = (f >= low_f & f <= high_f);
    
    full_energy = mean(magS(band_mask, :), 'all');
    hihat_energy = mean(magS(band_mask, hihat_frames), 'all');
    
    if full_energy > 0
        ratio = hihat_energy / full_energy;
    else
        ratio = 0;
    end
    
    fprintf('%-30s | %15.4f | %15.4f | %10.2fx\n', ...
        band_name, full_energy, hihat_energy, ratio);
end

%% STEP 9 - 하이햇 특성 요약
fprintf('\n=== 하이햇 주파수 특성 요약 ===\n');
fprintf('1. Hi-Hat 주 대역: 6~20kHz\n');
fprintf('   - Low (6-10kHz): 스네어 wire와 겹침\n');
fprintf('   - Mid (10-15kHz): 하이햇 핵심 대역\n');
fprintf('   - High (15-20kHz): 매우 밝은 성분 (open hi-hat)\n');
fprintf('\n');
fprintf('2. 시간적 특성\n');
fprintf('   - Duration: 매우 짧음 (20-50ms)\n');
fprintf('   - 빈도: 매우 높음 (8th/16th notes)\n');
fprintf('\n');
fprintf('3. 다른 악기와 구별\n');
fprintf('   - Kick: 50-120Hz (겹침 없음)\n');
fprintf('   - Snare: 3-10kHz (일부 겹침)\n');
fprintf('   - Hi-Hat: 6-20kHz (고주파 집중)\n');
fprintf('\n');
fprintf('4. 감지 전략\n');
fprintf('   - 10-15kHz 에너지가 핵심!\n');
fprintf('   - 매우 짧은 transient\n');
fprintf('   - 높은 빈도로 발생\n');
fprintf('\n분석 완료!\n');

%% STEP 10 - Temporal Analysis (Duration)
% 하이햇의 짧은 duration 확인
fprintf('\n=== Temporal Duration 분석 ===\n');

% High-pass filter (6kHz 이상만)
[b, a] = butter(4, 6000/(fs/2), 'high');
x_high = filtfilt(b, a, x_segment);

% Envelope
env_high = abs(hilbert(x_high));
env_high_smooth = movmean(env_high, round(0.005*fs));  % 5ms smoothing

% Transient 찾기
[pks, locs] = findpeaks(env_high_smooth, ...
    'MinPeakHeight', mean(env_high_smooth) + 2*std(env_high_smooth), ...
    'MinPeakDistance', round(0.05*fs));  % 최소 50ms 간격

fprintf('감지된 고주파 transient: %d개\n', length(locs));

% Duration 계산 (peak의 50% 지점 기준)
durations = [];
for i = 1:length(locs)
    peak_val = pks(i);
    half_val = peak_val * 0.5;
    
    % 시작점 찾기
    start_idx = locs(i);
    while start_idx > 1 && env_high_smooth(start_idx) > half_val
        start_idx = start_idx - 1;
    end
    
    % 끝점 찾기
    end_idx = locs(i);
    while end_idx < length(env_high_smooth) && env_high_smooth(end_idx) > half_val
        end_idx = end_idx + 1;
    end
    
    duration_samples = end_idx - start_idx;
    duration_ms = (duration_samples / fs) * 1000;
    durations = [durations; duration_ms];
end

if ~isempty(durations)
    fprintf('평균 duration: %.1f ms\n', mean(durations));
    fprintf('최소 duration: %.1f ms\n', min(durations));
    fprintf('최대 duration: %.1f ms\n', max(durations));
end

fprintf('\n하이햇 분석 완료!\n');