%% ============================================================
%% Kick Drum Removal v6 - Onset Detection Based
%% 
%% v5 문제: Kick detection 실패
%% v6 해결: Onset detection으로 킥 타이밍 정확히 찾기
%% 
%% 전략:
%% 1. Onset detection으로 강한 transient 찾기
%% 2. 해당 시점의 저주파만 aggressive하게 제거
%% 3. STFT에서도 동일 시점 감쇠
%% ============================================================

%% STEP 0 - Load Audio
input_path = "F:\GitHub\DrumRemoval_DSP\OriginalSongs\ZZZ Camillia Golden Week OST_ CityDay [Zenless Zone Zero].mp3";
output_path = "F:\GitHub\DrumRemoval_DSP\FilteredSong\CityDay_kick_removed_v6.wav";

[x, fs] = audioread(input_path);
x = mean(x, 2);

fprintf('파일 로드: %.2f초, %dHz\n', length(x)/fs, fs);

%% STEP 1 - Onset Detection (Time Domain)
% 1-1) High-pass filtered signal (저음만 추출)
[b, a] = butter(4, 150/(fs/2), 'low');  % 150Hz 이하만
x_low = filtfilt(b, a, x);

% 1-2) Envelope extraction
env = abs(hilbert(x_low));
env_smooth = movmean(env, round(0.01*fs));  % 10ms smoothing

% 1-3) Onset detection (envelope의 급격한 증가)
env_diff = [0; diff(env_smooth)];
env_diff(env_diff < 0) = 0;  % 증가만

% 1-4) Peak finding (킥 타이밍)
min_distance = round(0.25 * fs);  % 최소 250ms 간격 (4 beats/sec)
threshold = mean(env_diff) + 2.5 * std(env_diff);  % Adaptive threshold

[~, kick_times] = findpeaks(env_diff, ...
    'MinPeakHeight', threshold, ...
    'MinPeakDistance', min_distance);

fprintf('Onset 감지: %d개 킥\n', length(kick_times));

%% STEP 2 - STFT Analysis
win_len = 2048;          % 윈도우 길이 (스칼라)
hop = 512;
nfft = 4096;
win = hann(win_len);     % 윈도우 함수 (벡터)
overlap = win_len - hop; % OverlapLength (스칼라)

[S, f, t] = stft(x, fs, 'Window', win, 'OverlapLength', overlap, 'FFTLength', nfft);

fprintf('STFT: %d frames x %d freq bins\n', size(S,2), size(S,1));

%% STEP 3 - 킥 시점을 STFT frame으로 매핑
% Time domain sample → STFT frame index
stft_kick_frames = zeros(size(t));

for i = 1:length(kick_times)
    kick_sample = kick_times(i);
    kick_time_sec = kick_sample / fs;
    
    % 가장 가까운 STFT frame 찾기
    [~, frame_idx] = min(abs(t - kick_time_sec));
    
    % 해당 frame과 주변 frames 마킹
    frame_window = 3;  % ±3 frames (약 ±35ms at 512 hop)
    start_frame = max(1, frame_idx - frame_window);
    end_frame = min(length(t), frame_idx + frame_window);
    
    stft_kick_frames(start_frame:end_frame) = 1;
end

fprintf('STFT 킥 프레임: %d/%d (%.1f%%)\n', ...
    sum(stft_kick_frames), length(stft_kick_frames), ...
    100*sum(stft_kick_frames)/length(stft_kick_frames));

%% STEP 4 - Aggressive Multi-band Removal
S_filtered = S;

% 주파수 대역 정의
sub_band = (f >= 20 & f <= 50);        % Sub-bass
fund_band = (f >= 50 & f <= 120);      % Fundamental
harm_band = (f >= 120 & f <= 300);     % Harmonics
click_band = (f >= 800 & f <= 3000);   % Click

% 감쇠 강도 (킥 구간에서만 적용)
atten_sub = 0.95;       % 95% 제거
atten_fund = 0.92;      % 92% 제거
atten_harm = 0.75;      % 75% 제거
atten_click = 0.80;     % 80% 제거

