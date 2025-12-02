%% ============================================================
%% Full Drum Removal v2 - Two-Pass Iterative Filtering
%% 
%% 전략:
%% 1. Pass 1: 전체 드럼 제거 (v1과 동일)
%% 2. Pass 2: Pass 1 결과를 다시 입력으로 넣어서 한 번 더 제거
%% 
%% 장점:
%% - 1차에서 못 잡은 드럼도 2차에서 제거
%% - 더 강력한 제거 효과
%% 
%% 주의:
%% - 과도한 제거 가능성 있음 (음질 손상)
%% ============================================================

%% STEP 0 - Load Audio
input_path = "F:\GitHub\DrumRemoval_DSP\OriginalSongs\ZZZ Camillia Golden Week OST_ CityDay [Zenless Zone Zero].mp3";
output_path = "F:\GitHub\DrumRemoval_DSP\FilteredSong\CityDay_all_drums_removed_v2_2pass.wav";

[x, fs] = audioread(input_path);
x = mean(x, 2);

fprintf('=== Full Drum Removal v2 - Two-Pass ===\n');
fprintf('파일 로드: %.2f초, %dHz\n\n', length(x)/fs, fs);

%% ============================================================
%% PASS 1: 첫 번째 드럼 제거
%% ============================================================
fprintf('===== PASS 1 시작 =====\n');

x_pass1 = process_drum_removal(x, fs);

fprintf('PASS 1 완료!\n\n');

%% ============================================================
%% PASS 2: 두 번째 드럼 제거 (Pass 1 결과 재처리)
%% ============================================================
fprintf('===== PASS 2 시작 =====\n');

x_pass2 = process_drum_removal(x_pass1, fs);

fprintf('PASS 2 완료!\n\n');

%% STEP - Save Output
audiowrite(output_path, x_pass2, fs);

fprintf('=== Two-Pass 드럼 제거 완료 ===\n');
fprintf('출력 파일: %s\n', output_path);

%% STEP - Visualization (Original vs Pass1 vs Pass2)
fprintf('\n3-way 비교 시각화 중...\n');

% STFT for comparison
win_len = 2048;
hop = 512;
nfft = 4096;
win = hann(win_len);
overlap = win_len - hop;

% 분석 구간
start_t = 60;
end_t = 70;
start_idx = floor(start_t * fs);
end_idx = floor(end_t * fs);

x_seg = x(start_idx:end_idx);
x_pass1_seg = x_pass1(start_idx:end_idx);
x_pass2_seg = x_pass2(start_idx:end_idx);

[S_orig, f, t] = stft(x_seg, fs, 'Window', win, 'OverlapLength', overlap, 'FFTLength', nfft);
[S_pass1, ~, ~] = stft(x_pass1_seg, fs, 'Window', win, 'OverlapLength', overlap, 'FFTLength', nfft);
[S_pass2, ~, ~] = stft(x_pass2_seg, fs, 'Window', win, 'OverlapLength', overlap, 'FFTLength', nfft);

magS_orig = abs(S_orig);
magS_pass1 = abs(S_pass1);
magS_pass2 = abs(S_pass2);

figure('Position', [100, 100, 1600, 1000]);

% 1) Spectrogram 비교 (Low Freq)
subplot(3,3,1);
imagesc(t, f(f<=500), 20*log10(magS_orig(f<=500, :) + eps));
axis xy; colorbar; caxis([-80, 0]);
title('Original (0-500Hz)');
xlabel('Time (s)'); ylabel('Frequency (Hz)');

subplot(3,3,2);
imagesc(t, f(f<=500), 20*log10(magS_pass1(f<=500, :) + eps));
axis xy; colorbar; caxis([-80, 0]);
title('Pass 1 (0-500Hz)');
xlabel('Time (s)'); ylabel('Frequency (Hz)');

subplot(3,3,3);
imagesc(t, f(f<=500), 20*log10(magS_pass2(f<=500, :) + eps));
axis xy; colorbar; caxis([-80, 0]);
title('Pass 2 (0-500Hz)');
xlabel('Time (s)'); ylabel('Frequency (Hz)');

% 2) Spectrogram 비교 (High Freq)
subplot(3,3,4);
high_idx = (f >= 5000 & f <= 20000);
imagesc(t, f(high_idx), 20*log10(magS_orig(high_idx, :) + eps));
axis xy; colorbar; caxis([-80, 0]);
title('Original (5-20kHz)');
xlabel('Time (s)'); ylabel('Frequency (Hz)');

subplot(3,3,5);
imagesc(t, f(high_idx), 20*log10(magS_pass1(high_idx, :) + eps));
axis xy; colorbar; caxis([-80, 0]);
title('Pass 1 (5-20kHz)');
xlabel('Time (s)'); ylabel('Frequency (Hz)');

subplot(3,3,6);
imagesc(t, f(high_idx), 20*log10(magS_pass2(high_idx, :) + eps));
axis xy; colorbar; caxis([-80, 0]);
title('Pass 2 (5-20kHz)');
xlabel('Time (s)'); ylabel('Frequency (Hz)');

