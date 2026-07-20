function motion = load_or_process_movie( ...
    current_gcamp_TSeries_path, ...
    gcamp_output_folders, ...
    avg_block, ...
    sampling_rate_group, ...
    current_animal_group, ...
    data)

% LOAD_OR_PROCESS_MOVIE
%
% Charge ou calcule l'énergie de mouvement pour chaque acquisition.
%
% Organisation :
%   m = acquisition / TSeries
%
% La fonction :
%   - conserve les données déjà présentes en mémoire ;
%   - recharge results_motion.mat uniquement si nécessaire ;
%   - recherche les images caméra ;
%   - calcule la motion energy si demandé ;
%   - détecte les périodes de mouvement ;
%   - sauvegarde les résultats par acquisition.

    numAcquisitions = numel(current_gcamp_TSeries_path);

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

    data = init_motion_data_struct_if_needed( ...
        data, numAcquisitions, fields_motion);

    camFolders = cell(numAcquisitions, 1);

    fijiPath = ...
        'C:\Users\goldstein\Fiji.app\fiji-windows-x64.exe';

    motion_strategy = [];
    motion_strategy_initialized = false;

    fprintf('\n');
    fprintf('============================================================\n');
    fprintf('MOTION PROCESSING\n');
    fprintf('Animal       : %s\n', char(string(current_animal_group)));
    fprintf('Acquisitions : %d\n', numAcquisitions);
    fprintf('Average block: %d frames\n', avg_block);
    fprintf('============================================================\n');

    for m = 1:numAcquisitions

        data = ensure_motion_entry_exists( ...
            data, ...
            fields_motion, ...
            numAcquisitions, ...
            m);

        tseries_path_m = get_tseries_path( ...
            current_gcamp_TSeries_path, m);

        tseries_name = find_tseries_name_in_path( ...
            tseries_path_m);

        sampling_rate_m = get_sampling_rate( ...
            sampling_rate_group, m);

        data.motion.motion_tseries_path{m} = ...
            tseries_path_m;

        fprintf('\n');
        fprintf('------------------------------------------------------------\n');
        fprintf('Motion acquisition %d/%d\n', m, numAcquisitions);
        fprintf('Animal       : %s\n', char(string(current_animal_group)));
        fprintf('TSeries      : %s\n', tseries_name);
        fprintf('Sampling rate: %.4f Hz\n', sampling_rate_m);
        fprintf('------------------------------------------------------------\n');

        root_folder_m = extract_motion_root_folder( ...
            gcamp_output_folders, m);

        if isempty(root_folder_m)

            warning( ...
                'load_or_process_movie:MissingOutputFolder', ...
                ['Acquisition %d/%d | %s | impossible de ' ...
                'déterminer le dossier de sortie.'], ...
                m, numAcquisitions, tseries_name);

            fprintf('Status: skipped because output folder is missing.\n');
            continue;
        end

        fprintf('Output folder: %s\n', root_folder_m);

        oldPath = fullfile( ...
            root_folder_m, ...
            'results_movie.mat');

        savePath = fullfile( ...
            root_folder_m, ...
            'results_motion.mat');

        % =========================================================
        % Rename old results file
        % =========================================================

        if exist(oldPath, 'file') == 2 && ...
                exist(savePath, 'file') ~= 2

            try
                movefile(oldPath, savePath);

                fprintf(['Existing results_movie.mat renamed to ' ...
                    'results_motion.mat.\n']);

            catch ME

                warning( ...
                    'load_or_process_movie:RenameFailed', ...
                    ['Acquisition %d/%d | %s | unable to rename ' ...
                    'results_movie.mat: %s'], ...
                    m, numAcquisitions, tseries_name, ME.message);
            end
        end

        % =========================================================
        % Data already complete in memory
        % =========================================================

        already_has_all = motion_already_complete(data, m);

        if already_has_all

            status_name = get_motion_status_name(data, m);

            fprintf('Memory status: complete.\n');
            fprintf('Motion status: %s\n', status_name);
            fprintf('Action       : no reload or recalculation required.\n');

            continue;
        end

        % =========================================================
        % Complete memory from results_motion.mat
        % =========================================================

        if exist(savePath, 'file') == 2

            fprintf('Memory status: incomplete.\n');
            fprintf('Loading missing motion fields from results_motion.mat...\n');

            try
                loaded = load(savePath);

                data = merge_loaded_motion_into_data( ...
                    data, ...
                    loaded, ...
                    fields_motion, ...
                    m);

                if isempty(data.motion.motion_tseries_path{m})
                    data.motion.motion_tseries_path{m} = ...
                        tseries_path_m;
                end

            catch ME

                warning( ...
                    'load_or_process_movie:ResultsLoadFailed', ...
                    ['Acquisition %d/%d | %s | unable to load ' ...
                    'results_motion.mat: %s'], ...
                    m, numAcquisitions, tseries_name, ME.message);
            end
        else

            fprintf('Saved motion file: not found.\n');
        end

        has_new_data_for_acquisition = false;

        already_has_all = motion_already_complete(data, m);

        if already_has_all

            status_name = get_motion_status_name(data, m);

            fprintf('Memory completed from saved file.\n');
            fprintf('Motion status: %s\n', status_name);
            fprintf('Action       : calculation skipped.\n');

            continue;
        end

        % =========================================================
        % Locate camera folder
        % =========================================================

        camPath = fullfile( ...
            tseries_path_m, ...
            'cam', ...
            'Concatenated');

        cameraPath = fullfile( ...
            tseries_path_m, ...
            'camera', ...
            'Concatenated');

        fprintf('\nCamera data\n');

        if isfolder(camPath)

            camFolders{m} = camPath;

            fprintf('  Status: camera folder found.\n');
            fprintf('  Folder: %s\n', camPath);

        elseif isfolder(cameraPath)

            camFolders{m} = cameraPath;

            fprintf('  Status: camera folder found.\n');
            fprintf('  Folder: %s\n', cameraPath);

        else

            fprintf('  Status: no camera folder found.\n');
            fprintf('  Search: %s\n', camPath);
            fprintf('          %s\n', cameraPath);

            data = assign_empty_motion_fields_if_missing( ...
                data, m);

            data.motion.motion_energy_status{m} = ...
                'no_camera';

            has_new_data_for_acquisition = true;

            save_motion_fields_if_needed( ...
                savePath, ...
                data, ...
                fields_motion, ...
                m, ...
                has_new_data_for_acquisition, ...
                tseries_name);

            continue;
        end

        filepath = fullfile( ...
            camFolders{m}, ...
            'cam_crop.tif');

        if exist(filepath, 'file') ~= 2

            fprintf('  Movie status: cam_crop.tif not found.\n');
            fprintf('  Expected file: %s\n', filepath);

            data = assign_empty_motion_fields_if_missing( ...
                data, m);

            data.motion.motion_energy_status{m} = ...
                'no_motion';

            has_new_data_for_acquisition = true;

            save_motion_fields_if_needed( ...
                savePath, ...
                data, ...
                fields_motion, ...
                m, ...
                has_new_data_for_acquisition, ...
                tseries_name);

            continue;
        end

        fprintf('  Movie status: camera movie available.\n');
        fprintf('  Movie file  : %s\n', filepath);

        % =========================================================
        % 1. Motion energy
        % =========================================================

        fprintf('\nMotion energy\n');

        if ~motion_field_has_value( ...
                data, ...
                'motion_energy_group', ...
                m)

            fprintf('  Status: motion energy not available in memory.\n');

            if ~motion_strategy_initialized

                motion_strategy = ...
                    ask_motion_energy_strategy_once();

                motion_strategy_initialized = true;
            end

            motion_energy = compute_motion_energy_with_strategy( ...
                filepath, ...
                fijiPath, ...
                motion_strategy);

            data.motion.motion_energy_group{m} = ...
                motion_energy;

            if isempty(motion_energy)

                data.motion.motion_energy_status{m} = ...
                    'skipped';

                fprintf('  Result: motion energy calculation skipped.\n');

            else

                data.motion.motion_energy_status{m} = ...
                    'done';

                fprintf('  Result: motion energy calculated.\n');
                fprintf('  Frames: %d\n', numel(motion_energy));
            end

            has_new_data_for_acquisition = true;

        else

            motion_energy = ...
                data.motion.motion_energy_group{m};

            fprintf('  Status: existing motion energy reused.\n');
            fprintf('  Frames: %d\n', numel(motion_energy));

            if ~motion_status_exists(data, m) || ...
                    isempty(data.motion.motion_energy_status{m})

                data.motion.motion_energy_status{m} = ...
                    'done';

                has_new_data_for_acquisition = true;
            end
        end

        if isempty(motion_energy)

            data = assign_empty_motion_fields_if_missing( ...
                data, m);

            has_new_data_for_acquisition = true;

            save_motion_fields_if_needed( ...
                savePath, ...
                data, ...
                fields_motion, ...
                m, ...
                has_new_data_for_acquisition, ...
                tseries_name);

            continue;
        end

        % =========================================================
        % 2. Temporal averaging
        % =========================================================

        avg_motion_energy = average_frames( ...
            motion_energy, ...
            avg_block);

        fprintf('\nTemporal averaging\n');
        fprintf('  Input frames : %d\n', numel(motion_energy));
        fprintf('  Block size   : %d\n', avg_block);
        fprintf('  Output points: %d\n', numel(avg_motion_energy));

        % =========================================================
        % 3. Smoothing
        % =========================================================

        fprintf('\nMotion smoothing\n');

        if ~motion_field_has_value( ...
                data, ...
                'motion_energy_smooth_group', ...
                m)

            motion_energy_smooth = smooth_savgol( ...
                avg_motion_energy, ...
                3, ...
                11);

            data.motion.motion_energy_smooth_group{m} = ...
                motion_energy_smooth;

            has_new_data_for_acquisition = true;

            fprintf('  Status: smoothed motion signal calculated.\n');

        else

            motion_energy_smooth = ...
                data.motion.motion_energy_smooth_group{m};

            fprintf('  Status: existing smoothed signal reused.\n');
        end

        if isempty(motion_energy_smooth)

            fprintf('  Result: smoothed motion signal is empty.\n');

            data = assign_empty_binary_motion_fields_if_missing( ...
                data, m);

            has_new_data_for_acquisition = true;

            save_motion_fields_if_needed( ...
                savePath, ...
                data, ...
                fields_motion, ...
                m, ...
                has_new_data_for_acquisition, ...
                tseries_name);

            continue;
        end

        % =========================================================
        % 4. Motion state detection
        % =========================================================

        need_bin = ...
            ~motion_field_has_value( ...
                data, 'avg_active_motion_onsets_group', m) || ...
            ~motion_field_has_value( ...
                data, 'avg_active_motion_offsets_group', m) || ...
            ~motion_field_has_value( ...
                data, 'active_motion_onsets_group', m) || ...
            ~motion_field_has_value( ...
                data, 'active_motion_offsets_group', m) || ...
            ~motion_field_has_value( ...
                data, 'speed_active_group', m);

        thr_li = [];
        bin_sig = [];

        fprintf('\nMotion state detection\n');

        if need_bin

            [~, thr_li, ~] = ...
                compute_thresholds_for_bin_state_detection( ...
                    motion_energy_smooth, ...
                    false);

            [bin_sig, ~, ~, ~] = binarise_motion( ...
                motion_energy_smooth, ...
                thr_li, ...
                sampling_rate_m, ...
                avg_block, ...
                3.0, ...
                5);

            avg_onsets = get_onsets(bin_sig);
            avg_offsets = get_offsets(bin_sig);

            if ~isempty(bin_sig)

                if bin_sig(1) == 1
                    avg_onsets = [1; avg_onsets(:)];
                end

                if bin_sig(end) == 1
                    avg_offsets = [ ...
                        avg_offsets(:); ...
                        numel(bin_sig)];
                end
            end

            N_frames = numel(motion_energy);

            onsets_frames = ...
                (avg_onsets - 1) * avg_block + 1;

            offsets_frames = ...
                avg_offsets * avg_block;

            onsets_frames = max( ...
                1, ...
                onsets_frames);

            offsets_frames = min( ...
                N_frames, ...
                offsets_frames);

            speed_active = repelem( ...
                bin_sig(:), ...
                avg_block);

            if isempty(speed_active)

                speed_active = zeros(N_frames, 1);

            elseif numel(speed_active) < N_frames

                speed_active(end + 1:N_frames) = ...
                    speed_active(end);

            else

                speed_active = ...
                    speed_active(1:N_frames);
            end

            data.motion.avg_active_motion_onsets_group{m} = ...
                avg_onsets;

            data.motion.avg_active_motion_offsets_group{m} = ...
                avg_offsets;

            data.motion.active_motion_onsets_group{m} = ...
                onsets_frames;

            data.motion.active_motion_offsets_group{m} = ...
                offsets_frames;

            data.motion.speed_active_group{m} = ...
                speed_active;

            has_new_data_for_acquisition = true;

            fprintf('  Status         : motion states calculated.\n');
            fprintf('  Threshold      : %.6f\n', thr_li);
            fprintf('  Motion periods : %d\n', ...
                min(numel(avg_onsets), numel(avg_offsets)));

        else

            avg_onsets = ...
                data.motion.avg_active_motion_onsets_group{m};

            avg_offsets = ...
                data.motion.avg_active_motion_offsets_group{m};

            fprintf('  Status         : existing motion states reused.\n');
            fprintf('  Motion periods : %d\n', ...
                min(numel(avg_onsets), numel(avg_offsets)));
        end

        % =========================================================
        % Save
        % =========================================================

        save_motion_fields_if_needed( ...
            savePath, ...
            data, ...
            fields_motion, ...
            m, ...
            has_new_data_for_acquisition, ...
            tseries_name);

        % =========================================================
        % Figure
        % =========================================================

        png_filename = fullfile( ...
            root_folder_m, ...
            'binary_motion_energy.png');

        fprintf('\nMotion figure\n');

        if isfile(png_filename)

            fprintf('  Status: existing figure retained.\n');
            fprintf('  File  : %s\n', png_filename);

        elseif isempty(motion_energy_smooth)

            fprintf('  Status: figure not generated; signal is empty.\n');

        else

            try
                fig = figure( ...
                    'Visible', 'off', ...
                    'Color', 'w');

                hold on;

                dt = avg_block / sampling_rate_m;

                time_axis = ...
                    (0:numel(motion_energy_smooth) - 1) * dt;

                yl = [ ...
                    min(motion_energy_smooth), ...
                    max(motion_energy_smooth)];

                if yl(1) == yl(2)
                    yl = yl + [-1 1] * eps;
                end

                for kk = 1:min( ...
                        numel(avg_onsets), ...
                        numel(avg_offsets))

                    patch( ...
                        [ ...
                            time_axis(avg_onsets(kk)), ...
                            time_axis(avg_offsets(kk)), ...
                            time_axis(avg_offsets(kk)), ...
                            time_axis(avg_onsets(kk)) ...
                        ], ...
                        [ ...
                            yl(1), ...
                            yl(1), ...
                            yl(2), ...
                            yl(2) ...
                        ], ...
                        [1 0.8 0.8], ...
                        'EdgeColor', 'none', ...
                        'FaceAlpha', 0.4);
                end

                if isempty(bin_sig)

                    [~, thr_tmp, ~] = ...
                        compute_thresholds_for_bin_state_detection( ...
                            motion_energy_smooth, ...
                            false);

                    [bin_tmp, ~, ~, ~] = binarise_motion( ...
                        motion_energy_smooth, ...
                        thr_tmp, ...
                        sampling_rate_m, ...
                        avg_block, ...
                        3.0, ...
                        5);

                    plot( ...
                        time_axis, ...
                        bin_tmp(:)' * yl(2), ...
                        'Color', [1 0.5 0], ...
                        'LineWidth', 2);

                    yline( ...
                        thr_tmp, ...
                        '--r', ...
                        'LineWidth', 1);

                else

                    plot( ...
                        time_axis, ...
                        bin_sig(:)' * yl(2), ...
                        'Color', [1 0.5 0], ...
                        'LineWidth', 2);

                    if ~isempty(thr_li)

                        yline( ...
                            thr_li, ...
                            '--r', ...
                            'LineWidth', 1);
                    end
                end

                plot( ...
                    time_axis, ...
                    motion_energy_smooth, ...
                    'Color', [0 0 1], ...
                    'LineWidth', 2);

                title(sprintf( ...
                    'Binary motion energy - %s - %s', ...
                    char(string(current_animal_group)), ...
                    tseries_name), ...
                    'Interpreter', 'none');

                xlabel('Time (s)');
                ylabel('Motion energy');

                grid on;
                hold off;

                saveas(fig, png_filename);
                close(fig);

                fprintf('  Status: motion figure created.\n');
                fprintf('  File  : %s\n', png_filename);

            catch ME

                if exist('fig', 'var') && isgraphics(fig)
                    close(fig);
                end

                warning( ...
                    'load_or_process_movie:FigureFailed', ...
                    ['Acquisition %d/%d | %s | unable to create ' ...
                    'motion figure: %s'], ...
                    m, numAcquisitions, tseries_name, ME.message);

                fprintf('  Status: figure generation failed.\n');
            end
        end

        fprintf('\nAcquisition summary\n');
        fprintf('  TSeries: %s\n', tseries_name);
        fprintf('  Status : %s\n', ...
            get_motion_status_name(data, m));
    end

    fprintf('\n');
    fprintf('============================================================\n');
    fprintf('MOTION PROCESSING COMPLETED\n');
    fprintf('Animal      : %s\n', char(string(current_animal_group)));
    fprintf('Acquisitions: %d\n', numAcquisitions);
    fprintf('============================================================\n');

    motion = data.motion;
