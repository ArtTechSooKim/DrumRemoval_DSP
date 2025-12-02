%% ============================================================
%% Kick Drum Removal Prototype v2_1 (CityDay Harmonic Version)
%% - Sub + Fundamental + Harmonic(193Hz) + Attack 모두 감쇠
%% ============================================================

%% STEP 0 — 오디오 로드
[x, fs] = audioread("OriginalSongs/ZZZ Camillia Golden Week OST_ CityDay [Zenless Zone Zero].mp3");
x = mean(x, 2);  % mono

%% STEP 1 — STFT 변환
win_length = 1024;
win = hann(win_length);
hop = 512;
nfft = 2048;

[S, f, t] = stft(x, fs, ...
    'Window', win, ...
    'OverlapLength', win_length-hop, ...
    'FFTLength', nfft);

magS = abs(S);

%% STEP 2 — Kick 관련 주파수 대역 (CityDay 분석 기반)
% Sub-bass
sub_band = (f >= 40 & f <= 60);

% Fundamental (실제 Kick fundamental ≈ 97Hz)
fund_band = (f >= 80 & f <= 120);

% Harmonic (가장 강력한 Kick 주파수: 193.8Hz)
harm_band = (f >= 170 & f <= 220);

% Attack(click)
attack_band = (f >= 2000 & f <= 6000);

%% STEP 3 — Kick detection mask
kick_energy_band = sub_band | fund_band | harm_band;
kick_energy = sum(magS(kick_energy_band, :), 1);
kick_norm = kick_energy / max(kick_energy);

threshold = 0.28;                    % tunable
kick_mask = kick_norm > threshold;  % frame detection

%% STEP 4 — 감쇠 강도 설정 (강화)
atten_sub    = 0;  % Sub (40Hz-60Hz)
atten_fund   = 0;  % Fundamental (80Hz-120Hz) 
atten_harm   = 0;  % Harmonic (170Hz-220Hz)
atten_attack = 0;  % Attack (2kHz-6kHz)

S_filtered = S;

%% STEP 5 — Kick frame에서만 selective attenuation
for i = 1:length(t)
    if kick_mask(i)
        S_filtered(sub_band,    i) = S_filtered(sub_band,    i) * (1 - atten_sub);
        S_filtered(fund_band,   i) = S_filtered(fund_band,   i) * (1 - atten_fund);
        S_filtered(harm_band,   i) = S_filtered(harm_band,   i) * (1 - atten_harm);
        S_filtered(attack_band, i) = S_filtered(attack_band, i) * (1 - atten_attack);
    end
end

%% STEP 6 — iSTFT 복원
x_filtered = istft(S_filtered, fs, ...
    'Window', win, 'OverlapLength', win_length-hop, 'FFTLength', nfft);

% Normalization + imaginary 제거
x_filtered = x_filtered / max(abs(x_filtered) + eps);
x_filtered = real(x_filtered);

%% STEP 7 — 자동 저장 (FilteredSong 폴더)
output_path = "FilteredSong/CityDay_kick_removed_v2_1.wav";
audiowrite(output_path, x_filtered, fs);

fprintf("Saved improved v2_1 file: %s\n", output_path);
