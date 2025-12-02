%% ============================================================
%% Kick Drum Attack Suppression v4.2 — Kick Attack Only Removal
%% ============================================================

[x, fs] = audioread("OriginalSongs/ZZZ Camillia Golden Week OST_ CityDay [Zenless Zone Zero].mp3");
x = mean(x,2);

%% Envelope + derivative
env = abs(x);
win_len = round(0.004 * fs);    
env = movmean(env, win_len);

env_diff = [0; diff(env)];

%% Attack-only detection
th_env  = mean(env) + 3 * std(env);
th_diff = mean(env_diff) + 3 * std(env_diff);

kick_attack_mask = (env > th_env) & (env_diff > th_diff);

%% Gain envelope 초기화
gain_env = ones(size(x));

core_attack_ms = 0.015;
release_ms      = 0.08;

core_len    = round(core_attack_ms * fs);
release_len = round(release_ms * fs);

for n = 1:length(x)
    if kick_attack_mask(n)

        % Attack core
        core_end = min(n + core_len, length(x));
        gain_env(n:core_end) = min(gain_env(n:core_end), 0.05);

        % Release zone
        rel_end = min(core_end + release_len, length(x));

        idx = core_end:rel_end;        % 인덱스 구간
        L = length(idx);                % 길이
        ramp = linspace(0.05, 1, L);    % release ramp
        ramp = ramp(:);                 % ★ column vector로 강제 변환

        gain_env(idx) = min(gain_env(idx), ramp);
    end
end

%% Smoothing
smooth_len = round(0.015 * fs);
gain_env = movmean(gain_env, smooth_len);

%% Apply
x_shaped = x .* gain_env;

%% High-frequency burst attenuation
win = hann(512);
hop = 256;
nfft = 1024;

[S, f, t] = stft(x_shaped, fs, ...
    'Window', win, 'OverlapLength', 256, 'FFTLength', nfft);

burst_band = (f >= 3000 & f <= 10000);
S(burst_band, :) = 0.2 * S(burst_band, :);

x_shaped2 = istft(S, fs, ...
    'Window', win, 'OverlapLength', 256, 'FFTLength', nfft);

x_shaped2 = real(x_shaped2);
x_shaped2 = x_shaped2 / max(abs(x_shaped2));

audiowrite("FilteredSong/CityDay_kick_removed_v4_1_attackonly.wav", x_shaped2, fs);

disp("v4.2 Attack-only 강력 억제 버전 완료!");