end


% =====================================================================
% Helpers
% =====================================================================

function tf = motion_already_complete(data, m)

    tf = false;

    if ~motion_status_exists(data, m) || ...
            isempty(data.motion.motion_energy_status{m})

        return;
    end

    status = string( ...
        data.motion.motion_energy_status{m});

    switch status

        case "done"

            tf = ...
                motion_field_has_value( ...
                    data, 'motion_energy_group', m) && ...
                motion_field_has_value( ...
                    data, 'motion_energy_smooth_group', m) && ...
                motion_field_has_value( ...
                    data, 'speed_active_group', m);

        case "skipped"

            tf = true;

        case {"no_camera", "no_motion"}

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

    fprintf('\n');
    fprintf('============================================================\n');
    fprintf('MOTION ENERGY STRATEGY\n');
    fprintf('============================================================\n');

    choice = input( ...
        ['Open the camera movie in Fiji for cropping?\n' ...
        '  1 = Yes\n' ...
        '  2 = No\n' ...
        'Choice: '], ...
        's');

    if strcmpi(choice, '1')

        strategy.open_in_fiji = true;
        return;
    end

    subchoice = input( ...
        ['Calculate motion energy on the current movie?\n' ...
        '  1 = Calculate directly\n' ...
        '  2 = Skip motion energy\n' ...
        'Choice: '], ...
        's');

    if strcmpi(subchoice, '1')
        strategy.compute_direct = true;
    else
        strategy.skip = true;
    end