for i = 1:length(t)
    if stft_kick_frames(i) == 1
        % 킥 구간: aggressive attenuation
        S_filtered(sub_band, i) = S_filtered(sub_band, i) * (1 - atten_sub);
        S_filtered(fund_band, i) = S_filtered(fund_band, i) * (1 - atten_fund);
        S_filtered(harm_band, i) = S_filtered(harm_band, i) * (1 - atten_harm);
        S_filtered(click_band, i) = S_filtered(click_band, i) * (1 - atten_click);
    end
end

%% STEP 5 - Time Domain Attack Suppression
% STFT만으로 부족한 attack을 time domain에서도 처리

x_temp = istft(S_filtered, fs, ...
    'Window', win, 'OverlapLength', overlap, 'FFTLength', nfft);
x_temp = real(x_temp);

% Length matching
if length(x_temp) > length(x)
    x_temp = x_temp(1:length(x));
elseif length(x_temp) < length(x)
    x_temp = [x_temp; zeros(length(x) - length(x_temp), 1)];
end

% Gain envelope for attack suppression
gain_env = ones(size(x_temp));

attack_duration = round(0.02 * fs);   % 20ms attack window
release_duration = round(0.15 * fs);  % 150ms release

for i = 1:length(kick_times)
    kick_idx = kick_times(i);
    
    % Attack zone (킥 타이밍 직후 20ms)
    attack_start = kick_idx;
    attack_end = min(length(gain_env), kick_idx + attack_duration);
    
    % Release zone (20ms ~ 170ms)
    release_end = min(length(gain_env), attack_end + release_duration);
    
    % Attack: 거의 제거 (5% 남김)
    gain_env(attack_start:attack_end) = ...
        min(gain_env(attack_start:attack_end), 0.05);
    
    % Release: 선형 증가
    if release_end > attack_end
        release_len = release_end - attack_end;
        ramp = linspace(0.05, 1, release_len)';
        gain_env(attack_end+1:release_end) = ...
            min(gain_env(attack_end+1:release_end), ramp);
    end
end

% Smooth gain envelope
gain_env = movmean(gain_env, round(0.005 * fs));  % 5ms smoothing

% Apply gain
x_filtered = x_temp .* gain_env;

% Normalize
x_filtered = x_filtered / max(abs(x_filtered)) * 0.95;

%% STEP 6 - Save Output
audiowrite(output_path, x_filtered, fs);

fprintf('\n=== v6 완료 ===\n');
fprintf('출력: %s\n', output_path);

%% STEP 7 - Visualization
figure('Position', [100, 100, 1400, 800]);

% 7-1) Onset detection 결과
subplot(3,1,1);
time_vec = (0:length(x)-1) / fs;
plot(time_vec, x, 'b', 'LineWidth', 0.5); hold on;
plot(time_vec, env_smooth, 'r', 'LineWidth', 1.5);
scatter(kick_times/fs, env_smooth(kick_times), 100, 'g', 'filled');
xlim([60, 70]);  % 60-70초 구간만
xlabel('Time (s)');
ylabel('Amplitude');
title('Onset Detection Result');
legend('Original', 'Envelope', 'Detected Kicks');
grid on;

% 7-2) Gain envelope
subplot(3,1,2);
plot(time_vec, gain_env, 'r', 'LineWidth', 1.5);
xlim([60, 70]);
ylim([0, 1.1]);
xlabel('Time (s)');
ylabel('Gain');
title('Time-domain Gain Envelope');
grid on;

% 7-3) Waveform 비교
subplot(3,1,3);
plot(time_vec, x, 'b', 'LineWidth', 0.8); hold on;
plot(time_vec, x_filtered, 'r', 'LineWidth', 0.8);
xlim([60, 65]);
xlabel('Time (s)');
ylabel('Amplitude');
title('Waveform Comparison (60-65s)');
legend('Original', 'v6 Filtered');
grid on;

saveas(gcf, 'F:\GitHub\DrumRemoval_DSP\Graphs\v6_onset_detection.png');

disp('시각화 완료!');