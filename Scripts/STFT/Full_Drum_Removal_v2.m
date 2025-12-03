%% ============================================================
%% Full Drum Removal v2 - HPSS 분석 기반
%% 
%% HPSS 분석 결과:
%% - KICK: 22-86 Hz (피크: 43.1 Hz)
%% - SNARE: 90-301 Hz (피크: 150.7 Hz)
%% - HI-HAT: 피크 없음 → 제외
%% ============================================================

%% STEP 0 - Load Audio
input_path = "F:\GitHub\DrumRemoval_DSP\OriginalSongs\ZZZ Camillia Golden Week OST_ CityDay [Zenless Zone Zero].mp3";
output_path = "F:\GitHub\DrumRemoval_DSP\FilteredSong\CityDay_all_drums_removed_v2.wav";

[x, fs] = audioread(input_path);
x = mean(x, 2);

fprintf('=== Full Drum Removal v2 (HPSS 분석 기반) ===\n');
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
%% STEP 2 - KICK DETECTION (HPSS 분석 기반: 22-86 Hz)
%% ============================================================
fprintf('\n[1/2] Kick Detection (22-86 Hz)...\n');

% HPSS 분석 결과 기반 Kick 대역
kick_band = (f >= 22 & f <= 86);

% 에너지 계산
energy_kick = sum(magS(kick_band, :), 1);
energy_kick_norm = energy_kick / max(energy_kick);

% Kick score (단순화)
kick_score = energy_kick_norm;

% Threshold
kick_threshold = prctile(kick_score, 70);
kick_frames = kick_score > kick_threshold;

fprintf('  킥 프레임: %d/%d (%.1f%%)\n', ...
    sum(kick_frames), length(kick_frames), ...
    100*sum(kick_frames)/length(kick_frames));

%% ============================================================
%% STEP 3 - SNARE DETECTION (HPSS 분석 기반: 90-301 Hz)
%% ============================================================
fprintf('[2/2] Snare Detection (90-301 Hz)...\n');

% HPSS 분석 결과 기반 Snare 대역
snare_band = (f >= 90 & f <= 301);

% 에너지 계산
energy_snare = sum(magS(snare_band, :), 1);
energy_snare_norm = energy_snare / max(energy_snare);

% Snare score (단순화)
snare_score = energy_snare_norm;

% Threshold
snare_threshold = prctile(snare_score, 70);
snare_frames = snare_score > snare_threshold;

fprintf('  스네어 프레임: %d/%d (%.1f%%)\n', ...
    sum(snare_frames), length(snare_frames), ...
    100*sum(snare_frames)/length(snare_frames));

%% ============================================================
%% STEP 4 - INTEGRATED REMOVAL (KICK + SNARE only)
%% ============================================================
fprintf('\n드럼 제거 처리 중 (KICK + SNARE)...\n');

S_filtered = S;

% HPSS 분석 기반 주파수 대역만 사용
band_kick = (f >= 22 & f <= 86);      % 킥: 22-86 Hz
band_snare = (f >= 90 & f <= 301);    % 스네어: 90-301 Hz

% 감쇠 강도
atten_kick = 0.95;    % 95% 감쇠
atten_snare = 0.90;   % 90% 감쇠

% Frame-by-frame 처리
for i = 1:length(t)
    % KICK 제거
    if kick_frames(i)
        S_filtered(band_kick, i) = S_filtered(band_kick, i) * (1 - atten_kick);
    end
    
    % SNARE 제거
    if snare_frames(i)
        S_filtered(band_snare, i) = S_filtered(band_snare, i) * (1 - atten_snare);
    end
end

%% STEP 5 - Spectral Smoothing
fprintf('Spectral smoothing...\n');
for i = 3:size(S_filtered, 2)-2
    S_filtered(:, i) = 0.4 * S_filtered(:, i) + ...
                       0.2 * S_filtered(:, i-1) + ...
                       0.2 * S_filtered(:, i+1) + ...
                       0.1 * S_filtered(:, i-2) + ...
                       0.1 * S_filtered(:, i+2);
end

%% STEP 6 - iSTFT
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

%% STEP 7 - Save Output
audiowrite(output_path, x_filtered, fs);

fprintf('\n=== Full Drum Removal v2 완료 ===\n');
fprintf('출력 파일: %s\n', output_path);

%% STEP 8 - Visualization
fprintf('시각화 생성 중...\n');

figure('Position', [100, 100, 1400, 800]);