end


function motion_energy = compute_motion_energy_with_strategy( ...
    filepath, fijiPath, strategy)

    if strategy.open_in_fiji

        fprintf('Opening camera movie in Fiji:\n');
        fprintf('%s\n', filepath);

        system(sprintf( ...
            '"%s" "%s"', ...
            fijiPath, ...
            filepath));

        motion_energy = ...
            compute_motion_energy(filepath);

    elseif strategy.compute_direct

        fprintf('Calculating motion energy directly from:\n');
        fprintf('%s\n', filepath);

        motion_energy = ...
            compute_motion_energy(filepath);

    else

        fprintf('Motion energy calculation skipped for:\n');
        fprintf('%s\n', filepath);

        motion_energy = [];
    end
end


function data = init_motion_data_struct_if_needed( ...
    data, numAcquisitions, fieldNames)

    if nargin < 1 || isempty(data)
        data = struct();
    end

    if ~isfield(data, 'motion') || ...
            ~isstruct(data.motion) || ...
            isempty(data.motion)

        data.motion = struct();
    end

    for i = 1:numel(fieldNames)

        fieldName = fieldNames{i};

        if ~isfield(data.motion, fieldName) || ...
                ~iscell(data.motion.(fieldName))

            data.motion.(fieldName) = ...
                cell(numAcquisitions, 1);

        elseif numel(data.motion.(fieldName)) < ...
                numAcquisitions

            old_values = data.motion.(fieldName);

            new_values = cell( ...
                numAcquisitions, 1);

            new_values(1:numel(old_values)) = ...
                old_values(:);

            data.motion.(fieldName) = ...
                new_values;
        end
    end
