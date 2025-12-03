%% ============================================================
%% Kick Drum Removal v5 - Improved STFT Direct Removal
%% 
%% v1의 문제점 개선:
%% 1. Kick detection을 더 정교하게 (에너지 + 주파수 특성)
%% 2. Adaptive threshold (고정값 대신 동적 계산)
%% 3. Multi-band processing (fundamental + harmonics 동시 제거)
%% 4. Temporal masking (킥 전후 구간도 처리)
%% ============================================================

%% STEP 0 - Load Audio File
input_path = "F:\GitHub\DrumRemoval_DSP\OriginalSongs\ZZZ Camillia Golden Week OST_ CityDay [Zenless Zone Zero].mp3";
output_path = "F:\GitHub\DrumRemoval_DSP\FilteredSong\CityDay_kick_removed_v5.wav";

[x, fs] = audioread(input_path);
x = mean(x, 2);  % Stereo to Mono

fprintf('파일 로드 완료: %.2f초, %d Hz\n', length(x)/fs, fs);

%% STEP 1 - STFT Analysis
win_len = 2048;         % 윈도우 길이 (스칼라)
hop = 512;              % Overlap 75%
nfft = 4096;            % Zero-padding으로 주파수 해상도 증가
win = hann(win_len);    % 윈도우 함수 (벡터)
overlap = win_len - hop; % OverlapLength (스칼라)

[S, f, t] = stft(x, fs, 'Window', win, 'OverlapLength', overlap, 'FFTLength', nfft);
magS = abs(S);
phaseS = angle(S);

fprintf('STFT 완료: %d frames, %d freq bins\n', size(S,2), size(S,1));

%% STEP 2 - Improved Kick Detection
% 킥 드럼의 여러 특성을 동시에 고려

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

% 2-4) Kick detection score (3가지 특성의 가중 평균)
kick_score = 0.6 * energy_fund_norm + ...    % Fundamental이 가장 중요
             0.2 * energy_sub_norm + ...     % Sub-bass
             0.2 * energy_click_norm;        % Click

% 2-5) Adaptive threshold (percentile 기반)
% 상위 30%의 에너지를 킥으로 판단
kick_threshold = prctile(kick_score, 70);  
kick_frames = kick_score > kick_threshold;

fprintf('킥 프레임 감지: %d/%d (%.1f%%)\n', ...
    sum(kick_frames), length(kick_frames), ...
    100*sum(kick_frames)/length(kick_frames));

%% STEP 3 - Multi-band Adaptive Attenuation
S_filtered = S;  % 복사본 생성

% 감쇠 파라미터 (주파수 대역별로 다르게)
atten_fund = 0.90;      % Fundamental: 90% 제거
atten_sub = 0.85;       % Sub-bass: 85% 제거
atten_click = 0.75;     % Click: 75% 제거
atten_harmonic = 0.70;  % Harmonics: 70% 제거

% 추가 대역 정의
kick_harm_band = (f >= 120 & f <= 250);  % 2nd, 3rd harmonics

for i = 1:length(t)
    if kick_frames(i)
        % Temporal masking: 킥 전후 프레임도 약하게 처리
        % 현재 프레임만 강하게, 앞뒤는 약하게
        temporal_weight = 1.0;
        
        % 이전/다음 프레임 처리를 위한 인덱스
        if i > 1 && ~kick_frames(i-1)
            % 이전 프레임이 킥이 아니면 약하게 처리
            prev_weight = 0.3;
            S_filtered(kick_fund_band, i-1) = S_filtered(kick_fund_band, i-1) * (1 - atten_fund * prev_weight);
        end
        
        if i < length(t) && ~kick_frames(i+1)
            % 다음 프레임이 킥이 아니면 약하게 처리
            next_weight = 0.3;
            S_filtered(kick_fund_band, i+1) = S_filtered(kick_fund_band, i+1) * (1 - atten_fund * next_weight);
        end
        
        % 현재 프레임 강하게 처리
        S_filtered(kick_sub_band, i) = S_filtered(kick_sub_band, i) * (1 - atten_sub * temporal_weight);
        S_filtered(kick_fund_band, i) = S_filtered(kick_fund_band, i) * (1 - atten_fund * temporal_weight);
        S_filtered(kick_harm_band, i) = S_filtered(kick_harm_band, i) * (1 - atten_harmonic * temporal_weight);
        S_filtered(kick_click_band, i) = S_filtered(kick_click_band, i) * (1 - atten_click * temporal_weight);
    end
end

%% STEP 4 - Spectral Smoothing (Artifact 제거)
% 급격한 스펙트럼 변화를 부드럽게
for i = 2:size(S_filtered, 2)-1
    % 시간축 smoothing (3-point moving average)
    S_filtered(:, i) = 0.5 * S_filtered(:, i) + ...
                       0.25 * S_filtered(:, i-1) + ...
                       0.25 * S_filtered(:, i+1);
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
x_filtered = x_filtered / max(abs(x_filtered)) * 0.95;  % 95%로 정규화 (clipping 방지)

%% STEP 6 - Save Output
audiowrite(output_path, x_filtered, fs);

fprintf('\n=== v5 완료 ===\n');
fprintf('출력 파일: %s\n', output_path);
fprintf('처리 시간: %.2f초\n', length(x_filtered)/fs);

%% STEP 7 - Quick Visualization (선택사항)
% 결과 확인을 위한 간단한 스펙트럼 비교
figure('Position', [100, 100, 1200, 400]);

% Original
subplot(1,2,1);
imagesc(t, f(1:500), 20*log10(magS(1:500, :) + eps));
axis xy;
colorbar;
caxis([-80, 0]);
title('Original Spectrogram (0-500Hz)');
xlabel('Time (s)');
ylabel('Frequency (Hz)');

% Filtered
subplot(1,2,2);
magS_filt = abs(stft(x_filtered, fs, 'Window', win, 'OverlapLength', overlap, 'FFTLength', nfft));
imagesc(t, f(1:500), 20*log10(magS_filt(1:500, :) + eps));
axis xy;
colorbar;
caxis([-80, 0]);
title('Filtered v5 Spectrogram (0-500Hz)');
xlabel('Time (s)');
ylabel('Frequency (Hz)');

saveas(gcf, 'F:\GitHub\DrumRemoval_DSP\Graphs\v5_spectrogram_comparison.png');

disp('스펙트로그램 저장 완료!');