% 8-1) Detection Results
subplot(2,3,1);
plot(t, kick_score, 'b', 'LineWidth', 1); hold on;
plot(t, snare_score, 'r', 'LineWidth', 1);
yline(kick_threshold, 'b--', 'LineWidth', 1);
yline(snare_threshold, 'r--', 'LineWidth', 1);
xlim([60, 70]);
xlabel('Time (s)');
ylabel('Detection Score');
title('Drum Detection Scores');
legend('Kick (22-86Hz)', 'Snare (90-301Hz)', 'Location', 'best');
grid on;

% 8-2) Original Spectrogram (Low Freq)
subplot(2,3,2);
imagesc(t, f(f<=500), 20*log10(magS(f<=500, :) + eps));
axis xy;
colorbar;
caxis([-80, 0]);
xlim([60, 70]);
title('Original (0-500Hz)');
xlabel('Time (s)');
ylabel('Frequency (Hz)');

% 8-3) Filtered Spectrogram (Low Freq)
subplot(2,3,3);
magS_filt = abs(S_filtered);
imagesc(t, f(f<=500), 20*log10(magS_filt(f<=500, :) + eps));
axis xy;
colorbar;
caxis([-80, 0]);
xlim([60, 70]);
title('Filtered (0-500Hz)');
xlabel('Time (s)');
ylabel('Frequency (Hz)');

% 8-4) Spectrum Comparison
subplot(2,3,4);
avg_orig = mean(magS, 2);
avg_filt = mean(magS_filt, 2);
plot(f, 20*log10(avg_orig + eps), 'b', 'LineWidth', 1.5); hold on;
plot(f, 20*log10(avg_filt + eps), 'r', 'LineWidth', 1.5);
xlim([0, 500]);
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title('Average Spectrum (0-500Hz)');
legend('Original', 'Filtered');
grid on;

% 대역 표시
xline(22, 'g--', 'LineWidth', 1.5);
xline(86, 'g--', 'LineWidth', 1.5);
xline(90, 'm--', 'LineWidth', 1.5);
xline(301, 'm--', 'LineWidth', 1.5);

% 8-5) Drum Detection Mask
subplot(2,3,5);
frame_start = find(t >= 60, 1);
frame_end = find(t >= 70, 1);
if isempty(frame_end)
    frame_end = length(t);
end

time_axis = 1:length(t);
plot(time_axis(kick_frames), ones(sum(kick_frames),1)*2, 'b.', 'MarkerSize', 5); hold on;
plot(time_axis(snare_frames), ones(sum(snare_frames),1)*1, 'r.', 'MarkerSize', 5);
xlim([frame_start, frame_end]);
ylim([0, 3]);
yticks([1, 2]);
yticklabels({'Snare', 'Kick'});
xlabel('Frame Index');
title('Detected Drum Events');
grid on;

% 8-6) Waveform Comparison
subplot(2,3,6);
time_samples = round(60*fs):round(62*fs);  % 60-62초 구간
plot((time_samples-time_samples(1))/fs, x(time_samples), 'b', 'LineWidth', 0.5); hold on;
plot((time_samples-time_samples(1))/fs, x_filtered(time_samples), 'r', 'LineWidth', 0.5);
xlabel('Time (s)');
ylabel('Amplitude');
title('Waveform Comparison (60-62s)');
legend('Original', 'Filtered');

sgtitle('Full Drum Removal v2 - HPSS 분석 기반 (KICK + SNARE only)');

saveas(gcf, 'F:\GitHub\DrumRemoval_DSP\Graphs\full_drum_removal_v2_result.png');

fprintf('시각화 완료!\n');

%% STEP 9 - 정량 분석
fprintf('\n=== 제거 효과 분석 ===\n');

analysis_bands = {
    'Kick (22-86Hz)', 22, 86;
    'Snare (90-301Hz)', 90, 301;
};

fprintf('\n%-25s | %-10s\n', '대역', '제거율');
fprintf('%s\n', repmat('-', 1, 40));

for b = 1:size(analysis_bands, 1)
    band_name = analysis_bands{b, 1};
    low_f = analysis_bands{b, 2};
    high_f = analysis_bands{b, 3};
    
    band_mask = (f >= low_f & f <= high_f);
    
    orig_energy = mean(magS(band_mask, :), 'all');
    filt_energy = mean(magS_filt(band_mask, :), 'all');
    
    reduction = (1 - filt_energy/orig_energy) * 100;
    
    fprintf('%-25s | %9.2f%%\n', band_name, reduction);
end

fprintf('\n=== Full Drum Removal v2 완료! ===\n');
fprintf('HPSS 분석 기반 주파수만 사용:\n');
fprintf('  KICK:  22-86 Hz\n');
fprintf('  SNARE: 90-301 Hz\n');
fprintf('  HI-HAT: 제외 (피크 없음)\n');