end


function data = ensure_motion_entry_exists( ...
    data, fieldNames, numAcquisitions, m)

    data = init_motion_data_struct_if_needed( ...
        data, ...
        numAcquisitions, ...
        fieldNames);

    for i = 1:numel(fieldNames)

        fieldName = fieldNames{i};

        if numel(data.motion.(fieldName)) < m

            new_values = cell( ...
                numAcquisitions, 1);

            new_values(1:numel( ...
                data.motion.(fieldName))) = ...
                data.motion.(fieldName)(:);

            data.motion.(fieldName) = ...
                new_values;
        end
    end
end


function tf = motion_field_slot_exists( ...
    data, fieldName, m)

    tf = ...
        isfield(data, 'motion') && ...
        isfield(data.motion, fieldName) && ...
        iscell(data.motion.(fieldName)) && ...
        numel(data.motion.(fieldName)) >= m;
end


function tf = motion_field_has_value( ...
    data, fieldName, m)

    tf = ...
        motion_field_slot_exists( ...
            data, fieldName, m) && ...
        ~isempty(data.motion.(fieldName){m});
end


function tf = motion_status_exists(data, m)

    tf = motion_field_slot_exists( ...
        data, ...
        'motion_energy_status', ...
        m);
end


function data = merge_loaded_motion_into_data( ...
    data, loaded, fields_motion, m)

    for f = 1:numel(fields_motion)

        fieldName = fields_motion{f};

        if strcmp(fieldName, 'motion_tseries_path')
            continue;
        end

        if ~isfield(loaded, fieldName)
            continue;
        end

        if ~motion_field_slot_exists( ...
                data, fieldName, m) || ...
                isempty(data.motion.(fieldName){m})

            data.motion.(fieldName){m} = ...
                loaded.(fieldName);
        end
    end
