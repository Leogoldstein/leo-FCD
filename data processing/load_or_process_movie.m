function motion = load_or_process_movie( ...
    current_gcamp_TSeries_path, gcamp_output_folders, avg_block, ...
    sampling_rate_group, current_animal_group, data)

% - si les variables existent déjà dans data.motion, ne recharge pas le .mat
% - recharge results_motion.mat seulement pour compléter les champs absents
% - supprime de data.motion les entrées hors TSeries sélectionnés
% - stocke dans data.motion.<field>{m}
% - utilise motion.motion_energy_status{m} :
%       'done' / 'skipped' / 'no_camera' / 'no_motion'

    numFolders = numel(current_gcamp_TSeries_path);

    fields_motion = { ...
        'motion_tseries_path', ...
        'motion_energy_group', ...
        'motion_energy_smooth_group', ...
        'avg_active_motion_onsets_group', ...
        'avg_active_motion_offsets_group', ...
        'active_motion_onsets_group', ...
        'active_motion_offsets_group', ...
        'speed_active_group', ...
        'motion_energy_status' ...
    };

    data = init_motion_data_struct_if_needed(data, numFolders, fields_motion);

    camFolders = cell(numFolders,1);
    fijiPath = 'C:\Users\goldstein\Fiji.app\fiji-windows-x64.exe';

    motion_strategy = [];
    motion_strategy_initialized = false;

    for m = 1:numFolders

        data = ensure_motion_entry_exists(data, fields_motion, numFolders, m);
        data.motion.motion_tseries_path{m} = char(current_gcamp_TSeries_path{m});

        root_folder_m = extract_motion_root_folder(gcamp_output_folders, m);
        if isempty(root_folder_m)
            warning('load_or_process_motion:noOutputFolder', ...
                'Impossible de déterminer le dossier de sortie pour m=%d.', m);
            continue;
        end

        oldPath  = fullfile(root_folder_m, 'results_movie.mat');
        savePath = fullfile(root_folder_m, 'results_motion.mat');

        if exist(oldPath,'file') == 2 && exist(savePath,'file') ~= 2
            movefile(oldPath, savePath);
        end

        % -------------------------------------------------------------
        % Ne charger le .mat QUE si data.motion est incomplet
        % -------------------------------------------------------------
        already_has_all = motion_already_complete(data, m);

        if already_has_all
            fprintf('motion folder %d: motion data already in memory, no reload.\n', m);
            continue;
        end

        if exist(savePath, 'file') == 2
            loaded = load(savePath);
            data = merge_loaded_motion_into_data(data, loaded, fields_motion, m);

            if isempty(data.motion.motion_tseries_path{m})
                data.motion.motion_tseries_path{m} = char(current_gcamp_TSeries_path{m});
            end
        end

        has_new_data_for_group = false;

        already_has_all = motion_already_complete(data, m);
        if already_has_all
            fprintf('motion folder %d: motion data completed from file, skipping.\n', m);
            continue;
        end

        % -------------------------------------------------------------
        % Localiser dossier caméra
        % -------------------------------------------------------------
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

            data = assign_empty_motion_fields_if_missing(data, m);
            data.motion.motion_energy_status{m} = 'no_camera';
            has_new_data_for_group = true;
            save_motion_fields_if_needed(savePath, data, fields_motion, m, has_new_data_for_group);
            continue;
        end

        filepath = fullfile(camFolders{m}, 'cam_crop.tif');

        if exist(filepath, 'file') ~= 2
            fprintf('No motion found at %s.\n', filepath);

            data = assign_empty_motion_fields_if_missing(data, m);
            data.motion.motion_energy_status{m} = 'no_motion';
            has_new_data_for_group = true;
            save_motion_fields_if_needed(savePath, data, fields_motion, m, has_new_data_for_group);
            continue;
        end

        % -------------------------------------------------------------
        % 1) motion_energy
        % -------------------------------------------------------------
        if ~motion_field_has_value(data, 'motion_energy_group', m)

            if ~motion_strategy_initialized
                motion_strategy = ask_motion_energy_strategy_once();
                motion_strategy_initialized = true;
            end

            motion_energy = compute_motion_energy_with_strategy(filepath, fijiPath, motion_strategy);
            data.motion.motion_energy_group{m} = motion_energy;

            if isempty(motion_energy)
                data.motion.motion_energy_status{m} = 'skipped';
            else
                data.motion.motion_energy_status{m} = 'done';
            end

            has_new_data_for_group = true;

        else
            motion_energy = data.motion.motion_energy_group{m};

            if ~motion_status_exists(data, m) || isempty(data.motion.motion_energy_status{m})
                data.motion.motion_energy_status{m} = 'done';
                has_new_data_for_group = true;
            end
        end

        if isempty(motion_energy)
            data = assign_empty_motion_fields_if_missing(data, m);
            has_new_data_for_group = true;
            save_motion_fields_if_needed(savePath, data, fields_motion, m, has_new_data_for_group);
            continue;
        end

        % -------------------------------------------------------------
        % 2) avg_motion_energy
        % -------------------------------------------------------------
        avg_motion_energy = average_frames(motion_energy, avg_block);

        % -------------------------------------------------------------
        % 3) smooth
        % -------------------------------------------------------------
        if ~motion_field_has_value(data, 'motion_energy_smooth_group', m)
            motion_energy_smooth = smooth_savgol(avg_motion_energy, 3, 11);
            data.motion.motion_energy_smooth_group{m} = motion_energy_smooth;
            has_new_data_for_group = true;
        else
            motion_energy_smooth = data.motion.motion_energy_smooth_group{m};
        end

        if isempty(motion_energy_smooth)
            data = assign_empty_binary_motion_fields_if_missing(data, m);
            has_new_data_for_group = true;
            save_motion_fields_if_needed(savePath, data, fields_motion, m, has_new_data_for_group);
            continue;
        end

        % -------------------------------------------------------------
        % 4) binarisation
        % -------------------------------------------------------------
        need_bin = ...
            ~motion_field_has_value(data, 'avg_active_motion_onsets_group', m) || ...
            ~motion_field_has_value(data, 'avg_active_motion_offsets_group', m) || ...
            ~motion_field_has_value(data, 'active_motion_onsets_group', m) || ...
            ~motion_field_has_value(data, 'active_motion_offsets_group', m) || ...
            ~motion_field_has_value(data, 'speed_active_group', m);

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

            onsets_frames  = (avg_onsets - 1) * avg_block + 1;
            offsets_frames = avg_offsets * avg_block;

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

            data.motion.avg_active_motion_onsets_group{m}  = avg_onsets;
            data.motion.avg_active_motion_offsets_group{m} = avg_offsets;
            data.motion.active_motion_onsets_group{m}      = onsets_frames;
            data.motion.active_motion_offsets_group{m}     = offsets_frames;
            data.motion.speed_active_group{m}              = speed_active;

            has_new_data_for_group = true;

        else
            avg_onsets  = data.motion.avg_active_motion_onsets_group{m};
            avg_offsets = data.motion.avg_active_motion_offsets_group{m};
        end

        save_motion_fields_if_needed(savePath, data, fields_motion, m, has_new_data_for_group);

        % -------------------------------------------------------------
        % Figure
        % -------------------------------------------------------------
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
                      [1 0.8 0.8], ...
                      'EdgeColor','none', ...
                      'FaceAlpha',0.4);
            end

            if isempty(bin_sig)
                [~, thr_tmp, ~] = compute_thresholds_for_bin_state_detection(motion_energy_smooth, false);

                [bin_tmp, ~, ~, ~] = binarise_motion( ...
                    motion_energy_smooth, ...
                    thr_tmp, ...
                    sampling_rate_group{m}, ...
                    avg_block, ...
                    3.0, ...
                    5);

                plot(time_axis, bin_tmp(:)' * yl(2), ...
                    'Color',[1 0.5 0], ...
                    'LineWidth',2);

                yline(thr_tmp, '--r', 'LineWidth',1);

            else
                plot(time_axis, bin_sig(:)' * yl(2), ...
                    'Color',[1 0.5 0], ...
                    'LineWidth',2);

                if ~isempty(thr_li)
                    yline(thr_li, '--r', 'LineWidth',1);
                end
            end

            plot(time_axis, motion_energy_smooth, ...
                'Color',[0 0 1], ...
                'LineWidth',2);

            title(sprintf('binary motion\\_energy - %s', current_animal_group));
            xlabel('Time (s)');
            ylabel('Motion energy');
            grid on;
            hold off;

            saveas(fig, png_filename);
            close(fig);
        end
    end
   
    motion = data.motion;
