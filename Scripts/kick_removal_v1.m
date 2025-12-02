%% ============================================================
%% Kick Drum Removal Prototype (1단계 곡 전용)
%% ============================================================

%% STEP 0 — Load Audio File
% [수업 기반] : Week 6 LAB에서 audio read 후 convolution 시뮬레이션을 했던 방식과 동일
% [원리] : 모든 신호 처리의 시작은 time-domain 신호 확보
[x, fs] = audioread("ZZZ Camillia Golden Week OST_ CityDay [Zenless Zone Zero].mp3");
x = mean(x, 2); % stereo → mono (kick energy 분석을 위해 합성)
%% STEP 1 — Short-Time FFT로 주파수 분석
% [수업 기반] : Week 5 DFT/FFT와 Week 6 Spectrogram 예제
% [원리] : Kick은 50–120Hz에 강력한 energy peak가 있음 → 탐지 가능

win = hann(1024);               % (Week 9 Windowing)
hop = 512;
nfft = 2048;

[S, f, t] = stft(x, fs, 'Window', win, 'OverlapLength', hop, 'FFTLength', nfft);
magS = abs(S);
%% STEP 2 — Kick Drum Frequency Band 정의
% [수업 기반] : Week 9 FIR 필터 설계, 주파수 대역 조절
% [원리] : Kick fundamental이 가장 뚜렷하게 존재하는 영역을 타겟팅

kick_band = (f >= 50 & f <= 120); % Kick band mask
%% STEP 3 — Kick 에너지 프로파일 추출
% [수업 기반] : Week 7 LAB의 ITD에서 amplitude tracking, envelope 분석과 유사
% [원리] : Kick은 매우 강한 transient → 특정 band 에너지의 envelope로 detection 가능

kick_energy = sum(magS(kick_band, :), 1);     % frame별 kick energy
kick_norm = kick_energy / max(kick_energy);   % normalize 0~1
%% STEP 4 — Kick 발생 순간에만 감쇠 필터 적용
% [수업 기반] : Week 6 Spectral Subtraction (reverb tail 제거) 원리 응용
% [원리] : Kick 발생 순간의 spectral component만 줄여야 음악 전체 손상이 적음

% 감쇠 강도 (0 → 원본 유지, 1 → 완전 제거)
atten_strength = 0.7;

% Kick이 강한 순간: 에너지 0.35 이상일 때를 kick frame으로 판단
kick_mask = kick_norm > 0.35;
%% STEP 5 — Kick 주파수 대역을 frame-by-frame로 attenuate
% [수업 기반] : Week 9 FIR → frequency shaping / Filtering 원리
% [원리] : 특정 주파수 bin만 감산하는 spectral subtraction

S_filtered = S;

for i = 1:length(t)
    if kick_mask(i)
        % Kick band만 energy 감소
        S_filtered(kick_band, i) = S_filtered(kick_band, i) * (1 - atten_strength);
    end
end
%% STEP 6 — iSTFT로 시간 영역으로 복원
% [수업 기반] : Week 5 DFT ↔ IDFT 변환, Week 6 Convolution 후 time-domain 변환
% [원리] : FFT 도메인에서 수정한 스펙트럼을 inverse transform

x_filtered = istft(S_filtered, fs, 'Window', win, 'OverlapLength', hop, 'FFTLength', nfft);

% Normalize
x_filtered = x_filtered / max(abs(x_filtered));

% (중요) audiowrite는 real-valued signal만 받으므로 imaginary 제거
% [수업 기반] : Week 5 DFT/IDFT에서 imaginary 성분이 남는 경우 real() 사용
% [원리] : FFT/iFFT는 floating point rounding error로 아주 작은 imaginary 값 발생할 수 있음
x_filtered = real(x_filtered);

%% STEP 7 — 결과 저장
% [수업 기반] : Week 6 LAB에서 audiowrite로 reverb 파일 저장했음
% [원리] : Before/After 비교를 위해 audio output 생성

audiowrite("CityDay_kick_removed.wav", x_filtered, fs);