end


function root_folder_m = extract_motion_root_folder( ...
    gcamp_output_folders, m)

    root_folder_m = '';

    if isempty(gcamp_output_folders) || ...
            m > numel(gcamp_output_folders) || ...
            isempty(gcamp_output_folders{m})

        return;
    end

    this_entry = gcamp_output_folders{m};

    if iscell(this_entry)

        if ~isempty(this_entry) && ...
                ~isempty(this_entry{1})

            root_folder_m = ...
                fileparts(this_entry{1});
        end

    elseif ischar(this_entry) || ...
            isstring(this_entry)

        root_folder_m = ...
            char(this_entry);
    end
end


function data = assign_empty_motion_fields_if_missing( ...
    data, m)

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

        fieldName = motion_fields{i};

        if ~motion_field_slot_exists( ...
                data, fieldName, m) || ...
                isempty(data.motion.(fieldName){m})

            data.motion.(fieldName){m} = [];
        end
    end
end


function data = assign_empty_binary_motion_fields_if_missing( ...
    data, m)

    motion_fields = { ...
        'avg_active_motion_onsets_group', ...
        'avg_active_motion_offsets_group', ...
        'active_motion_onsets_group', ...
        'active_motion_offsets_group', ...
        'speed_active_group' ...
    };

    for i = 1:numel(motion_fields)

        fieldName = motion_fields{i};

        if ~motion_field_slot_exists( ...
                data, fieldName, m) || ...
                isempty(data.motion.(fieldName){m})

            data.motion.(fieldName){m} = [];
        end
    end