end


% =====================================================================
% Helpers
% =====================================================================
function tf = motion_already_complete(data, m)

    tf = false;

    if ~motion_status_exists(data, m) || isempty(data.motion.motion_energy_status{m})
        return;
    end

    status = string(data.motion.motion_energy_status{m});

    switch status

        case "done"
            
        tf = ...
            motion_field_has_value(data, 'motion_energy_group', m) && ...
            motion_field_has_value(data, 'motion_energy_smooth_group', m) && ...
            motion_field_has_value(data, 'speed_active_group', m);

        case "skipped"

            % L'utilisateur a explicitement choisi de ne pas calculer
            tf = true;

        case {"no_camera","no_motion"}

            % Toujours revérifier si une caméra ou un cam_crop.tif
            % est apparu depuis le dernier passage
            tf = false;

        otherwise

            tf = false;

    end
end

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


function data = init_motion_data_struct_if_needed(data, numFolders, fieldNames)

    if nargin < 1 || isempty(data)
        data = struct();
    end

    if ~isfield(data, 'motion') || ~isstruct(data.motion) || isempty(data.motion)
        data.motion = struct();
    end

    for i = 1:numel(fieldNames)
        fn = fieldNames{i};

        if ~isfield(data.motion, fn) || ~iscell(data.motion.(fn))
            data.motion.(fn) = cell(numFolders,1);

        elseif numel(data.motion.(fn)) < numFolders
            oldv = data.motion.(fn);
            tmp = cell(numFolders,1);
            tmp(1:numel(oldv)) = oldv(:);
            data.motion.(fn) = tmp;
        end
    end
