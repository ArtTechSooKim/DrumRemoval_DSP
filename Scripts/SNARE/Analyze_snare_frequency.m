%% ============================================================
%% Snare Drum Frequency Analysis
%% CityDay 곡의 스네어 주파수 특성 분석
%% ============================================================

%% STEP 1 - Load Audio
input_path = "F:\GitHub\DrumRemoval_DSP\OriginalSongs\ZZZ Camillia Golden Week OST_ CityDay [Zenless Zone Zero].mp3";
[x, fs] = audioread(input_path);
x = mean(x, 2);

fprintf('파일 로드: %.2f초, %dHz\n', length(x)/fs, fs);

%% STEP 2 - 스네어가 많은 구간 선택
% 여러 구간을 분석해서 스네어 특성 찾기
analysis_segments = [
    60, 70;    % 구간 1
    30, 40;    % 구간 2  
    90, 100;   % 구간 3
];

fprintf('\n=== 스네어 분석 구간 ===\n');
for i = 1:size(analysis_segments, 1)
    fprintf('구간 %d: %.0f~%.0f초\n', i, analysis_segments(i,1), analysis_segments(i,2));
end

%% STEP 3 - STFT로 시간-주파수 분석
win_len = 2048;
hop = 512;
nfft = 4096;
win = hann(win_len);
overlap = win_len - hop;

% 첫 번째 구간 분석
start_t = analysis_segments(1, 1);
end_t = analysis_segments(1, 2);
start_idx = floor(start_t * fs);
end_idx = floor(end_t * fs);

x_segment = x(start_idx:end_idx);

[S, f, t] = stft(x_segment, fs, 'Window', win, 'OverlapLength', overlap, 'FFTLength', nfft);
magS = abs(S);

fprintf('\nSTFT 완료: %d frames x %d freq bins\n', size(S,2), size(S,1));

%% STEP 4 - 스네어 특성 추출
% 스네어는 두 가지 주요 성분:
% 1) Body/Shell resonance: 150~300Hz (낮은 톤)
% 2) Snare wire: 3~10kHz (고주파 노이즈/rattle)

% 대역별 에너지 계산
snare_body_band = (f >= 150 & f <= 300);
snare_wire_band = (f >= 3000 & f <= 10000);
kick_band = (f >= 50 & f <= 120);  % 비교용

energy_body = sum(magS(snare_body_band, :), 1);
energy_wire = sum(magS(snare_wire_band, :), 1);
energy_kick = sum(magS(kick_band, :), 1);

% Normalize
energy_body_norm = energy_body / max(energy_body);
energy_wire_norm = energy_wire / max(energy_wire);
energy_kick_norm = energy_kick / max(energy_kick);

%% STEP 5 - 스네어 후보 프레임 찾기
% 스네어 특징: body + wire 동시 발생, kick과 다른 타이밍
snare_score = 0.4 * energy_body_norm + 0.6 * energy_wire_norm;
snare_threshold = prctile(snare_score, 75);  % 상위 25%
snare_frames = snare_score > snare_threshold;

fprintf('\n=== 스네어 후보 프레임 ===\n');
fprintf('감지된 스네어 프레임: %d/%d (%.1f%%)\n', ...
    sum(snare_frames), length(snare_frames), ...
    100*sum(snare_frames)/length(snare_frames));

%% STEP 6 - 스네어가 강한 순간의 스펙트럼 평균
snare_spectrum = mean(magS(:, snare_frames), 2);
full_spectrum = mean(magS, 2);

%% STEP 7 - Visualization
figure('Position', [100, 100, 1400, 900]);

% 7-1) Spectrogram (0-500Hz)
subplot(3,2,1);
imagesc(t, f(f<=500), 20*log10(magS(f<=500, :) + eps));
axis xy;
colorbar;
caxis([-80, 0]);
title('Spectrogram: Low Freq (0-500Hz)');
xlabel('Time (s)');
ylabel('Frequency (Hz)');

% 7-2) Spectrogram (3-10kHz) - Snare wire 대역
subplot(3,2,2);
wire_band_idx = (f >= 3000 & f <= 10000);
imagesc(t, f(wire_band_idx), 20*log10(magS(wire_band_idx, :) + eps));
axis xy;
colorbar;
caxis([-80, 0]);
title('Spectrogram: Snare Wire (3-10kHz)');
xlabel('Time (s)');
ylabel('Frequency (Hz)');

