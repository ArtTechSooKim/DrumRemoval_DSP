%% ============================================================
%% Kick Drum Attack Suppression v4.2
%% - Attack-only removal (0~15ms)
%% - Harmonic Attack cancellation (1k~2kHz)
%% - Wide-band transient removal (3k~10kHz)
%% - Micro-transient removal (±2ms)
%% ============================================================

[x, fs] = audioread("OriginalSongs/ZZZ Camillia Golden Week OST_ CityDay [Zenless Zone Zero].mp3");
x = mean(x,2);

%% STEP 1 — Envelope + derivative
env = abs(x);
win_len = round(0.004 * fs);      % 4ms smoothing
env = movmean(env, win_len);

env_diff = [0; diff(env)];        % derivative


%% STEP 2 — Attack-only detection (Kick 특화)
th_env  = mean(env) + 3 * std(env);
th_diff = mean(env_diff) + 3 * std(env_diff);

kick_attack_mask = (env > th_env) & (env_diff > th_diff);


%% STEP 3 — Gain envelope 초기화
gain_env = ones(size(x));

core_attack_ms = 0.015;    % 15ms (Kick core click zone)
release_ms      = 0.08;    % 80ms release

core_len    = round(core_attack_ms * fs);
release_len = round(release_ms      * fs);

for n = 1:length(x)
    if kick_attack_mask(n)

        %% Core Attack removal (0~15ms)
        core_end = min(n + core_len, length(x));
        gain_env(n:core_end) = min(gain_env(n:core_end), 0.03);   % 3% 남기고 거의 제거

        %% Release ramp
        rel_end = min(core_end + release_len, length(x));
        
        idx = core_end:rel_end;
        L = length(idx);
        ramp = linspace(0.03, 1, L)';
        
        gain_env(idx) = min(gain_env(idx), ramp);

        %% Micro-transient removal (전후 2ms)
        micro = round(0.002 * fs);   % ±2ms
        micro_start = max(1, n - micro);
        micro_end   = min(length(x), n + micro);
        gain_env(micro_start:micro_end) = ...
            min(gain_env(micro_start:micro_end), 0.1);

    end
end


%% STEP 4 — Gain smoothing
smooth_len = round(0.015 * fs); % 15ms
gain_env = movmean(gain_env, smooth_len);


%% STEP 5 — Apply
x_shaped = x .* gain_env;


%% STEP 6 — STFT Attack Harmonic & Transient Cancellation
win = hann(512);
hop = 256;
nfft = 1024;

[S, f, t] = stft(x_shaped, fs, ...
    'Window', win, 'OverlapLength', 256, 'FFTLength', nfft);

%% 6-1) Harmonic Click removal (1~2 kHz notch)
harm_band = (f >= 1000 & f <= 2000);
S(harm_band, :) = S(harm_band, :) * 0.3;

%% 6-2) High-frequency Attack Removal (3~10 kHz)
attack_band = (f >= 3000 & f <= 10000);
S(attack_band, :) = S(attack_band, :) * 0.15;

%% 6-3) Microtransient spectral flattening
micro_band = (f >= 2000 & f <= 12000);
S(micro_band, :) = medfilt1(abs(S(micro_band, :)), 5) .* exp(1j*angle(S(micro_band, :)));

%% 6-4) Psychoacoustic smoothing (artifact 최소화)
for i = 2:size(S,2)-1
    S(:, i) = 0.6*S(:,i) + 0.2*S(:,i-1) + 0.2*S(:,i+1);
end

x_v43 = istft(S, fs, ...
    'Window', win, 'OverlapLength', 256, 'FFTLength', nfft);

x_v43 = real(x_v43);
x_v43 = x_v43 / max(abs(x_v43));

audiowrite("FilteredSong/CityDay_kick_removed_v4_2.wav", x_v43, fs);

disp("v4.3 완료 — Attack + Harmonic + Micro-transient 제거");
