%% ============================================================
%% Kick Drum Perceptual Suppression v4 — Time-domain Transient Shaper
%% - MIDI 기반 드럼에 특히 효과적
%% - Attack(0~40ms)만 강하게 억제 → Kick 귀에서 사라짐
%% ============================================================

%% STEP 0 — 오디오 로드
[x, fs] = audioread("OriginalSongs/ZZZ Camillia Golden Week OST_ CityDay [Zenless Zone Zero].mp3");
x = mean(x, 2);   % stereo → mono

%% STEP 1 — Envelope 추출
env = abs(x);                         % full-wave rectified
win_len = round(0.005 * fs);          % 5ms smoothing window
env = movmean(env, win_len);          % smoothed envelope

%% STEP 2 — Transient Detection
th = mean(env) + 2.5 * std(env);      % Kick-like transient threshold
transient_mask = env > th;

%% STEP 3 — Gain Shaping Envelope 생성
attack_ms  = 0.04;  % 40ms
release_ms = 0.12;  % 120ms
attack_len  = round(attack_ms  * fs);
release_len = round(release_ms * fs);

gain_env = ones(size(x));   % 기본 = 1

for n = 1:length(x)
    if transient_mask(n)
        % Attack 구간: 0.1배로 줄임
        start_idx = n;
        end_idx_a = min(n + attack_len, length(x));
        gain_env(start_idx:end_idx_a) = min(gain_env(start_idx:end_idx_a), 0.1);
        
        %% Release 구간
        end_idx_r = min(end_idx_a + release_len, length(x));
        
        % [Fix] 범위가 비어있지 않은 경우에만 처리
        if end_idx_r > end_idx_a
            ramp_len = end_idx_r - end_idx_a;
            ramp = linspace(0.1, 1, ramp_len)';  % column vector로 생성
            
            % 실제 인덱스 범위 길이와 ramp 길이 맞추기
            actual_len = length(end_idx_a+1:end_idx_r);
            minLen = min(actual_len, length(ramp));
            
            gain_env(end_idx_a+1:end_idx_a+minLen) = ...
                min(gain_env(end_idx_a+1:end_idx_a+minLen), ramp(1:minLen));
        end
    end
end

%% STEP 4 — Gain envelope smoothing
smooth_len = round(0.02 * fs);   % 20ms smoothing
gain_env = movmean(gain_env, smooth_len);

%% STEP 5 — Gain 적용
x_shaped = x .* gain_env;

%% STEP 6 — 정규화 및 저장
x_shaped = x_shaped / max(abs(x_shaped) + eps);
audiowrite("FilteredSong/CityDay_kick_removed_v4_attackshaper.wav", x_shaped, fs);
disp("v4 Attack Shaper 완료!");