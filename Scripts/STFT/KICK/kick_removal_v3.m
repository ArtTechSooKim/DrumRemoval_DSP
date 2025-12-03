%% ============================================================
%% Kick Drum Perceptual Suppression v3
%% - 목표: Kick "존재감"을 줄이는 것 (완전 제거 X)
%% - 기법:
%%   1) Kick 전용 transient detector 사용
%%   2) Sub / Fundamental / Harmonic / Wide Attack 대역 attenuate
%%   3) Frame smoothing 으로 transient 완화
%% ============================================================

%% STEP 0 — 오디오 로드
% [수업 연결] Week 5~6 : time-domain 신호 로드 후 처리
[x, fs] = audioread("OriginalSongs/ZZZ Camillia Golden Week OST_ CityDay [Zenless Zone Zero].mp3");
x = mean(x, 2);   % stereo → mono

%% STEP 1 — STFT
% [수업 연결]
%  - Week 5: FFT/DFT
%  - Week 9 LAB: myspectrogram (window, overlap, nfft)
win_length = 1024;
win   = hann(win_length);
hop   = 512;
ovlp  = win_length - hop;
nfft  = 2048;

[S, f, t] = stft(x, fs, ...
    'Window', win, ...
    'OverlapLength', ovlp, ...
    'FFTLength', nfft);

magS = abs(S);

%% STEP 2 — Kick 관련 주파수 대역 정의 (CityDay 분석 기반)
% [수업 연결] Week 9 FIR: 특정 band를 선택해 처리
sub_band    = (f >= 40   & f <= 60);      % Sub tail
fund_band   = (f >= 80   & f <= 120);     % Fundamental (≈97Hz)
harm_band   = (f >= 170  & f <= 220);     % 2nd harmonic (≈193.8Hz)
attack_band = (f >= 2000 & f <= 6000);    % 기본 attack band
attack_wide = (f >= 1500 & f <= 9000);    % layered transient 확장 대역

%% STEP 3 — Kick Transient Detection (전용 detector 사용)
% [수업 연결]
%  - Week 7: Envelope / ITD 실험에서 amplitude peak 검출
kick_mask = kick_transient_detector(magS, f, 0.28);  % 1 x T logical

%% STEP 4 — 감쇠 강도 설정 (Perceptual Suppression 목표)
% [수업 연결]
%  - Week 9/10: gain 조절을 통한 filtering / reverb shaping

% 저역 계층
atten_sub   = 0.7;   % Sub 70% 감소
atten_fund  = 0.8;   % Fundamental 80% 감소
atten_harm  = 0.85;  % Harmonic 85% 감소

% 고역 attack 계층
atten_attack      = 0.6;  % 2~6kHz 기본 attack
atten_attack_wide = 0.5;  % 1.5~9kHz wide transient

S_filtered = S;

%% STEP 5 — Kick frame에서만 selective attenuation + smoothing
for i = 1:length(t)
    if kick_mask(i)
        % 1) 주파수 대역별 감쇠
        S_filtered(sub_band,    i) = S_filtered(sub_band,    i) * (1 - atten_sub);
        S_filtered(fund_band,   i) = S_filtered(fund_band,   i) * (1 - atten_fund);
        S_filtered(harm_band,   i) = S_filtered(harm_band,   i) * (1 - atten_harm);
        S_filtered(attack_band, i) = S_filtered(attack_band, i) * (1 - atten_attack);
        S_filtered(attack_wide, i) = S_filtered(attack_wide, i) * (1 - atten_attack_wide);

        % 2) Frame smoothing (Transient Shaper와 유사한 개념)
        % [수업 연결] Week 6/10: impulse response / reverb에서
        %               신호가 시간축으로 퍼지면서 공격이 부드러워지는 현상
        if i > 1 && i < length(t)
            S_filtered(:, i) = ...
                0.5  * S_filtered(:, i)   + ...
                0.25 * S_filtered(:, i-1) + ...
                0.25 * S_filtered(:, i+1);
        end
    end
end

%% STEP 6 — iSTFT로 복원
% [수업 연결]
%  - Week 5: FFT ↔ iFFT
%  - Week 6: convolution 후 time-domain 재구성
x_filtered = istft(S_filtered, fs, ...
    'Window', win, ...
    'OverlapLength', ovlp, ...
    'FFTLength', nfft);

% 정규화 + 실수화
x_filtered = x_filtered / max(abs(x_filtered) + eps);
x_filtered = real(x_filtered);

%% STEP 7 — 결과 저장 (FilteredSong 폴더에)
output_path = "FilteredSong/CityDay_kick_removed_v3.wav";
audiowrite(output_path, x_filtered, fs);

fprintf("v3 완료: %s\n", output_path);
