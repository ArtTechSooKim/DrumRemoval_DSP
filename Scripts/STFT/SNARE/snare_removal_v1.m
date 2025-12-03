%% ============================================================
%% Snare Drum Removal v1 - STFT Based
%% 
%% 분석 결과:
%% - Snare Body (150-300Hz): 약함, 킥과 겹침
%% - Snare Wire (3-10kHz): 강함, 스네어 핵심 특성
%% 
%% 전략:
%% 1. Wire 에너지 중심 detection
%% 2. Body + Wire 동시 제거
%% 3. Kick 제거 코드 참고
%% ============================================================

%% STEP 0 - Load Audio
input_path = "F:\GitHub\DrumRemoval_DSP\OriginalSongs\ZZZ Camillia Golden Week OST_ CityDay [Zenless Zone Zero].mp3";
output_path = "F:\GitHub\DrumRemoval_DSP\FilteredSong\SNARE\CityDay_snare_removed_v1.wav";

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

%% STEP 2 - Snare Detection
% 분석 결과: Wire가 더 중요!

% 2-1) Snare Body (150-300Hz)
snare_body_band = (f >= 150 & f <= 300);

% 2-2) Snare Wire (3-10kHz) - 핵심!
snare_wire_band = (f >= 3000 & f <= 10000);

% 2-3) Additional: Mid freq (1-3kHz) - 배음
snare_mid_band = (f >= 1000 & f <= 3000);

% 각 대역 에너지
energy_body = sum(magS(snare_body_band, :), 1);
energy_wire = sum(magS(snare_wire_band, :), 1);
energy_mid = sum(magS(snare_mid_band, :), 1);

% Normalize
energy_body_norm = energy_body / max(energy_body);
energy_wire_norm = energy_wire / max(energy_wire);
energy_mid_norm = energy_mid / max(energy_mid);

% 2-4) Snare detection score (Wire 중심)
snare_score = 0.2 * energy_body_norm + ...    % Body 비중 낮춤
              0.6 * energy_wire_norm + ...     % Wire 비중 증가
              0.2 * energy_mid_norm;           % Mid 추가

% 2-5) Adaptive threshold
snare_threshold = prctile(snare_score, 70);  % 상위 30%
snare_frames = snare_score > snare_threshold;

fprintf('스네어 프레임 감지: %d/%d (%.1f%%)\n', ...
    sum(snare_frames), length(snare_frames), ...
    100*sum(snare_frames)/length(snare_frames));

%% STEP 3 - Multi-band Snare Removal
S_filtered = S;

% 주파수 대역 정의
body_band = (f >= 150 & f <= 300);          % Body
body_ext_band = (f >= 300 & f <= 500);     % Body 확장
mid_band = (f >= 1000 & f <= 3000);        % Mid
wire_band = (f >= 3000 & f <= 10000);      % Wire
wire_high_band = (f >= 10000 & f <= 15000); % Wire high extension

% 감쇠 강도
atten_body = 0.75;          % 75% 제거 (약하게, 베이스 보호)
atten_body_ext = 0.60;      % 60% 제거
atten_mid = 0.80;           % 80% 제거
atten_wire = 0.92;          % 92% 제거 (강하게!)
atten_wire_high = 0.85;     % 85% 제거

% Temporal window
temporal_window = 2;  % ±2 frames

for i = 1:length(t)
    if snare_frames(i)
        % 현재 프레임 처리
        S_filtered(body_band, i) = S_filtered(body_band, i) * (1 - atten_body);
        S_filtered(body_ext_band, i) = S_filtered(body_ext_band, i) * (1 - atten_body_ext);
        S_filtered(mid_band, i) = S_filtered(mid_band, i) * (1 - atten_mid);
        S_filtered(wire_band, i) = S_filtered(wire_band, i) * (1 - atten_wire);
        S_filtered(wire_high_band, i) = S_filtered(wire_high_band, i) * (1 - atten_wire_high);
        
        % 주변 프레임도 약하게 처리
        for offset = -temporal_window:temporal_window
            idx = i + offset;
            if idx >= 1 && idx <= length(t) && offset ~= 0
                weight = 0.4;
                S_filtered(body_band, idx) = S_filtered(body_band, idx) * (1 - atten_body * weight);
                S_filtered(mid_band, idx) = S_filtered(mid_band, idx) * (1 - atten_mid * weight);
                S_filtered(wire_band, idx) = S_filtered(wire_band, idx) * (1 - atten_wire * weight);
                S_filtered(wire_high_band, idx) = S_filtered(wire_high_band, idx) * (1 - atten_wire_high * weight);
            end
        end
    end
