%% ============================================================
%% Kick Drum Removal Prototype v2
%% - Fundamental + Sub-harmonic(Sub-bass) + Attack까지 약화
%% - v1 대비: 더 넓은 대역에서 Kick 존재감을 줄이는 버전
%% ============================================================

%% STEP 0 — 오디오 로드
% [수업 연결] Week 6 LAB (reverb_sim, my_simple_reverb에서 audioread 사용)
% [원리] 모든 DSP 처리의 시작은 time-domain 신호 확보
[x, fs] = audioread("ZZZ Camillia Golden Week OST_ CityDay [Zenless Zone Zero].mp3");

% 스테레오 → 모노 (Kick 에너지 분석을 간단하게 하기 위해 채널 합산)
% [수업 연결] Week 5 DFT 예제에서도 mono 신호로 분석
x = mean(x, 2);


%% STEP 1 — STFT로 시간-주파수 변환
% [수업 연결] 
%  - Week 5: DFT/FFT, 주파수 도메인 분석
%  - Week 9 LAB: myspectrogram, window + overlap 기반 분석
% [원리] Kick은 "어느 시간에 / 어느 주파수 대역에" 에너지가 몰리는지가 중요하므로,
%        STFT로 time-frequency representation을 만든다.

win_length = 1024;
win = hann(win_length);                 % [Week 9] hann window (leakage 줄이기)
overlap = win_length - 512;             % hop = 512 → overlap = win_length - hop
nfft = 2048;

[S, f, t] = stft(x, fs, ...
    'Window', win, ...
    'OverlapLength', overlap, ...
    'FFTLength', nfft);

magS = abs(S);  % magnitude spectrum
% phase는 iSTFT에서 자동으로 유지되므로 별도 분리 필요 없음 (복소수 그대로 보관)


%% STEP 2 — Kick 관련 주파수 대역 정의
% [수업 연결]
%  - Week 9: FIR filter 설계 시 cut-off 대역 설정
%  - 강의: 드럼의 주파수 대역 설명 (Fundamental / Attack / Sub-bass)
% [원리]
%  - Sub-bass(서브 하모닉, 808 꼬리 등): 대략 30–60Hz
%  - Fundamental + Boom: 60–120Hz
%  - Attack(click): 2kHz 이상, 특히 2–6kHz 구간에 transient가 강함

sub_band   = (f >= 30   & f <= 60);      % Sub-bass, 808 꼬리 느낌
fund_band  = (f >= 60   & f <= 120);     % Kick의 메인 바디
attack_band= (f >= 2000 & f <= 6000);    % Kick의 '딱' 하는 어택


%% STEP 3 — Kick 에너지로 "어느 타이밍에 치는지" 감지
% [수업 연결]
%  - Week 7 LAB: ITD, HRIR 등에서 특정 band energy / envelope 추적
%  - Week 5: magnitude spectrum 사용
% [원리] 
%  Kick은 특정 저역 대역(30–120Hz)에 짧고 강한 에너지를 남긴다.
%  → Sub + Fundamental 대역 에너지를 합산해서 frame별 Kick 존재감 추정

kick_energy_band = sub_band | fund_band;        % 30–120Hz 전체를 Kick 저역으로 본다
kick_energy = sum(magS(kick_energy_band, :), 1);% frame마다 저역 에너지 합
kick_norm  = kick_energy / max(kick_energy);    % 0~1로 정규화


%% STEP 4 — Kick가 강하게 나타나는 frame 골라내기
% [수업 연결]
%  - Week 6 LAB: Reverb tail 제어에서 threshold 기반 감쇠
% [원리]
%  - Kick는 transient가 강하므로, 일정 threshold 이상이면 "여기서 Kick 쳤다"고 간주
%  - threshold가 낮으면 다른 악기까지 잡고, 너무 높으면 일부 Kick를 놓친다.

threshold = 0.3;                      % 실험적으로 조정 가능 (0.2~0.4 추천)
kick_mask = kick_norm > threshold;     % true인 frame = Kick가 강한 위치


%% STEP 5 — 각 대역별 감쇠 강도 설정
% [수업 연결]
%  - Week 9: FIR filter로 특정 frequency band attenuate
%  - Week 10: Comb / All-pass / Schroeder Reverb에서 gain < 1로 에너지 조절
% [원리]
%  - Sub-bass: 곡의 저역 무너질 수 있으니 적당히 감쇠 (ex. 50% 정도)
%  - Fundamental: Kick 본체를 확실히 약화 (ex. 70~80% 정도 감쇠)
%  - Attack: 너무 많이 깎으면 스네어/하이햇/보컬에 영향 → 적당히만 (ex. 40~50%)

atten_sub       = 0.5;   % Sub-bass: 50% 줄이기
atten_fund      = 0.7;   % Fundamental: 70% 줄이기
atten_attack    = 0.4;   % Attack: 40% 줄이기 (귀로 들리는 Kick 느낌 줄이기)

S_filtered = S;  % 원본 복사 후 수정


%% STEP 6 — Kick가 있는 frame에서만 주파수 도메인 감쇠
% [수업 연결]
%  - Week 6: Convolution Reverb에서 IR을 곱하거나 conv로 필터링
%  - 여기서는 Convolution 대신 "스펙트럼을 직접 스케일링"하는 방식 사용
% [원리]
%  - 특정 시간(frame) & 특정 주파수 대역(bin)에 대해만 gain을 줄이는
%    '시간-주파수 selective filtering' (spectral subtraction 비슷한 개념)

for i = 1:length(t)
    if kick_mask(i)
        % Sub-bass 대역 감쇠
        S_filtered(sub_band, i) = S_filtered(sub_band, i) * (1 - atten_sub);
        
        % Fundamental 대역 감쇠
        S_filtered(fund_band, i) = S_filtered(fund_band, i) * (1 - atten_fund);
        
        % Attack 대역 감쇠
        S_filtered(attack_band, i) = S_filtered(attack_band, i) * (1 - atten_attack);
    end
end


%% STEP 7 — iSTFT로 시간 영역 복원
% [수업 연결]
%  - Week 5: DFT ↔ IDFT 상호 변환
%  - Week 6: convolution reverb 후 time-domain 신호 복원(ifft)
% [원리]
%  - STFT에서 magnitude를 줄인 후, 원래의 위상을 유지한 채 inverse STFT 수행
%  - 약간의 floating point error로 매우 작은 imaginary part가 생길 수 있으므로 real() 사용

x_filtered = istft(S_filtered, fs, ...
    'Window', win, ...
    'OverlapLength', overlap, ...
    'FFTLength', nfft);

% Normalize
x_filtered = x_filtered / max(abs(x_filtered) + eps);

% audiowrite는 real-valued만 허용하므로 실수만 남긴다
x_filtered = real(x_filtered);


%% STEP 8 — 결과 저장
% [수업 연결]
%  - Week 6 LAB: reverb_sim1.wav 등 결과 파일 저장
% [원리]
%  - Before/After 비교 및, 나중에 "내가 친 드럼을 얹었을 때 차이"를 체험하기 위해 출력

audiowrite("CityDay_kick_removed_v2.wav", x_filtered, fs);
