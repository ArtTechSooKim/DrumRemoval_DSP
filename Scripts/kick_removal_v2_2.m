%% ============================================================
%% Kick Drum Removal Prototype v2_2
%% - v2_1에 비해 Transient Suppression 강화
%% - Attack 확장 대역(1.5~9kHz) 추가 감쇠
%% - Frame smoothing 추가 (Transient Shaper 역할)
%% ============================================================


%% STEP 0 — 오디오 로드
% [수업 연결] Week 5 ~ 7 : audio read 후 time-domain → frequency-domain 변환
[x, fs] = audioread("OriginalSongs\ZZZ Camillia Golden Week OST_ CityDay [Zenless Zone Zero].mp3");
x = mean(x, 2);  % stereo → mono


%% STEP 1 — STFT로 시간-주파수 분석
% [수업 연결]
%  - Week 5: FFT/DFT
%  - Week 9 LAB: myspectrogram, windowing, hop size
win_length = 1024;
win = hann(win_length);
hop = 512;
overlap = win_length - hop;
nfft = 2048;

[S, f, t] = stft(x, fs, ...
    'Window', win, ...
    'OverlapLength', overlap, ...
    'FFTLength', nfft);

magS = abs(S);


%% STEP 2 — Kick Drum 주파수 대역 정의
% [수업 연결] Week 9 FIR: 특정 주파수 대역 선택적 처리
sub_band    = (f >= 40   & f <= 60);      % Sub harmonic
fund_band   = (f >= 80   & f <= 120);     % Fundamental
harm_band   = (f >= 170  & f <= 220);     % Harmonic
attack_band = (f >= 2000 & f <= 6000);    % Attack region

% [v2_2 변경] Attack 확장 대역
attack_wide_band = (f >= 1500 & f <= 9000);



%% STEP 3 — Kick Detection (기본 버전)
% [수업 연결] Week 7 LAB: envelope tracking → transient detection
kick_energy_band = sub_band | fund_band | harm_band;
kick_energy = sum(magS(kick_energy_band, :), 1);

kick_norm = kick_energy / max(kick_energy);
threshold = 0.28;

kick_mask = kick_norm > threshold;



%% STEP 4 — 감쇠 강도 설정
% [수업 연결]
%  - Week 9: frequency selective filtering
%  - Week 10: gain 조절을 통한 signal shaping

% 기존 v2_1보다 강하게 조정
atten_sub       = 0.8;   % [v2_2 변경] 80% attenuation
atten_fund      = 0.9;   % [v2_2 변경] 90% attenuation
atten_harm      = 0.95;  % [v2_2 변경] 95% attenuation
atten_attack    = 0.7;   % 기존 attack 감쇠

% [v2_2 변경] 넓은 고역 공격 감쇠
atten_attack_wide = 0.6; % 1.5~9kHz → transient smoothing 효과



%% STEP 5 — Kick Frame Selective Attenuation
% [수업 연결]
%  - Week 6: spectral subtraction(특정 bin 감소)
%  - Week 9: FIR filtering 개념을 STFT domain에서 직접 구현
S_filtered = S;

for i = 1:length(t)
    if kick_mask(i)

        % 기존 감쇠
        S_filtered(sub_band, i)    = S_filtered(sub_band, i)    * (1 - atten_sub);
        S_filtered(fund_band, i)   = S_filtered(fund_band, i)   * (1 - atten_fund);
        S_filtered(harm_band, i)   = S_filtered(harm_band, i)   * (1 - atten_harm);
        S_filtered(attack_band, i) = S_filtered(attack_band, i) * (1 - atten_attack);

        % [v2_2 변경] 확장 Attack 감쇠
        S_filtered(attack_wide_band, i) = ...
            S_filtered(attack_wide_band, i) * (1 - atten_attack_wide);

        % [v2_2 변경] Kick transient smoothing
        % 수업의 time-domain smoothing 개념과 유사한 frame smoothing
        if i > 1 && i < length(t)
            S_filtered(:, i) = ...
                0.5 * S_filtered(:, i) + ...
                0.25 * S_filtered(:, i-1) + ...
                0.25 * S_filtered(:, i+1);
        end
    end
end



%% STEP 6 — iSTFT로 시간 영역 복원
% [수업 연결]
%  - Week 5: FFT ↔ iFFT
%  - Week 6: convolution 후 time-domain reconstruction
x_filtered = istft(S_filtered, fs, ...
    'Window', win, ...
    'OverlapLength', overlap, ...
    'FFTLength', nfft);

x_filtered = x_filtered / max(abs(x_filtered) + eps);
x_filtered = real(x_filtered);



%% STEP 7 — 파일 저장
% [수업 연결] Week 6 LAB: audiowrite로 결과 비교
audiowrite("FilteredSong\CityDay_kick_removed_v2_2.wav", x_filtered, fs);

disp("v2_2 처리 완료 — CityDay_kick_removed_v2_2.wav 생성됨");
