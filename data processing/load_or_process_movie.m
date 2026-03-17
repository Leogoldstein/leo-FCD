function [motion_energy_group, motion_energy_smooth_group, ...
          avg_active_motion_onsets_group, avg_active_motion_offsets_group, ...
          active_motion_onsets_group, active_motion_offsets_group, ...
          speed_active_group] = ...
    load_or_process_movie(current_gcamp_TSeries_path, gcamp_output_folders, avg_block, sampling_rate_group, current_animal_group)
    

%LOAD_OR_PROCESS_MOVIE
    % - Load existing results_movie.mat fields if present
    % - Otherwise compute ONLY missing parts (field-by-field)
    % - Compute motion energy if missing (with Fiji prompt)
    % - Average, smooth, threshold, binarise
    % - Detect active periods (avg + frame level)
    % - Build speed_active directly from bin_sig
    % - Save everything in results_movie.mat
    % - Plot active periods

    numFolders = numel(current_gcamp_TSeries_path);

    motion_energy_group        = cell(numFolders,1);
    motion_energy_smooth_group = cell(numFolders,1);

    avg_active_motion_onsets_group  = cell(numFolders,1);
    avg_active_motion_offsets_group = cell(numFolders,1);

    active_motion_onsets_group  = cell(numFolders,1);
    active_motion_offsets_group = cell(numFolders,1);

    speed_active_group = cell(numFolders,1);

    camFolders = cell(numFolders,1);
    fijiPath = 'C:\Users\goldstein\Fiji.app\fiji-windows-x64.exe';

    for m = 1:numFolders

        % ------- Locate camera folder -------
        camPath    = fullfile(current_gcamp_TSeries_path{m}, 'cam',    'Concatenated');
        cameraPath = fullfile(current_gcamp_TSeries_path{m}, 'camera', 'Concatenated');

        if isfolder(camPath)
            camFolders{m} = camPath;
            fprintf('Found cam folder: %s\n', camPath);
        elseif isfolder(cameraPath)
            camFolders{m} = cameraPath;
            fprintf('Found camera folder: %s\n', cameraPath);
        else
            fprintf('No Camera images found in %s.\n', current_gcamp_TSeries_path{m});
            % Fill empties and continue
            motion_energy_group{m} = [];
            motion_energy_smooth_group{m} = [];
            avg_active_motion_onsets_group{m} = [];
            avg_active_motion_offsets_group{m} = [];
            active_motion_onsets_group{m} = [];
            active_motion_offsets_group{m} = [];
            speed_active_group{m} = [];
            continue;
        end

        filepath = fullfile(camFolders{m}, 'cam_crop.tif');
        if exist(filepath, 'file') ~= 2
            fprintf('No movie found at %s.\n', filepath);
            motion_energy_group{m} = [];
            motion_energy_smooth_group{m} = [];
            avg_active_motion_onsets_group{m} = [];
            avg_active_motion_offsets_group{m} = [];
            active_motion_onsets_group{m} = [];
            active_motion_offsets_group{m} = [];
            speed_active_group{m} = [];
            continue;
        end

        savePath = fullfile(gcamp_output_folders{m}, 'results_movie.mat');

        % ------- Load previous data if exists -------
        data = [];
        if exist(savePath,'file') == 2
            data = load(savePath);
        end

        % ============================================================
        % 1) motion_energy (load if exists, else compute/prompt)
        % ============================================================
        motion_energy = load_field_or_default(data, 'motion_energy', ...
            @() compute_or_prompt_motion_energy(filepath, fijiPath));

        motion_energy_group{m} = motion_energy;

        if isempty(motion_energy)
            % Nothing else to do
            motion_energy_smooth_group{m} = [];
            avg_active_motion_onsets_group{m} = [];
            avg_active_motion_offsets_group{m} = [];
            active_motion_onsets_group{m} = [];
            active_motion_offsets_group{m} = [];
            speed_active_group{m} = [];
            continue;
        end

        % ============================================================
        % 2) avg_motion_energy (load if exists, else compute)
        % ============================================================
        avg_motion_energy = load_field_or_default(data, 'avg_motion_energy', ...
            @() average_frames(motion_energy, avg_block));

        % ============================================================
        % 3) motion_energy_smooth (load if exists, else compute)
        % ============================================================
        motion_energy_smooth = load_field_or_default(data, 'motion_energy_smooth', ...
            @() smooth_savgol(avg_motion_energy, 3, 11));

        motion_energy_smooth_group{m} = motion_energy_smooth;

        % ============================================================
        % 4) Dependent outputs (onsets/offsets/speed_active)
        %    If ANY missing => recompute from motion_energy_smooth
        % ============================================================
        need_bin = isempty(data) || ...
                   ~isfield(data,'avg_active_motion_onsets') || ...
                   ~isfield(data,'avg_active_motion_offsets') || ...
                   ~isfield(data,'active_motion_onsets') || ...
                   ~isfield(data,'active_motion_offsets') || ...
                   ~isfield(data,'speed_active');

        thr_li = [];
        bin_sig = [];

        if need_bin
            [~, thr_li, ~] = compute_thresholds_for_bin_state_detection(motion_energy_smooth, false);

            [bin_sig, ~, ~, ~] = binarise_motion( ...
                motion_energy_smooth, ...
                thr_li, ...
                sampling_rate_group{m}, ...
                avg_block, ...
                3.0, ...
                5);

            % ---- avg onsets/offsets (in averaged samples) ----
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

            % ---- convert to frames ----
            N_frames = numel(motion_energy);
            onsets_frames  = (avg_onsets  - 1) * avg_block + 1;
            offsets_frames =  avg_offsets * avg_block;

            onsets_frames  = max(1, onsets_frames);
            offsets_frames = min(N_frames, offsets_frames);

            % ---- speed_active per camera frame (0/1) ----
            speed_active = repelem(bin_sig(:), avg_block);

            if numel(speed_active) < N_frames
                speed_active(end+1:N_frames) = speed_active(end);
            else
                speed_active = speed_active(1:N_frames);
            end

        else
            % Load everything
            avg_onsets     = data.avg_active_motion_onsets;
            avg_offsets    = data.avg_active_motion_offsets;
            onsets_frames  = data.active_motion_onsets;
            offsets_frames = data.active_motion_offsets;
            speed_active   = data.speed_active;

            % Optional: try to load thr_li / bin_sig if saved previously
            if isfield(data,'thr_li'), thr_li = data.thr_li; end
            if isfield(data,'bin_sig'), bin_sig = data.bin_sig; end
        end

        avg_active_motion_onsets_group{m}  = avg_onsets;
        avg_active_motion_offsets_group{m} = avg_offsets;
        active_motion_onsets_group{m}      = onsets_frames;
        active_motion_offsets_group{m}     = offsets_frames;
        speed_active_group{m}              = speed_active;

        % ============================================================
        % 5) Save (always overwrite to ensure consistency)
        % ============================================================
        avg_active_motion_onsets  = avg_onsets;
        avg_active_motion_offsets = avg_offsets;
        active_motion_onsets      = onsets_frames;
        active_motion_offsets     = offsets_frames;

        % If you want, you can also save bin_sig & thr_li to avoid recomputing:
        % (uncomment these two lines if you want them stored)
        % bin_sig_to_save = bin_sig;
        % thr_li_to_save  = thr_li;

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
            '-v7.3');

       % ---- Sauvegarde image PNG ----
        png_filename = fullfile(gcamp_output_folders{m}, ...
            sprintf('binary_motion_energy.png'));
        
        if ~isfile(png_filename)
        
            fig = figure('Visible','off', 'Color','w');
            hold on;
        
            % ============================================================
            % 6) Plot (only if we have thr/bin; otherwise skip threshold line)
            % ============================================================
            dt = avg_block / sampling_rate_group{m};
            time_axis = (0:numel(motion_energy_smooth)-1) * dt;
        
            yl = [min(motion_energy_smooth) max(motion_energy_smooth)];
            if yl(1) == yl(2)
                yl = yl + [-1 1]*eps;
            end
        
            for k = 1:min(numel(avg_onsets), numel(avg_offsets))
                patch([time_axis(avg_onsets(k)) time_axis(avg_offsets(k)) ...
                       time_axis(avg_offsets(k)) time_axis(avg_onsets(k))], ...
                      [yl(1) yl(1) yl(2) yl(2)], ...
                      [1 0.8 0.8], 'EdgeColor','none', 'FaceAlpha',0.4);
            end
        
            % Plot bin if available (otherwise compute a quick one for display)
            if isempty(bin_sig)
                % just for plotting (does not affect saved results)
                [~, thr_tmp, ~] = compute_thresholds_for_bin_state_detection(motion_energy_smooth, false);
                [bin_tmp, ~, ~, ~] = binarise_motion(motion_energy_smooth, thr_tmp, ...
                    sampling_rate_group{m}, avg_block, 3.0, 5);
        
                plot(time_axis, bin_tmp(:)' * yl(2), 'Color',[1 0.5 0], 'LineWidth',2);
                yline(thr_tmp, '--r', 'LineWidth',1);
            else
                plot(time_axis, bin_sig(:)' * yl(2), 'Color',[1 0.5 0], 'LineWidth',2);
                if ~isempty(thr_li)
                    yline(thr_li, '--r', 'LineWidth',1);
                end
            end
        
            plot(time_axis, motion_energy_smooth, 'Color',[0 0 1], 'LineWidth',2);
        
            title(sprintf('binary motion_energy – %s', ...
                current_animal_group));
            xlabel('Time (s)');
            ylabel('Motion energy');
            grid on;
            hold off;
        
            saveas(fig, png_filename);
            close(fig);
        end

    end % for m
end % main


% =====================================================================
% Helpers
% =====================================================================

function val = load_field_or_default(S, fieldname, default_fun)
%LOAD_FIELD_OR_DEFAULT Return S.(fieldname) if exists, else default_fun()
    if ~isempty(S) && isfield(S, fieldname)
        val = S.(fieldname);
    else
        val = default_fun();
    end
end

function motion_energy = compute_or_prompt_motion_energy(filepath, fijiPath)
%COMPUTE_OR_PROMPT_MOTION_ENERGY Ask user and compute motion energy.
    choice = input('Voulez-vous ouvrir le film dans Fiji pour cropper ? (1/2) ', 's');

    if strcmpi(choice, '1')
        fprintf('Ouverture de %s dans Fiji...\n', filepath);
        system(sprintf('"%s" "%s"', fijiPath, filepath));
        motion_energy = compute_motion_energy(filepath);

    elseif strcmpi(choice, '2')
        subchoice = input('Voulez-vous calculer la motion_energy sur le film tel quel ou passer ? (1/2) ', 's');
        if strcmpi(subchoice, '1')
            motion_energy = compute_motion_energy(filepath);
        else
            motion_energy = [];
        end
    else
        fprintf('Motion energy non calculée.\n');
        motion_energy = [];
    end
end

function y = smooth_savgol(x, order, framelen_target)
%SMOOTH_SAVGOL Robust Savitzky-Golay smoothing.
% Ensures framelen is odd and > order; falls back to no-op if too short.
    x = x(:);
    N = numel(x);

    framelen = min(framelen_target, N);

    if mod(framelen, 2) == 0
        framelen = framelen - 1;
    end

    if framelen <= order
        framelen = order + 2;
        if mod(framelen, 2) == 0
            framelen = framelen + 1;
        end
    end

    if N < framelen || framelen < 3
        y = x;
        return;
    end

    y = sgolayfilt(x, order, framelen);
end

function onsets = get_onsets(bin_motion)
%GET_ONSETS Indices where signal goes from 0 to 1
    bin_motion = bin_motion(:);
    onsets = find(bin_motion(2:end) == 1 & bin_motion(1:end-1) == 0) + 1;
end

function offsets = get_offsets(bin_motion)
%GET_OFFSETS Indices where signal goes from 1 to 0
    bin_motion = bin_motion(:);
    offsets = find(bin_motion(2:end) == 0 & bin_motion(1:end-1) == 1) + 1;
end