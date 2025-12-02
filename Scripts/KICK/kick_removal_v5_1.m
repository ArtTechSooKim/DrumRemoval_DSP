%% ============================================================
%% Kick Drum Removal v5.1 - Enhanced STFT Direct Removal
%% 
%% v5 문제: 감쇠가 너무 약함 (킥 16.51%만 제거)
%% v5.1 해결: 
%%   1. Threshold 낮추기 (70% → 50%)
%%   2. 감쇠 강도 증가
%%   3. 더 넓은 주파수 대역 처리
%% ============================================================

%% STEP 0 - Load Audio File
input_path = "F:\GitHub\DrumRemoval_DSP\OriginalSongs\ZZZ Camillia Golden Week OST_ CityDay [Zenless Zone Zero].mp3";
output_path = "F:\GitHub\DrumRemoval_DSP\FilteredSong\CityDay_kick_removed_v5_1.wav";

[x, fs] = audioread(input_path);
x = mean(x, 2);  % Stereo to Mono

fprintf('파일 로드 완료: %.2f초, %d Hz\n', length(x)/fs, fs);

%% STEP 1 - STFT Analysis
win_len = 2048;         % 윈도우 길이 (스칼라)
hop = 512;              % Hop size
nfft = 4096;            % FFT length
win = hann(win_len);    % 윈도우 함수 (벡터)
overlap = win_len - hop; % OverlapLength (스칼라)

[S, f, t] = stft(x, fs, 'Window', win, 'OverlapLength', overlap, 'FFTLength', nfft);
magS = abs(S);
phaseS = angle(S);

fprintf('STFT 완료: %d frames, %d freq bins\n', size(S,2), size(S,1));


%% STEP 2 - Enhanced Kick Detection
% v5보다 더 많은 킥 프레임을 찾기

% 2-1) Kick fundamental band (50-120Hz)
kick_fund_band = (f >= 50 & f <= 120);

% 2-2) Kick sub-harmonic (30-50Hz) - 매우 낮은 저음
kick_sub_band = (f >= 30 & f <= 50);

% 2-3) Kick click (1-3kHz) - 비터의 클릭음
kick_click_band = (f >= 1000 & f <= 3000);

% 각 대역의 에너지 계산
energy_fund = sum(magS(kick_fund_band, :), 1);    % Fundamental
energy_sub = sum(magS(kick_sub_band, :), 1);      % Sub
energy_click = sum(magS(kick_click_band, :), 1);  % Click

% Normalize
energy_fund_norm = energy_fund / max(energy_fund);
energy_sub_norm = energy_sub / max(energy_sub);
energy_click_norm = energy_click / max(energy_click);

% 2-4) Kick detection score (가중치 조정 - Fundamental 비중 증가)
kick_score = 0.7 * energy_fund_norm + ...    % v5: 0.6 → 0.7
             0.2 * energy_sub_norm + ...
             0.1 * energy_click_norm;        % v5: 0.2 → 0.1

% *** 핵심 변경: Threshold 대폭 낮춤 ***
kick_threshold = prctile(kick_score, 50);  % v5: 70% → 50%
% 상위 50%를 킥으로 판단 (더 많은 프레임 처리)

kick_frames = kick_score > kick_threshold;

fprintf('킥 프레임 감지: %d/%d (%.1f%%) - threshold: %.4f\n', ...
    sum(kick_frames), length(kick_frames), ...
    100*sum(kick_frames)/length(kick_frames), kick_threshold);


%% STEP 3 - Aggressive Multi-band Attenuation
S_filtered = S;  % 복사본 생성

% 주파수 대역 (v5보다 범위 확대)
sub_band = (f >= 25 & f <= 50);        % v5: 30-50 → 25-50
fund_band = (f >= 50 & f <= 130);      % v5: 50-120 → 50-130
harm_band = (f >= 130 & f <= 350);     % v5: 120-250 → 130-350
click_band = (f >= 800 & f <= 3500);   % v5: 1000-3000 → 800-3500

% *** 핵심 변경: 감쇠 강도 대폭 증가 ***
atten_sub = 0.97;       % v5: 0.85 → 0.97 (97% 제거)
atten_fund = 0.95;      % v5: 0.90 → 0.95 (95% 제거)
atten_harm = 0.85;      % v5: 0.70 → 0.85 (85% 제거)
atten_click = 0.88;     % v5: 0.75 → 0.88 (88% 제거)

% Temporal context 추가
temporal_window = 2;  % v5: 1 → 2 frames

for i = 1:length(t)
    if kick_frames(i)
        % 현재 프레임 강하게 처리
        S_filtered(sub_band, i) = S_filtered(sub_band, i) * (1 - atten_sub);
        S_filtered(fund_band, i) = S_filtered(fund_band, i) * (1 - atten_fund);
        S_filtered(harm_band, i) = S_filtered(harm_band, i) * (1 - atten_harm);
        S_filtered(click_band, i) = S_filtered(click_band, i) * (1 - atten_click);
        
        % 이전/다음 프레임도 처리 (약하게)
        for offset = -temporal_window:temporal_window
            idx = i + offset;
            if idx >= 1 && idx <= length(t) && offset ~= 0
                weight = 0.4;  % v5: 0.3 → 0.4 (40% 강도로 주변 처리)
                S_filtered(sub_band, idx) = S_filtered(sub_band, idx) * (1 - atten_sub * weight);
                S_filtered(fund_band, idx) = S_filtered(fund_band, idx) * (1 - atten_fund * weight);
                S_filtered(harm_band, idx) = S_filtered(harm_band, idx) * (1 - atten_harm * weight);
                S_filtered(click_band, idx) = S_filtered(click_band, idx) * (1 - atten_click * weight);
            end
        end
    end