end


function save_motion_fields_if_needed( ...
    savePath, ...
    data, ...
    fields_motion, ...
    m, ...
    has_new_data_for_acquisition, ...
    tseries_name)

    if ~has_new_data_for_acquisition

        fprintf('\nMotion results\n');
        fprintf('  TSeries: %s\n', tseries_name);
        fprintf('  Status : no new data; results_motion.mat unchanged.\n');

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

            saveStruct.(fieldName) = ...
                data.motion.(fieldName){m};
        end
    end

    try
        if exist(savePath, 'file') == 2

            save( ...
                savePath, ...
                '-struct', ...
                'saveStruct', ...
                '-append');

        else

            save( ...
                savePath, ...
                '-struct', ...
                'saveStruct');
        end

        fprintf('\nMotion results\n');
        fprintf('  TSeries: %s\n', tseries_name);
        fprintf('  Status : results_motion.mat updated.\n');
        fprintf('  File   : %s\n', savePath);

    catch ME

        warning( ...
            'load_or_process_movie:SaveFailed', ...
            'TSeries %s | unable to save motion results: %s', ...
            tseries_name, ME.message);

        fprintf('\nMotion results\n');
        fprintf('  TSeries: %s\n', tseries_name);
        fprintf('  Status : save failed.\n');
    end