% 7-3) 에너지 timeline 비교
subplot(3,2,3);
plot(t, energy_kick_norm, 'b', 'LineWidth', 1.5); hold on;
plot(t, energy_body_norm, 'r', 'LineWidth', 1.5);
plot(t, energy_wire_norm, 'g', 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Normalized Energy');
title('Energy Timeline by Band');
legend('Kick (50-120Hz)', 'Snare Body (150-300Hz)', 'Snare Wire (3-10kHz)');
grid on;

% 7-4) 스네어 score
subplot(3,2,4);
plot(t, snare_score, 'b', 'LineWidth', 1); hold on;
yline(snare_threshold, 'r--', 'LineWidth', 2);
scatter(t(snare_frames), snare_score(snare_frames), 30, 'g', 'filled');
xlabel('Time (s)');
ylabel('Snare Score');
title(sprintf('Snare Detection (threshold=%.3f)', snare_threshold));
legend('Snare Score', 'Threshold', 'Detected Frames');
grid on;

% 7-5) 전체 스펙트럼 vs 스네어 스펙트럼
subplot(3,2,5);
plot(f, 20*log10(full_spectrum + eps), 'b', 'LineWidth', 1.5); hold on;
plot(f, 20*log10(snare_spectrum + eps), 'r', 'LineWidth', 1.5);
xlim([0, 1000]);
ylim([-80, 40]);
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title('Average Spectrum Comparison (0-1kHz)');
legend('All Frames', 'Snare Frames Only');
grid on;

% 주요 대역 표시
xline(150, 'g--', 'Alpha', 0.5);
xline(300, 'g--', 'Alpha', 0.5);
text(225, 30, 'Snare Body', 'HorizontalAlignment', 'center', 'Color', 'g');

% 7-6) 고주파 스펙트럼 (Snare wire)
subplot(3,2,6);
plot(f, 20*log10(full_spectrum + eps), 'b', 'LineWidth', 1.5); hold on;
plot(f, 20*log10(snare_spectrum + eps), 'r', 'LineWidth', 1.5);
xlim([2000, 12000]);
ylim([-80, 20]);
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title('High Freq Spectrum (2-12kHz)');
legend('All Frames', 'Snare Frames Only');
grid on;

% 스네어 wire 대역 표시
xline(3000, 'g--', 'Alpha', 0.5);
xline(10000, 'g--', 'Alpha', 0.5);
text(6500, 15, 'Snare Wire', 'HorizontalAlignment', 'center', 'Color', 'g');

sgtitle('Snare Drum Frequency Analysis');

saveas(gcf, 'F:\GitHub\DrumRemoval_DSP\Graphs\snare_frequency_analysis.png');

fprintf('\n스펙트럼 그래프 저장 완료!\n');

%% STEP 8 - 주파수 대역별 상세 분석
fprintf('\n=== 주파수 대역별 에너지 분석 ===\n');

bands_to_check = {
    'Kick Fundamental (50-120Hz)', 50, 120;
    'Snare Body Low (150-200Hz)', 150, 200;
    'Snare Body Mid (200-300Hz)', 200, 300;
    'Snare Body High (300-500Hz)', 300, 500;
    'Mid Freq (1-3kHz)', 1000, 3000;
    'Snare Wire (3-6kHz)', 3000, 6000;
    'Snare Wire High (6-10kHz)', 6000, 10000;
    'Very High (10-15kHz)', 10000, 15000;
};

fprintf('\n%-30s | %-15s | %-15s | %-10s\n', '대역', '전체 평균', '스네어 평균', '비율');
fprintf('%s\n', repmat('-', 1, 80));

for i = 1:size(bands_to_check, 1)
    band_name = bands_to_check{i, 1};
    low_f = bands_to_check{i, 2};
    high_f = bands_to_check{i, 3};
    
    band_mask = (f >= low_f & f <= high_f);
    
    full_energy = mean(magS(band_mask, :), 'all');
    snare_energy = mean(magS(band_mask, snare_frames), 'all');
    
    ratio = snare_energy / full_energy;
    
    fprintf('%-30s | %15.4f | %15.4f | %10.2fx\n', ...
        band_name, full_energy, snare_energy, ratio);
end

%% STEP 9 - 스네어 특성 요약
fprintf('\n=== 스네어 주파수 특성 요약 ===\n');
fprintf('1. Snare Body (Shell Resonance)\n');
fprintf('   - 주 대역: 150~300Hz\n');
fprintf('   - 특징: 킥(50-120Hz)보다 높은 톤\n');
fprintf('\n');
fprintf('2. Snare Wire (Rattle/Buzz)\n');
fprintf('   - 주 대역: 3~10kHz\n');
fprintf('   - 특징: 밝고 날카로운 고주파 노이즈\n');
fprintf('\n');
fprintf('3. 감지 전략\n');
fprintf('   - Body + Wire 동시 발생하는 순간 = 스네어\n');
fprintf('   - Kick과 구별: 킥은 저주파만, 스네어는 저+고주파\n');
fprintf('\n분석 완료!\n');