% 3) Spectrum 비교
subplot(3,3,7);
avg_orig = mean(magS_orig, 2);
avg_pass1 = mean(magS_pass1, 2);
avg_pass2 = mean(magS_pass2, 2);

plot(f, 20*log10(avg_orig + eps), 'b', 'LineWidth', 1.5); hold on;
plot(f, 20*log10(avg_pass1 + eps), 'r', 'LineWidth', 1.5);
plot(f, 20*log10(avg_pass2 + eps), 'g', 'LineWidth', 1.5);
xlim([0, 20000]); ylim([-80, 40]);
xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
title('Full Spectrum Comparison');
legend('Original', 'Pass 1', 'Pass 2');
grid on;

% 4) Low Freq Zoom
subplot(3,3,8);
plot(f, 20*log10(avg_orig + eps), 'b', 'LineWidth', 2); hold on;
plot(f, 20*log10(avg_pass1 + eps), 'r', 'LineWidth', 2);
plot(f, 20*log10(avg_pass2 + eps), 'g', 'LineWidth', 2);
xlim([0, 500]);
xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
title('Low Freq (Kick/Snare)');
legend('Original', 'Pass 1', 'Pass 2');
grid on;

% 5) High Freq Zoom
subplot(3,3,9);
plot(f, 20*log10(avg_orig + eps), 'b', 'LineWidth', 2); hold on;
plot(f, 20*log10(avg_pass1 + eps), 'r', 'LineWidth', 2);
plot(f, 20*log10(avg_pass2 + eps), 'g', 'LineWidth', 2);
xlim([8000, 20000]);
xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
title('High Freq (Hi-Hat)');
legend('Original', 'Pass 1', 'Pass 2');
grid on;

sgtitle('Two-Pass Drum Removal - Comparison');

saveas(gcf, 'F:\GitHub\DrumRemoval_DSP\Graphs\full_drum_removal_v2_2pass_result.png');

fprintf('시각화 완료!\n');