end


function data = ensure_motion_entry_exists(data, fieldNames, numFolders, m)

    data = init_motion_data_struct_if_needed(data, numFolders, fieldNames);

    for i = 1:numel(fieldNames)
        fn = fieldNames{i};

        if numel(data.motion.(fn)) < m
            tmp = cell(numFolders,1);
            tmp(1:numel(data.motion.(fn))) = data.motion.(fn)(:);
            data.motion.(fn) = tmp;
        end
    end
end


function tf = motion_field_slot_exists(data, fieldName, m)

    tf = isfield(data, 'motion') && ...
         isfield(data.motion, fieldName) && ...
         iscell(data.motion.(fieldName)) && ...
         numel(data.motion.(fieldName)) >= m;
end


function tf = motion_field_has_value(data, fieldName, m)

    tf = motion_field_slot_exists(data, fieldName, m) && ...
         ~isempty(data.motion.(fieldName){m});
end


function tf = motion_status_exists(data, m)

    tf = motion_field_slot_exists(data, 'motion_energy_status', m);
end


function data = merge_loaded_motion_into_data(data, loaded, fields_motion, m)

    for f = 1:numel(fields_motion)

        fieldName = fields_motion{f};

        if strcmp(fieldName, 'motion_tseries_path')
            continue;
        end

        if ~isfield(loaded, fieldName)
            continue;
        end

        if ~motion_field_slot_exists(data, fieldName, m) || isempty(data.motion.(fieldName){m})
            data.motion.(fieldName){m} = loaded.(fieldName);
        end
    end
end


function root_folder_m = extract_motion_root_folder(gcamp_output_folders, m)

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


function data = assign_empty_motion_fields_if_missing(data, m)

    motion_fields = { ...
        'motion_energy_group', ...
        'motion_energy_smooth_group', ...
        'avg_active_motion_onsets_group', ...
        'avg_active_motion_offsets_group', ...
        'active_motion_onsets_group', ...
        'active_motion_offsets_group', ...
        'speed_active_group' ...
    };

    for i = 1:numel(motion_fields)
        fn = motion_fields{i};

        if ~motion_field_slot_exists(data, fn, m)
            data.motion.(fn){m} = [];
        end
    end
end


function data = assign_empty_binary_motion_fields_if_missing(data, m)

    motion_fields = { ...
        'avg_active_motion_onsets_group', ...
        'avg_active_motion_offsets_group', ...
        'active_motion_onsets_group', ...
        'active_motion_offsets_group', ...
        'speed_active_group' ...
    };

    for i = 1:numel(motion_fields)
        fn = motion_fields{i};

        if ~motion_field_slot_exists(data, fn, m)
            data.motion.(fn){m} = [];
        end
    end
end


function save_motion_fields_if_needed(savePath, data, fields_motion, m, has_new_data_for_group)

    if ~has_new_data_for_group
        fprintf('motion folder %d: no new motion data, results_motion.mat not modified.\n', m);
        return;
    end

    saveStruct = struct();

    for f = 1:numel(fields_motion)

        fieldName = fields_motion{f};

        if strcmp(fieldName, 'motion_tseries_path')
            continue;
        end

        if isfield(data, 'motion') && ...
                isfield(data.motion, fieldName) && ...
                numel(data.motion.(fieldName)) >= m

            saveStruct.(fieldName) = data.motion.(fieldName){m};
        end
    end

    if exist(savePath, 'file') == 2
        save(savePath, '-struct', 'saveStruct', '-append');
    else
        save(savePath, '-struct', 'saveStruct');
    end

    fprintf('motion folder %d: motion fields updated in results_motion.mat.\n', m);
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