end


function y = smooth_savgol( ...
    x, order, framelen_target)

    x = x(:);
    N = numel(x);

    framelen = min( ...
        framelen_target, ...
        N);

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

    y = sgolayfilt( ...
        x, ...
        order, ...
        framelen);
end


function onsets = get_onsets(bin_motion)

    bin_motion = bin_motion(:);

    onsets = find( ...
        bin_motion(2:end) == 1 & ...
        bin_motion(1:end - 1) == 0) + 1;
end


function offsets = get_offsets(bin_motion)

    bin_motion = bin_motion(:);

    offsets = find( ...
        bin_motion(2:end) == 0 & ...
        bin_motion(1:end - 1) == 1) + 1;
end


function tseries_path = get_tseries_path( ...
    current_gcamp_TSeries_path, m)

    tseries_path = '';

    if isempty(current_gcamp_TSeries_path) || ...
            m > numel(current_gcamp_TSeries_path) || ...
            isempty(current_gcamp_TSeries_path{m})

        return;
    end

    tseries_path = char(string( ...
        current_gcamp_TSeries_path{m}));
end


function tseries_name = find_tseries_name_in_path( ...
    path_value)

    tseries_name = 'TSeries_unknown';

    if isempty(path_value)
        return;
    end

    path_value = char(string(path_value));

    while ~isempty(path_value)

        [parent_path, current_name] = ...
            fileparts(path_value);

        if startsWith( ...
                current_name, ...
                'TSeries-', ...
                'IgnoreCase', true)

            tseries_name = current_name;
            return;
        end

        if isempty(parent_path) || ...
                strcmp(parent_path, path_value)

            break;
        end

        path_value = parent_path;
    end
end


function sampling_rate_m = get_sampling_rate( ...
    sampling_rate_group, m)

    sampling_rate_m = NaN;

    if isempty(sampling_rate_group)
        return;
    end

    if iscell(sampling_rate_group)

        if m <= numel(sampling_rate_group) && ...
                ~isempty(sampling_rate_group{m})

            sampling_rate_m = double( ...
                sampling_rate_group{m});
        end

    elseif isnumeric(sampling_rate_group)

        if isscalar(sampling_rate_group)

            sampling_rate_m = ...
                double(sampling_rate_group);

        elseif m <= numel(sampling_rate_group)

            sampling_rate_m = ...
                double(sampling_rate_group(m));
        end
    end

    if isempty(sampling_rate_m) || ...
            ~isfinite(sampling_rate_m) || ...
            sampling_rate_m <= 0

        sampling_rate_m = 1;

        warning( ...
            'load_or_process_movie:InvalidSamplingRate', ...
            ['Invalid sampling rate for acquisition %d. ' ...
            'Fallback value of 1 Hz used.'], ...
            m);
    end
end


function status_name = get_motion_status_name(data, m)

    status_name = 'unknown';

    if ~motion_status_exists(data, m) || ...
            isempty(data.motion.motion_energy_status{m})

        return;
    end

    raw_status = string( ...
        data.motion.motion_energy_status{m});

    switch raw_status

        case "done"
            status_name = 'completed';

        case "skipped"
            status_name = 'calculation skipped';

        case "no_camera"
            status_name = 'no camera data';

        case "no_motion"
            status_name = 'camera movie missing';

        otherwise
            status_name = char(raw_status);
    end
end