function movie = load_or_process_movie( ...
    current_gcamp_TSeries_path, gcamp_output_folders, avg_block, ...
    sampling_rate_group, current_animal_group, data)

% LOAD_OR_PROCESS_MOVIE
% - recharge results_movie.mat si présent
% - complète uniquement les champs absents dans data.movie
% - ne réécrit pas les données déjà présentes en mémoire
% - pose les questions de calcul de motion_energy une seule fois
% - seulement si nécessaire
% - stocke dans data.movie.<field>{m}
% - utilise movie.motion_energy_status{m} pour distinguer :
%       'done' / 'skipped' / 'no_camera' / 'no_movie'
% - retourne uniquement data.movie

    numFolders = numel(current_gcamp_TSeries_path);

    fields_movie = { ...
        'motion_energy_group', ...
        'motion_energy_smooth_group', ...
        'avg_active_motion_onsets_group', ...
        'avg_active_motion_offsets_group', ...
        'active_motion_onsets_group', ...
        'active_motion_offsets_group', ...
        'speed_active_group', ...
        'motion_energy_status' ...
    };

    data = init_movie_data_struct_if_needed(data, numFolders, fields_movie);

    camFolders = cell(numFolders,1);
    fijiPath = 'C:\Users\goldstein\Fiji.app\fiji-windows-x64.exe';

    % Poser les questions seulement si nécessaire
    motion_strategy = [];
    motion_strategy_initialized = false;

    for m = 1:numFolders

        data = ensure_movie_entry_exists(data, fields_movie, numFolders, m);

        root_folder_m = extract_movie_root_folder(gcamp_output_folders, m);
        if isempty(root_folder_m)
            warning('load_or_process_movie:noOutputFolder', ...
                'Impossible de déterminer le dossier de sortie pour m=%d.', m);
            continue;
        end

        savePath = fullfile(root_folder_m, 'results_movie.mat');

        % Reload .mat sans écraser ce qui existe déjà en mémoire
        if exist(savePath, 'file') == 2
            loaded = load(savePath);
            data = merge_loaded_movie_into_data(data, loaded, fields_movie, m);
        end

        has_new_data_for_group = false;

        %-----------------------------------------
        % Vérifier si tout existe vraiment déjà
        %-----------------------------------------
        already_has_all = ...
            movie_field_has_value(data, 'motion_energy_group', m) && ...
            movie_field_has_value(data, 'motion_energy_smooth_group', m) && ...
            movie_field_has_value(data, 'avg_active_motion_onsets_group', m) && ...
            movie_field_has_value(data, 'avg_active_motion_offsets_group', m) && ...
            movie_field_has_value(data, 'active_motion_onsets_group', m) && ...
            movie_field_has_value(data, 'active_motion_offsets_group', m) && ...
            movie_field_has_value(data, 'speed_active_group', m);

        if already_has_all
            fprintf('Movie folder %d: motion data already processed, skipping.\n', m);
            continue;
        end

        % Si explicitement "skipped/no_camera/no_movie", ne pas redemander
        if movie_status_already_final(data, m)
            fprintf('Movie folder %d: motion previously marked as %s, skipping recomputation.\n', ...
                m, string(data.movie.motion_energy_status{m}));

            data = assign_empty_movie_fields_if_missing(data, m);
            save_movie_fields_if_needed(savePath, data, fields_movie, m, false);
            continue;
        end

        %-----------------------------------------
        % Localiser dossier caméra
        %-----------------------------------------
        tseries_path_m = current_gcamp_TSeries_path{m};

        camPath    = fullfile(tseries_path_m, 'cam',    'Concatenated');
        cameraPath = fullfile(tseries_path_m, 'camera', 'Concatenated');

        if isfolder(camPath)
            camFolders{m} = camPath;
            fprintf('Found cam folder: %s\n', camPath);
        elseif isfolder(cameraPath)
            camFolders{m} = cameraPath;
            fprintf('Found camera folder: %s\n', cameraPath);
        else
            fprintf('No Camera images found in %s.\n', tseries_path_m);

            data = assign_empty_movie_fields_if_missing(data, m);
            data.movie.motion_energy_status{m} = 'no_camera';
            has_new_data_for_group = true;
            save_movie_fields_if_needed(savePath, data, fields_movie, m, has_new_data_for_group);
            continue;
        end

        filepath = fullfile(camFolders{m}, 'cam_crop.tif');
        if exist(filepath, 'file') ~= 2
            fprintf('No movie found at %s.\n', filepath);

            data = assign_empty_movie_fields_if_missing(data, m);
            data.movie.motion_energy_status{m} = 'no_movie';
            has_new_data_for_group = true;
            save_movie_fields_if_needed(savePath, data, fields_movie, m, has_new_data_for_group);
            continue;
        end

        %-----------------------------------------
        % 1) motion_energy
        %-----------------------------------------
        if ~movie_field_has_value(data, 'motion_energy_group', m)

            if ~motion_strategy_initialized
                motion_strategy = ask_motion_energy_strategy_once();
                motion_strategy_initialized = true;
            end

            motion_energy = compute_motion_energy_with_strategy(filepath, fijiPath, motion_strategy);
            data.movie.motion_energy_group{m} = motion_energy;

            if isempty(motion_energy)
                data.movie.motion_energy_status{m} = 'skipped';
            else
                data.movie.motion_energy_status{m} = 'done';
            end

            has_new_data_for_group = true;
        else
            motion_energy = data.movie.motion_energy_group{m};

            if ~movie_status_exists(data, m) || isempty(data.movie.motion_energy_status{m})
                data.movie.motion_energy_status{m} = 'done';
                has_new_data_for_group = true;
            end
        end

        if isempty(motion_energy)
            data = assign_empty_movie_fields_if_missing(data, m);
            has_new_data_for_group = true;
            save_movie_fields_if_needed(savePath, data, fields_movie, m, has_new_data_for_group);
            continue;
        end

        %-----------------------------------------
        % 2) avg_motion_energy
        %-----------------------------------------
        avg_motion_energy = average_frames(motion_energy, avg_block);

        %-----------------------------------------
        % 3) motion_energy_smooth
        %-----------------------------------------
        if ~movie_field_has_value(data, 'motion_energy_smooth_group', m)
            motion_energy_smooth = smooth_savgol(avg_motion_energy, 3, 11);
            data.movie.motion_energy_smooth_group{m} = motion_energy_smooth;
            has_new_data_for_group = true;
        else
            motion_energy_smooth = data.movie.motion_energy_smooth_group{m};
        end

        if isempty(motion_energy_smooth)
            data = assign_empty_binary_movie_fields_if_missing(data, m);
            has_new_data_for_group = true;
            save_movie_fields_if_needed(savePath, data, fields_movie, m, has_new_data_for_group);
            continue;
        end

        %-----------------------------------------
        % 4) Onsets / offsets / speed_active
        %-----------------------------------------
        need_bin = ...
            ~movie_field_has_value(data, 'avg_active_motion_onsets_group', m) || ...
            ~movie_field_has_value(data, 'avg_active_motion_offsets_group', m) || ...
            ~movie_field_has_value(data, 'active_motion_onsets_group', m) || ...
            ~movie_field_has_value(data, 'active_motion_offsets_group', m) || ...
            ~movie_field_has_value(data, 'speed_active_group', m);

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

            N_frames = numel(motion_energy);
            onsets_frames  = (avg_onsets  - 1) * avg_block + 1;
            offsets_frames =  avg_offsets * avg_block;

            onsets_frames  = max(1, onsets_frames);
            offsets_frames = min(N_frames, offsets_frames);

            speed_active = repelem(bin_sig(:), avg_block);

            if isempty(speed_active)
                speed_active = zeros(N_frames,1);
            elseif numel(speed_active) < N_frames
                speed_active(end+1:N_frames) = speed_active(end);
            else
                speed_active = speed_active(1:N_frames);
            end

            data.movie.avg_active_motion_onsets_group{m}  = avg_onsets;
            data.movie.avg_active_motion_offsets_group{m} = avg_offsets;
            data.movie.active_motion_onsets_group{m}      = onsets_frames;
            data.movie.active_motion_offsets_group{m}     = offsets_frames;
            data.movie.speed_active_group{m}              = speed_active;

            has_new_data_for_group = true;

        else
            avg_onsets  = data.movie.avg_active_motion_onsets_group{m};
            avg_offsets = data.movie.avg_active_motion_offsets_group{m};
        end

        save_movie_fields_if_needed(savePath, data, fields_movie, m, has_new_data_for_group);

        png_filename = fullfile(root_folder_m, 'binary_motion_energy.png');

        if ~isfile(png_filename) && ~isempty(motion_energy_smooth)
            fig = figure('Visible','off', 'Color','w');
            hold on;

            dt = avg_block / sampling_rate_group{m};
            time_axis = (0:numel(motion_energy_smooth)-1) * dt;

            yl = [min(motion_energy_smooth) max(motion_energy_smooth)];
            if yl(1) == yl(2)
                yl = yl + [-1 1]*eps;
            end

            for kk = 1:min(numel(avg_onsets), numel(avg_offsets))
                patch([time_axis(avg_onsets(kk)) time_axis(avg_offsets(kk)) ...
                       time_axis(avg_offsets(kk)) time_axis(avg_onsets(kk))], ...
                      [yl(1) yl(1) yl(2) yl(2)], ...
                      [1 0.8 0.8], 'EdgeColor','none', 'FaceAlpha',0.4);
            end

            if isempty(bin_sig)
                [~, thr_tmp, ~] = compute_thresholds_for_bin_state_detection(motion_energy_smooth, false);
                [bin_tmp, ~, ~, ~] = binarise_motion( ...
                    motion_energy_smooth, thr_tmp, sampling_rate_group{m}, avg_block, 3.0, 5);

                plot(time_axis, bin_tmp(:)' * yl(2), 'Color',[1 0.5 0], 'LineWidth',2);
                yline(thr_tmp, '--r', 'LineWidth',1);
            else
                plot(time_axis, bin_sig(:)' * yl(2), 'Color',[1 0.5 0], 'LineWidth',2);
                if ~isempty(thr_li)
                    yline(thr_li, '--r', 'LineWidth',1);
                end
            end

            plot(time_axis, motion_energy_smooth, 'Color',[0 0 1], 'LineWidth',2);
            title(sprintf('binary motion\\_energy - %s', current_animal_group));
            xlabel('Time (s)');
            ylabel('Motion energy');
            grid on;
            hold off;

            saveas(fig, png_filename);
            close(fig);
        end
    end

    movie = data.movie;
end


% =====================================================================
% Helpers
% =====================================================================

function strategy = ask_motion_energy_strategy_once()
    strategy = struct();
    strategy.open_in_fiji = false;
    strategy.compute_direct = false;
    strategy.skip = false;

    choice = input('Voulez-vous ouvrir le film dans Fiji pour cropper ? (1/2) ', 's');

    if strcmpi(choice, '1')
        strategy.open_in_fiji = true;
        return;
    end

    subchoice = input('Voulez-vous calculer la motion_energy sur le film tel quel ou passer ? (1/2) ', 's');

    if strcmpi(subchoice, '1')
        strategy.compute_direct = true;
    else
        strategy.skip = true;
    end
end

function motion_energy = compute_motion_energy_with_strategy(filepath, fijiPath, strategy)
    if strategy.open_in_fiji
        fprintf('Ouverture de %s dans Fiji...\n', filepath);
        system(sprintf('"%s" "%s"', fijiPath, filepath));
        motion_energy = compute_motion_energy(filepath);
    elseif strategy.compute_direct
        motion_energy = compute_motion_energy(filepath);
    else
        fprintf('Motion energy non calculée pour %s.\n', filepath);
        motion_energy = [];
    end
end

function data = init_movie_data_struct_if_needed(data, numFolders, fieldNames)
    if nargin < 1 || isempty(data)
        data = struct();
    end

    if ~isfield(data, 'movie') || ~isstruct(data.movie) || isempty(data.movie)
        data.movie = struct();
    end

    for i = 1:numel(fieldNames)
        fn = fieldNames{i};
        if ~isfield(data.movie, fn) || ~iscell(data.movie.(fn))
            data.movie.(fn) = cell(numFolders,1);
        elseif numel(data.movie.(fn)) < numFolders
            oldv = data.movie.(fn);
            tmp = cell(numFolders,1);
            tmp(1:numel(oldv)) = oldv(:);
            data.movie.(fn) = tmp;
        end
    end
end

function data = ensure_movie_entry_exists(data, fieldNames, numFolders, m)
    data = init_movie_data_struct_if_needed(data, numFolders, fieldNames);

    for i = 1:numel(fieldNames)
        fn = fieldNames{i};
        if numel(data.movie.(fn)) < m
            tmp = cell(numFolders,1);
            tmp(1:numel(data.movie.(fn))) = data.movie.(fn)(:);
            data.movie.(fn) = tmp;
        end
    end
end

function tf = movie_field_slot_exists(data, fieldName, m)
    tf = isfield(data, 'movie') && ...
         isfield(data.movie, fieldName) && ...
         iscell(data.movie.(fieldName)) && ...
         numel(data.movie.(fieldName)) >= m;
end

function tf = movie_field_has_value(data, fieldName, m)
    tf = movie_field_slot_exists(data, fieldName, m) && ...
         ~isempty(data.movie.(fieldName){m});
end

function tf = movie_status_exists(data, m)
    tf = movie_field_slot_exists(data, 'motion_energy_status', m);
end

function tf = movie_status_already_final(data, m)
    tf = false;
    if movie_status_exists(data, m) && ~isempty(data.movie.motion_energy_status{m})
        status = string(data.movie.motion_energy_status{m});
        tf = any(status == ["skipped","no_camera","no_movie"]);
    end
end

function data = merge_loaded_movie_into_data(data, loaded, fields_movie, m)
    for f = 1:numel(fields_movie)
        fieldName = fields_movie{f};

        if ~isfield(loaded, fieldName)
            continue;
        end

        if ~movie_field_slot_exists(data, fieldName, m) || isempty(data.movie.(fieldName){m})
            data.movie.(fieldName){m} = loaded.(fieldName);
        end
    end
end

function root_folder_m = extract_movie_root_folder(gcamp_output_folders, m)
    root_folder_m = '';

    if isempty(gcamp_output_folders) || m > numel(gcamp_output_folders) || isempty(gcamp_output_folders{m})
        return;
    end

    this_entry = gcamp_output_folders{m};

    if iscell(this_entry)
        if ~isempty(this_entry{1})
            root_folder_m = fileparts(this_entry{1});
        end
    elseif ischar(this_entry) || isstring(this_entry)
        root_folder_m = char(this_entry);
    end
end

function data = assign_empty_movie_fields_if_missing(data, m)
    movie_fields = { ...
        'motion_energy_group', ...
        'motion_energy_smooth_group', ...
        'avg_active_motion_onsets_group', ...
        'avg_active_motion_offsets_group', ...
        'active_motion_onsets_group', ...
        'active_motion_offsets_group', ...
        'speed_active_group' ...
    };

    for i = 1:numel(movie_fields)
        fn = movie_fields{i};
        if ~movie_field_slot_exists(data, fn, m)
            data.movie.(fn){m} = [];
        end
    end
end

function data = assign_empty_binary_movie_fields_if_missing(data, m)
    movie_fields = { ...
        'avg_active_motion_onsets_group', ...
        'avg_active_motion_offsets_group', ...
        'active_motion_onsets_group', ...
        'active_motion_offsets_group', ...
        'speed_active_group' ...
    };

    for i = 1:numel(movie_fields)
        fn = movie_fields{i};
        if ~movie_field_slot_exists(data, fn, m)
            data.movie.(fn){m} = [];
        end
    end
end

function save_movie_fields_if_needed(savePath, data, fields_movie, m, has_new_data_for_group)
    if ~has_new_data_for_group
        fprintf('Movie folder %d: no new movie data, results_movie.mat not modified.\n', m);
        return;
    end

    saveStruct = struct();
    for f = 1:numel(fields_movie)
        fieldName = fields_movie{f};
        if isfield(data, 'movie') && isfield(data.movie, fieldName) && numel(data.movie.(fieldName)) >= m
            saveStruct.(fieldName) = data.movie.(fieldName){m};
        end
    end

    if exist(savePath, 'file') == 2
        save(savePath, '-struct', 'saveStruct', '-append');
    else
        save(savePath, '-struct', 'saveStruct');
    end

    fprintf('Movie folder %d: movie fields updated in results_movie.mat.\n', m);
end

function y = smooth_savgol(x, order, framelen_target)
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
    bin_motion = bin_motion(:);
    onsets = find(bin_motion(2:end) == 1 & bin_motion(1:end-1) == 0) + 1;
end

function offsets = get_offsets(bin_motion)
    bin_motion = bin_motion(:);
    offsets = find(bin_motion(2:end) == 0 & bin_motion(1:end-1) == 1) + 1;
end