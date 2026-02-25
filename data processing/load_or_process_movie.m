function [motion_energy_group, motion_energy_smooth_group, ...
          avg_active_motion_onsets_group, avg_active_motion_offsets_group, ...
          active_motion_onsets_group, active_motion_offsets_group, ...
          speed_active_group] = ...
    load_or_process_movie(current_gcamp_TSeries_path, gcamp_output_folders, avg_block, sampling_rate)
%LOAD_OR_PROCESS_MOVIE
% - Compute/load motion energy
% - Average, smooth, threshold, binarise
% - Detect active periods (avg + frame level)
% - Build speed_active directly from bin_sig (NO active_frames)
% - Save everything in results_movie.mat
% - Plot active periods

    numFolders = numel(current_gcamp_TSeries_path);

    motion_energy_group        = cell(numFolders,1);
    motion_energy_smooth_group = cell(numFolders,1);

    avg_active_motion_onsets_group  = cell(numFolders,1);
    avg_active_motion_offsets_group = cell(numFolders,1);

    active_motion_onsets_group  = cell(numFolders,1);
    active_motion_offsets_group = cell(numFolders,1);

    speed_active_group = cell(numFolders,1);   % 0/1 par frame caméra

    fijiPath = 'C:\Users\goldstein\Fiji.app\fiji-windows-x64.exe';

    for m = 1:numFolders

        %% ---------- Locate movie ----------
        camPath    = fullfile(current_gcamp_TSeries_path{m}, 'cam', 'Concatenated');
        cameraPath = fullfile(current_gcamp_TSeries_path{m}, 'camera', 'Concatenated');

        if isfolder(camPath)
            movieDir = camPath;
        elseif isfolder(cameraPath)
            movieDir = cameraPath;
        else
            warning('No camera folder for m=%d', m);
            continue;
        end

        filepath = fullfile(movieDir, 'cam_crop.tif');
        if exist(filepath,'file') ~= 2
            warning('cam_crop.tif missing for m=%d', m);
            continue;
        end

        %% ---------- Sampling rate ----------
        if iscell(sampling_rate)
            fs = sampling_rate{m};
        else
            fs = sampling_rate(m);
        end

        %% ---------- Output ----------
        if ~exist(gcamp_output_folders{m}, 'dir')
            mkdir(gcamp_output_folders{m});
        end
        savePath = fullfile(gcamp_output_folders{m}, 'results_movie.mat');

        %% ---------- Load if exists ----------
        motion_energy = [];
        avg_motion_energy = [];
        avg_onsets = [];
        avg_offsets = [];
        onsets_frames = [];
        offsets_frames = [];
        speed_active = [];

        if exist(savePath,'file') == 2
            data = load(savePath);
            if isfield(data,'motion_energy'), motion_energy = data.motion_energy; end
            if isfield(data,'avg_motion_energy'), avg_motion_energy = data.avg_motion_energy; end
            if isfield(data,'avg_active_motion_onsets'),  avg_onsets  = data.avg_active_motion_onsets; end
            if isfield(data,'avg_active_motion_offsets'), avg_offsets = data.avg_active_motion_offsets; end
            if isfield(data,'active_motion_onsets'),  onsets_frames  = data.active_motion_onsets; end
            if isfield(data,'active_motion_offsets'), offsets_frames = data.active_motion_offsets; end
            if isfield(data,'speed_active'), speed_active = data.speed_active; end
        end

        %% ---------- Compute motion energy ----------
        if isempty(motion_energy)
            motion_energy = compute_motion_energy(filepath);
        end
        motion_energy_group{m} = motion_energy;

        %% ---------- Average + smooth ----------
        if isempty(avg_motion_energy)
            avg_motion_energy = average_frames(motion_energy, avg_block);
        end

        motion_energy_smooth = smooth_savgol(avg_motion_energy, 3, 11);
        motion_energy_smooth_group{m} = motion_energy_smooth;

        %% ---------- Time axis ----------
        dt = avg_block / fs;
        time_axis = (0:numel(motion_energy_smooth)-1) * dt;

        %% ---------- Threshold + binarise ----------
        try
            [~, thr_li, ~] = compute_thresholds_for_bin_state_detection(motion_energy_smooth, false);
        catch
            [~, thr_li, ~] = compute_thresholds_for_bin_state_detection(motion_energy_smooth, false);
        end

        [bin_sig, ~, ~, ~] = binarise_motion( ...
            motion_energy_smooth, ...
            thr_li, ...
            fs, ...
            avg_block, ...
            3.0, ...   % min duration (s)
            5);        % min inactive gap (samples moyennés)

        %% ---------- Onsets / offsets (avg signal) ----------
        if isempty(avg_onsets) || isempty(avg_offsets)
            avg_onsets  = get_onsets(bin_sig);
            avg_offsets = get_offsets(bin_sig);

            if ~isempty(bin_sig)
                if bin_sig(1) == 1
                    avg_onsets = [1; avg_onsets(:)];
                end
                if bin_sig(end) == 1
                    avg_offsets = [avg_offsets(:); numel(bin_sig)];
                end
            end
        end

        avg_active_motion_onsets_group{m}  = avg_onsets;
        avg_active_motion_offsets_group{m} = avg_offsets;

        %% ---------- Convert onsets/offsets to frames ----------
        if isempty(onsets_frames) || isempty(offsets_frames)
            N_frames = numel(motion_energy);
            onsets_frames  = (avg_onsets  - 1) * avg_block + 1;
            offsets_frames =  avg_offsets * avg_block;
            onsets_frames  = max(1, onsets_frames);
            offsets_frames = min(N_frames, offsets_frames);
        end

        active_motion_onsets_group{m}  = onsets_frames;
        active_motion_offsets_group{m} = offsets_frames;

        %% ---------- Build speed_active DIRECTLY from bin_sig ----------
        if isempty(speed_active)
            N_frames = numel(motion_energy);
            speed_active = repelem(bin_sig(:), avg_block);

            if numel(speed_active) < N_frames
                speed_active(end+1:N_frames) = speed_active(end);
            else
                speed_active = speed_active(1:N_frames);
            end
        end

        speed_active_group{m} = speed_active;

        %% ---------- Save ----------
        avg_active_motion_onsets  = avg_onsets; %#ok<NASGU>
        avg_active_motion_offsets = avg_offsets; %#ok<NASGU>
        active_motion_onsets      = onsets_frames; %#ok<NASGU>
        active_motion_offsets     = offsets_frames; %#ok<NASGU>

        save(savePath, ...
            'motion_energy', ...
            'avg_motion_energy', ...
            'motion_energy_smooth', ...
            'avg_active_motion_onsets', ...
            'avg_active_motion_offsets', ...
            'active_motion_onsets', ...
            'active_motion_offsets', ...
            'speed_active', ...
            'avg_block', ...
            'fs', ...
            '-v7.3');

        %% ---------- Plot ----------
        figure('Color','w'); hold on;

        yl = [min(motion_energy_smooth) max(motion_energy_smooth)];
        if yl(1) == yl(2), yl = yl + [-1 1]*eps; end

        for k = 1:min(numel(avg_onsets), numel(avg_offsets))
            patch([time_axis(avg_onsets(k)) time_axis(avg_offsets(k)) ...
                   time_axis(avg_offsets(k)) time_axis(avg_onsets(k))], ...
                  [yl(1) yl(1) yl(2) yl(2)], ...
                  [1 0.8 0.8], 'EdgeColor','none', 'FaceAlpha',0.4);
        end

        plot(time_axis, bin_sig(:)' * yl(2), 'Color',[1 0.5 0], 'LineWidth',2);
        plot(time_axis, motion_energy_smooth, 'Color',[0 0 1], 'LineWidth',2);
        yline(thr_li, '--r', 'LineWidth',1);

        title(sprintf('binary motion\\_energy (m=%d)', m), 'FontSize', 18);
        xlabel('Time (s)');
        ylabel('Motion energy');
        grid on;
        hold off;
    end
end
function y = smooth_savgol(x, order, framelen_target)
%SMOOTH_SAVGOL Robust Savitzky-Golay smoothing.
% Ensures framelen is odd and > order; falls back to no-op if too short.

    x = x(:);
    N = numel(x);

    framelen = min(framelen_target, N);

    % Must be odd
    if mod(framelen, 2) == 0
        framelen = framelen - 1;
    end

    % Must be > order
    if framelen <= order
        framelen = order + 2;
        if mod(framelen, 2) == 0
            framelen = framelen + 1;
        end
    end

    % If still impossible, return raw
    if N < framelen || framelen < 3
        y = x;
        return;
    end

    y = sgolayfilt(x, order, framelen);
end

function onsets = get_onsets(bin_motion)
%GET_ONSETS Indices where signal goes from 0 to 1

    bin_motion = bin_motion(:);   % colonne
    onsets = find(bin_motion(2:end) == 1 & bin_motion(1:end-1) == 0) + 1;
end

function offsets = get_offsets(bin_motion)
%GET_OFFSETS Indices where signal goes from 1 to 0

    bin_motion = bin_motion(:);   % colonne
    offsets = find(bin_motion(2:end) == 0 & bin_motion(1:end-1) == 1) + 1;
end