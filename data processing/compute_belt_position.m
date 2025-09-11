% ===============================
% Parameters
% ===============================
% Need chan1, chan2 and lap_signal from csv
chan1 = TSeries080520251523028Cycle00001VoltageRecording001.Input5;
chan2 = TSeries080520251523028Cycle00001VoltageRecording001.Input6;
lap_signal =TSeries080520251523028Cycle00001VoltageRecording001.Input7;

Fs = 1000;                    % Sampling rate in Hz of treadmill
belt_length_cm = 190;         % Length of the treadmill belt (cm)
threshold = 2.5;              % Voltage threshold for chan1/chan2
lap_threshold = 0.5;          % Voltage threshold to detect lap drop (~0.3V drop)
Fs_img = fs_sig;              % fs_sig is the sampling rate of your imaging
% ===============================
% Step 1: Convert to binary
% ===============================
chan1_bin = chan1 > threshold;
chan2_bin = chan2 > threshold;

% ===============================
% Step 2: Compute quadrature state
% ===============================
states = bitshift(uint8(chan1_bin), 1) + uint8(chan2_bin);  % 2-bit state (0–3)

% Create direction lookup table
dir_lookup = zeros(4, 4);  % Rows: prev, Cols: current
% Forward transitions (clockwise)
dir_lookup(1+0,1+1) =  1;  % 00 -> 01
dir_lookup(1+1,1+3) =  1;  % 01 -> 11
dir_lookup(1+3,1+2) =  1;  % 11 -> 10
dir_lookup(1+2,1+0) =  1;  % 10 -> 00
% Reverse transitions (counterclockwise)
dir_lookup(1+1,1+0) = -1;  % 01 -> 00
dir_lookup(1+3,1+1) = -1;  % 11 -> 01
dir_lookup(1+2,1+3) = -1;  % 10 -> 11
dir_lookup(1+0,1+2) = -1;  % 00 -> 10

% ===============================
% Step 3: Decode direction
% ===============================
prev_state = states(1:end-1);
curr_state = states(2:end);
direction = zeros(length(chan1), 1);
direction(2:end) = arrayfun(@(p, c) dir_lookup(1+p, 1+c), prev_state, curr_state);

% ===============================
% Step 4: Cumulative steps
% ===============================
cumulative_steps = cumsum(direction);

% ===============================
% Step 5: Detect laps using FIRST LAP as anchor
% ===============================

% Initial lap signal thresholding (for reference lap)
lap_binary = lap_signal > lap_threshold;
lap_edges_raw = find(diff(lap_binary) == -1);

if length(lap_edges_raw) < 2
    error('Not enough lap pulses detected to compute steps per revolution.');
end

% Estimate steps per revolution as before (based on raw edges)
steps_at_laps_raw = cumulative_steps(lap_edges_raw);
steps_per_rev = median(diff(steps_at_laps_raw));
cm_per_step = belt_length_cm / steps_per_rev;

% Compute position and wrap
position_cm = cumulative_steps * cm_per_step;
position_wrapped_cm = mod(position_cm, belt_length_cm);

% -------------------------------------
% NEW: Use first lap’s wrapped position as anchor
% -------------------------------------
ref_lap_idx = lap_edges_raw(1);
ref_position = position_wrapped_cm(ref_lap_idx);  % Reference lap position (wrapped)

% Find all other times when mouse passes near the same wrapped position
tolerance_cm = 2;  % Allowable deviation
lap_candidate_idx = find(abs(position_wrapped_cm - ref_position) < tolerance_cm);

if isempty(lap_candidate_idx)
    error('No lap candidates found near the reference position.');
end

% Debounce: ensure laps are at least 0.5 sec apart
min_lap_spacing = round(Fs * 0.5);  % Samples
keep_idx = [true; diff(lap_candidate_idx) > min_lap_spacing];
keep_idx = keep_idx(1:length(lap_candidate_idx));  % Ensure size match

lap_edges = lap_candidate_idx(keep_idx);


% Debounce: ensure laps are at least 0.5 sec apart
min_lap_spacing = round(Fs * 0.5);  % Samples
lap_edges = lap_candidate_idx([true; diff(lap_candidate_idx) > min_lap_spacing]);