%% ============================================================
%% Helper Function: Drum Removal Processing
%% ============================================================
function x_filtered = process_drum_removal(x, fs)
    % STFT
    win_len = 2048;
    hop = 512;
    nfft = 4096;
    win = hann(win_len);
    overlap = win_len - hop;
    
    [S, f, t] = stft(x, fs, 'Window', win, 'OverlapLength', overlap, 'FFTLength', nfft);
    magS = abs(S);
    
    fprintf('  STFT 완료: %d frames x %d bins\n', size(S,2), size(S,1));
    
    % === KICK DETECTION ===
    kick_fund_band = (f >= 50 & f <= 120);
    kick_sub_band = (f >= 30 & f <= 50);
    kick_click_band = (f >= 1000 & f <= 3000);
    
    energy_kick_fund = sum(magS(kick_fund_band, :), 1);
    energy_kick_sub = sum(magS(kick_sub_band, :), 1);
    energy_kick_click = sum(magS(kick_click_band, :), 1);
    
    energy_kick_fund_norm = energy_kick_fund / max(energy_kick_fund);
    energy_kick_sub_norm = energy_kick_sub / max(energy_kick_sub);
    energy_kick_click_norm = energy_kick_click / max(energy_kick_click);
    
    kick_score = 0.6 * energy_kick_fund_norm + ...
                 0.2 * energy_kick_sub_norm + ...
                 0.2 * energy_kick_click_norm;
    
    kick_threshold = prctile(kick_score, 70);
    kick_frames = kick_score > kick_threshold;
    
    fprintf('  킥: %d/%d (%.1f%%)\n', sum(kick_frames), length(kick_frames), ...
        100*sum(kick_frames)/length(kick_frames));
    
    % === SNARE DETECTION ===
    snare_body_band = (f >= 150 & f <= 300);
    snare_mid_band = (f >= 1000 & f <= 3000);
    snare_wire_band = (f >= 3000 & f <= 10000);
    
    energy_snare_body = sum(magS(snare_body_band, :), 1);
    energy_snare_mid = sum(magS(snare_mid_band, :), 1);
    energy_snare_wire = sum(magS(snare_wire_band, :), 1);
    
    energy_snare_body_norm = energy_snare_body / max(energy_snare_body);
    energy_snare_mid_norm = energy_snare_mid / max(energy_snare_mid);
    energy_snare_wire_norm = energy_snare_wire / max(energy_snare_wire);
    
    snare_score = 0.2 * energy_snare_body_norm + ...
                  0.2 * energy_snare_mid_norm + ...
                  0.6 * energy_snare_wire_norm;
    
    snare_threshold = prctile(snare_score, 70);
    snare_frames = snare_score > snare_threshold;
    
    fprintf('  스네어: %d/%d (%.1f%%)\n', sum(snare_frames), length(snare_frames), ...
        100*sum(snare_frames)/length(snare_frames));
    
    % === HI-HAT DETECTION ===
    hihat_low_band = (f >= 6000 & f <= 10000);
    hihat_mid_band = (f >= 10000 & f <= 15000);
    hihat_high_band = (f >= 15000 & f <= 20000);
    
    energy_hihat_low = sum(magS(hihat_low_band, :), 1);
    energy_hihat_mid = sum(magS(hihat_mid_band, :), 1);
    energy_hihat_high = sum(magS(hihat_high_band, :), 1);
    
    energy_hihat_low_norm = energy_hihat_low / max(energy_hihat_low);
    energy_hihat_mid_norm = energy_hihat_mid / max(energy_hihat_mid);
    energy_hihat_high_norm = energy_hihat_high / max(energy_hihat_high);
    
    hihat_score = 0.3 * energy_hihat_low_norm + ...
                  0.5 * energy_hihat_mid_norm + ...
                  0.2 * energy_hihat_high_norm;
    
    hihat_threshold = prctile(hihat_score, 75);
    hihat_frames = hihat_score > hihat_threshold;
    
    fprintf('  하이햇: %d/%d (%.1f%%)\n', sum(hihat_frames), length(hihat_frames), ...
        100*sum(hihat_frames)/length(hihat_frames));
    
    % === MULTI-BAND REMOVAL ===
    S_filtered = S;
    
    % 대역 정의
    band_kick_sub = (f >= 25 & f <= 50);
    band_kick_fund = (f >= 50 & f <= 130);
    band_kick_harm = (f >= 130 & f <= 350);
    band_kick_click = (f >= 800 & f <= 3500);
    
    band_snare_body = (f >= 150 & f <= 300);
    band_snare_body_ext = (f >= 300 & f <= 500);
    band_snare_mid = (f >= 1000 & f <= 3000);
    band_snare_wire = (f >= 3000 & f <= 10000);
    band_snare_wire_high = (f >= 10000 & f <= 15000);
    
    band_hihat_pre = (f >= 5000 & f <= 6000);
    band_hihat_low1 = (f >= 6000 & f <= 8000);
    band_hihat_low2 = (f >= 8000 & f <= 10000);
    band_hihat_mid1 = (f >= 10000 & f <= 12000);
    band_hihat_mid2 = (f >= 12000 & f <= 15000);
    band_hihat_high1 = (f >= 15000 & f <= 18000);
    band_hihat_high2 = (f >= 18000 & f <= 20000);
    band_hihat_very_high = (f >= 20000 & f <= 22050);
    
    % 감쇠 강도
    atten_kick_sub = 0.97;
    atten_kick_fund = 0.95;
    atten_kick_harm = 0.85;
    atten_kick_click = 0.88;
    
    atten_snare_body = 0.75;
    atten_snare_body_ext = 0.60;
    atten_snare_mid = 0.80;
    atten_snare_wire = 0.92;
    atten_snare_wire_high = 0.85;
    
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
        if kick_frames(i)
            S_filtered(band_kick_sub, i) = S_filtered(band_kick_sub, i) * (1 - atten_kick_sub);
            S_filtered(band_kick_fund, i) = S_filtered(band_kick_fund, i) * (1 - atten_kick_fund);
            S_filtered(band_kick_harm, i) = S_filtered(band_kick_harm, i) * (1 - atten_kick_harm);
            S_filtered(band_kick_click, i) = S_filtered(band_kick_click, i) * (1 - atten_kick_click);
        end
        
        if snare_frames(i)
            S_filtered(band_snare_body, i) = S_filtered(band_snare_body, i) * (1 - atten_snare_body);
            S_filtered(band_snare_body_ext, i) = S_filtered(band_snare_body_ext, i) * (1 - atten_snare_body_ext);
            S_filtered(band_snare_mid, i) = S_filtered(band_snare_mid, i) * (1 - atten_snare_mid);
            S_filtered(band_snare_wire, i) = S_filtered(band_snare_wire, i) * (1 - atten_snare_wire);
            S_filtered(band_snare_wire_high, i) = S_filtered(band_snare_wire_high, i) * (1 - atten_snare_wire_high);
        end
        
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
    
    % Smoothing
    for i = 3:size(S_filtered, 2)-2
        S_filtered(:, i) = 0.4 * S_filtered(:, i) + ...
                           0.2 * S_filtered(:, i-1) + ...
                           0.2 * S_filtered(:, i+1) + ...
                           0.1 * S_filtered(:, i-2) + ...
                           0.1 * S_filtered(:, i+2);
    end
    
    % iSTFT
    x_filtered = istft(S_filtered, fs, 'Window', win, 'OverlapLength', overlap, 'FFTLength', nfft);
    x_filtered = real(x_filtered);
    
    % Length matching
    if length(x_filtered) > length(x)
        x_filtered = x_filtered(1:length(x));
    elseif length(x_filtered) < length(x)
        x_filtered = [x_filtered; zeros(length(x) - length(x_filtered), 1)];
    end
    
    % Normalize
    x_filtered = x_filtered / max(abs(x_filtered)) * 0.95;
end