end

%% STEP 4 - Spectral Smoothing
for i = 3:size(S_filtered, 2)-2
    % 5-point smoothing
    S_filtered(:, i) = 0.4 * S_filtered(:, i) + ...
                       0.2 * S_filtered(:, i-1) + ...
                       0.2 * S_filtered(:, i+1) + ...
                       0.1 * S_filtered(:, i-2) + ...
                       0.1 * S_filtered(:, i+2);
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

fprintf('\n=== Snare Removal v1 완료 ===\n');
fprintf('출력 파일: %s\n', output_path);

%% STEP 7 - Visualization
figure('Position', [100, 100, 1400, 800]);

% 7-1) Snare detection
subplot(2,3,1);
plot(t, snare_score, 'b', 'LineWidth', 1); hold on;
yline(snare_threshold, 'r--', 'LineWidth', 2);
scatter(t(snare_frames), snare_score(snare_frames), 20, 'g', 'filled');
xlim([60, 70]);
xlabel('Time (s)');
ylabel('Snare Score');
title(sprintf('Snare Detection (threshold=%.4f)', snare_threshold));
legend('Snare Score', 'Threshold', 'Detected');
grid on;

% 7-2) Original Spectrogram (Body)
subplot(2,3,2);
body_idx = (f >= 100 & f <= 600);
imagesc(t, f(body_idx), 20*log10(magS(body_idx, :) + eps));
axis xy;
colorbar;
caxis([-80, 0]);
xlim([60, 70]);
title('Original: Body (100-600Hz)');
xlabel('Time (s)');
ylabel('Frequency (Hz)');

% 7-3) Original Spectrogram (Wire)
subplot(2,3,3);
wire_idx = (f >= 3000 & f <= 12000);
imagesc(t, f(wire_idx), 20*log10(magS(wire_idx, :) + eps));
axis xy;
colorbar;
caxis([-80, 0]);
xlim([60, 70]);
title('Original: Wire (3-12kHz)');
xlabel('Time (s)');
ylabel('Frequency (Hz)');

% 7-4) Filtered Spectrogram (Body)
subplot(2,3,5);
magS_filt = abs(S_filtered);
imagesc(t, f(body_idx), 20*log10(magS_filt(body_idx, :) + eps));
axis xy;
colorbar;
caxis([-80, 0]);
xlim([60, 70]);
title('Filtered: Body (100-600Hz)');
xlabel('Time (s)');
ylabel('Frequency (Hz)');

% 7-5) Filtered Spectrogram (Wire)
subplot(2,3,6);
imagesc(t, f(wire_idx), 20*log10(magS_filt(wire_idx, :) + eps));
axis xy;
colorbar;
caxis([-80, 0]);
xlim([60, 70]);
title('Filtered: Wire (3-12kHz)');
xlabel('Time (s)');
ylabel('Frequency (Hz)');

% 7-6) Spectrum comparison
subplot(2,3,4);
avg_orig = mean(magS, 2);
avg_filt = mean(magS_filt, 2);
plot(f, 20*log10(avg_orig + eps), 'b', 'LineWidth', 1.5); hold on;
plot(f, 20*log10(avg_filt + eps), 'r', 'LineWidth', 1.5);
xlim([0, 15000]);
ylim([-80, 40]);
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title('Average Spectrum');
legend('Original', 'Snare Removed');
grid on;

% 주요 대역 표시
xline(150, 'g--', 'Alpha', 0.5);
xline(300, 'g--', 'Alpha', 0.5);
xline(3000, 'm--', 'Alpha', 0.5);
xline(10000, 'm--', 'Alpha', 0.5);

sgtitle('Snare Removal v1 Analysis');

saveas(gcf, 'F:\GitHub\DrumRemoval_DSP\Graphs\SNARE\snare_removal_v1_result.png');

fprintf('시각화 완료!\n');

%% STEP 8 - 정량 분석
fprintf('\n=== 주파수 대역별 제거율 ===\n');

bands_check = {
    'Snare Body (150-300Hz)', 150, 300;
    'Snare Body Ext (300-500Hz)', 300, 500;
    'Snare Mid (1-3kHz)', 1000, 3000;
    'Snare Wire (3-10kHz)', 3000, 10000;
    'Snare Wire High (10-15kHz)', 10000, 15000;
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

fprintf('\n스네어 제거 v1 완료!\n');