% Recalculate steps_at_laps using consistent lap positions
steps_at_laps = cumulative_steps(lap_edges);

% ===============================
% Step 6: Convert steps to position (cm) [Already done above]
% ===============================
% position_cm = cumulative_steps * cm_per_step;

% ===============================
% Step 7: Compute speed (cm/s)
% ===============================
dt = 1 / Fs;
speed_cm_per_s = [0; diff(position_cm)] / dt;

% Smooth speed
window_ms = 50;
window_size = round(window_ms * Fs / 1000);
speed_smoothed = movmean(speed_cm_per_s, window_size);

% ===============================
% Step 8: Plot original + wrapped position with corrected lap markers
% ===============================
time = (0:length(chan1)-1) / Fs;

figure;
subplot(2,1,1);
plot(time, position_cm, 'b'); hold on;
plot(time(lap_edges), position_cm(lap_edges), 'ro', 'MarkerSize', 6);
xlabel('Time (s)');
ylabel('Position (cm)');
title('Absolute Position with Corrected Lap Markers');
grid on;

subplot(2,1,2);
position_wrapped_cm = mod(position_cm, belt_length_cm);
plot(time, position_wrapped_cm, 'b'); hold on;
plot(time(lap_edges), position_wrapped_cm(lap_edges), 'ro');
xlabel('Time (s)');
ylabel('Wrapped Position (cm)');
title('Wrapped Position with Corrected Lap Markers');
ylim([0 belt_length_cm]);
grid on;

% ===============================
% Imaging Timebase Resampling + Correction
% ===============================
% UP/Downsample from treadmill Fs to imaging Fs
% Construct timebases
time_original = (0:length(position_cm)-1) / Fs;
time_img = (0:length(x_s_d)-1) / Fs_img;

% Interpolate (works for upsampling or downsampling)
position_resampled = interp1(time_original, position_cm, time_img, 'linear', 'extrap');
speed_resampled = interp1(time_original, speed_smoothed, time_img, 'linear', 'extrap');


% Wrap position to [0, belt_length_cm)
position_wrapped = mod(position_resampled, belt_length_cm);
position_wrapped(position_wrapped < 0) = position_wrapped(position_wrapped < 0) + belt_length_cm;

% ---------------------------------------------
% Apply +16 cm laser offset and wrap again
% ---------------------------------------------
offset_cm = 16;
position_corrected = mod(position_wrapped + offset_cm, belt_length_cm);

% ---------------------------------------------
% Align so that first lap = 0 cm
% ---------------------------------------------
first_lap_time = time(lap_edges(1));  % time of first corrected lap
[~, first_lap_img_index] = min(abs(time_img - first_lap_time));
first_lap_pos_corrected = position_corrected(first_lap_img_index);

% Final aligned corrected position
position_aligned = mod(position_corrected - first_lap_pos_corrected, belt_length_cm);

% ===============================
% Final Plot
% ===============================
figure;

subplot(3,1,1);
plot(time_img, x_s_d, 'b');
title('x\_s\_d (Imaging Trigger)');
xlabel('Time (s)');
ylabel('x\_s\_d');
grid on;

subplot(3,1,2);
plot(time_img, position_aligned, 'g');
title('Aligned Resampled Position (16 cm shift + First Lap = 0 cm)');
xlabel('Time (s)');
ylabel('Aligned Position (cm)');
ylim([0 belt_length_cm]);
grid on;

subplot(3,1,3);
plot(time_img, speed_resampled, 'r');
title('Resampled Speed');
xlabel('Time (s)');
ylabel('Speed (cm/s)');
grid on;

%---------
lap_times = time(lap_edges);
lap_intervals = diff(lap_times);
avg_lap_speed = belt_length_cm ./ lap_intervals;

figure;
plot(lap_times(2:end), avg_lap_speed, '-o');
xlabel('Time (s)');
ylabel('Avg Speed per Lap (cm/s)');
title('Average Speed Per Lap');
grid on;

lap_diffs = diff(steps_at_laps);
disp(['Mean: ', num2str(mean(lap_diffs)), ', Std: ', num2str(std(lap_diffs)), ...
      ', CoV: ', num2str(std(lap_diffs)/mean(lap_diffs))]);