end


%% STEP 4 - Enhanced Spectral Smoothing (Artifact 제거)
% v5보다 더 강한 smoothing
for i = 3:size(S_filtered, 2)-2
    % 5-point smoothing (v5는 3-point)
    S_filtered(:, i) = 0.4 * S_filtered(:, i) + ...
                       0.2 * S_filtered(:, i-1) + ...
                       0.2 * S_filtered(:, i+1) + ...
                       0.1 * S_filtered(:, i-2) + ...
                       0.1 * S_filtered(:, i+2);
end

%% STEP 5 - iSTFT Reconstruction
x_filtered = istft(S_filtered, fs, ...
    'Window', win, 'OverlapLength', overlap, 'FFTLength', nfft);

% Real-valued signal
x_filtered = real(x_filtered);

% Length matching (원본과 길이 맞추기)
if length(x_filtered) > length(x)
    x_filtered = x_filtered(1:length(x));
elseif length(x_filtered) < length(x)
    x_filtered = [x_filtered; zeros(length(x) - length(x_filtered), 1)];
end

% Normalize
x_filtered = x_filtered / max(abs(x_filtered)) * 0.95;  % 95%로 정규화

%% STEP 6 - Save Output
audiowrite(output_path, x_filtered, fs);

fprintf('\n=== v5.1 완료 ===\n');
fprintf('출력 파일: %s\n', output_path);
fprintf('처리 시간: %.2f초\n', length(x_filtered)/fs);

% %% STEP 7 - Visualization
% figure('Position', [100, 100, 1400, 600]);
% 
% % 7-1) Kick detection score
% subplot(2,2,1);
% plot(t, kick_score, 'b', 'LineWidth', 1); hold on;
% yline(kick_threshold, 'r--', 'LineWidth', 2);
% scatter(t(kick_frames), kick_score(kick_frames), 20, 'g', 'filled');
% xlim([60, 70]);
% xlabel('Time (s)');
% ylabel('Kick Score');
% title(sprintf('Kick Detection (threshold=%.4f)', kick_threshold));
% legend('Kick Score', 'Threshold', 'Detected Frames');
% grid on;
% 
% % 7-2) Original Spectrogram (저주파)
% subplot(2,2,2);
% low_freq_idx = f <= 300;
% imagesc(t, f(low_freq_idx), 20*log10(magS(low_freq_idx, :) + eps));
% axis xy;
% colorbar;
% caxis([-80, 0]);
% xlim([60, 70]);
% title('Original Spectrogram (0-300Hz)');
% xlabel('Time (s)');
% ylabel('Frequency (Hz)');
% 
% % 7-3) Filtered Spectrogram (저주파)
% subplot(2,2,3);
% magS_filt = abs(S_filtered);
% imagesc(t, f(low_freq_idx), 20*log10(magS_filt(low_freq_idx, :) + eps));
% axis xy;
% colorbar;
% caxis([-80, 0]);
% xlim([60, 70]);
% title('Filtered v5.1 Spectrogram (0-300Hz)');
% xlabel('Time (s)');
% ylabel('Frequency (Hz)');
% 
% % 7-4) 주파수 스펙트럼 비교 (킥 대역)
% subplot(2,2,4);
% avg_orig = mean(magS, 2);
% avg_filt = mean(magS_filt, 2);
% plot(f, 20*log10(avg_orig + eps), 'b', 'LineWidth', 2); hold on;
% plot(f, 20*log10(avg_filt + eps), 'r', 'LineWidth', 2);
% xlim([25, 150]);
% xlabel('Frequency (Hz)');
% ylabel('Magnitude (dB)');
% title('Kick Band Comparison (25-150Hz)');
% legend('Original', 'v5.1 Filtered');
% grid on;
% 
% saveas(gcf, 'F:\GitHub\DrumRemoval_DSP\Graphs\v5_1_analysis.png');
% 
% fprintf('시각화 완료!\n');

% %% STEP 8 - 정량 분석 출력
% fprintf('\n=== 주파수 대역별 제거율 분석 ===\n');
% 
% bands_check = {
%     'Sub-bass (25-50Hz)', 25, 50;
%     'Fundamental (50-130Hz)', 50, 130;
%     'Harmonics (130-350Hz)', 130, 350;
%     'Click (800-3500Hz)', 800, 3500;
% };
% 
% for b = 1:size(bands_check, 1)
%     band_name = bands_check{b, 1};
%     low_f = bands_check{b, 2};
%     high_f = bands_check{b, 3};
% 
%     band_mask = (f >= low_f & f <= high_f);
% 
%     orig_energy = mean(magS(band_mask, :), 'all');
%     filt_energy = mean(magS_filt(band_mask, :), 'all');
% 
%     reduction = (1 - filt_energy/orig_energy) * 100;
% 
%     fprintf('%s: %.2f%% 제거\n', band_name, reduction);
% end
% 
% fprintf('\n분석 완료!\n');