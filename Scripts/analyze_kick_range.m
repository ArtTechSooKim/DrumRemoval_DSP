%% ============================================================
% analyze_kick_range.m
% CityDay의 01:00~01:10 구간에서 Kick 주파수 Peak 분석
% ============================================================

%% 1. 파일 로드 (OriginalSongs 폴더 자동 접근)
[file_in, fs] = audioread("OriginalSongs/ZZZ Camillia Golden Week OST_ CityDay [Zenless Zone Zero].mp3");
x = mean(file_in, 2);

%% 2. 분석 구간 지정 (60~70초)
start_t = 60;
end_t   = 70;

start_sample = floor(start_t * fs);
end_sample   = floor(end_t   * fs);

x_cut = x(start_sample:end_sample);

%% 3. STFT로 구간 분석
win = hann(2048);
hop = 1024;
nfft = 4096;

[S, f, t] = stft(x_cut, fs, 'Window', win, 'OverlapLength', hop, 'FFTLength', nfft);
magS = abs(S);

%% 4. 전체 구간에서 Kick이 가장 강한 Frame 찾기
energy = sum(magS, 1);              % frame energy
[~, idx] = max(energy);             % Kick 가장 강한 frame
kick_frame = magS(:, idx);

%% 5. Kick frame의 Spectrum에서 peak 탐색
% 저음역(20~200Hz)에서 Peak 찾기
low_band = (f >= 20 & f <= 200);
[freq_peak, loc] = max(kick_frame(low_band));
freq_list = f(low_band);
dominant_freq = freq_list(loc);

fprintf("Kick Dominant Frequency ≈ %.2f Hz\n", dominant_freq);

%% 6. 스펙트럼 그래프 출력
figure;
plot(f, kick_frame);
xlim([0 5000]);
title("Kick Frequency Spectrum (01:00~01:10)");
xlabel("Frequency (Hz)");
ylabel("Magnitude");
grid on;
