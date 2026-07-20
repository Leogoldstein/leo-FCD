function data = load_or_process_stims( ...
    date_group_paths, ...
    current_gcamp_TSeries_path, ...
    data)

% LOAD_OR_PROCESS_STIMS
%
% Charge les fichiers de stimulation associés à chaque acquisition.
%
% Organisation :
%   m = acquisition / TSeries
%
% La fonction :
%   - associe chaque stimulation à son TSeries réel ;
%   - conserve l'alignement avec les acquisitions sélectionnées ;
%   - réordonne les données si l'ordre des TSeries change ;
%   - recharge uniquement les champs manquants ;
%   - déplace éventuellement le dossier stim depuis le dossier date
%     vers le dossier TSeries.

    numAcquisitions = numel(date_group_paths);

    if nargin < 3 || isempty(data)
        data = struct();
    end

    if ~isfield(data, 'stim') || ...
            ~isstruct(data.stim) || ...
            isempty(data.stim)

        data.stim = struct();
    end

    stim_fields = { ...
        'stim_tseries_path', ...
        'stim_frames_log_group', ...
        'stim_protocol_group', ...
        'stim_reply_log_group', ...
        'stim_times_group', ...
        'stim_values_log_group' ...
    };

    data = init_stim_data_struct_if_needed( ...
        data, ...
        numAcquisitions, ...
        stim_fields);

    % =============================================================
    % Conserver uniquement les acquisitions sélectionnées
    % =============================================================

    data = keep_only_selected_tseries_stim( ...
        data, ...
        stim_fields, ...
        current_gcamp_TSeries_path);

    fprintf('\n');
    fprintf('============================================================\n');
    fprintf('STIMULATION PROCESSING\n');
    fprintf('Acquisitions: %d\n', numAcquisitions);
    fprintf('============================================================\n');

    for m = 1:numAcquisitions

        data = ensure_stim_entry_exists( ...
            data, ...
            stim_fields, ...
            numAcquisitions, ...
            m);

        date_path_m = get_path_entry( ...
            date_group_paths, m);

        tseries_path_m = get_path_entry( ...
            current_gcamp_TSeries_path, m);

        date_name = get_folder_name_or_default( ...
            date_path_m, ...
            sprintf('Date_%d', m));

        tseries_name = find_tseries_name_in_path( ...
            tseries_path_m);

        data.stim.stim_tseries_path{m} = ...
            tseries_path_m;

        fprintf('\n');
        fprintf('------------------------------------------------------------\n');
        fprintf('Stimulation acquisition %d/%d\n', ...
            m, numAcquisitions);
        fprintf('Date   : %s\n', date_name);
        fprintf('TSeries: %s\n', tseries_name);
        fprintf('------------------------------------------------------------\n');

        if isempty(date_path_m)

            warning( ...
                'load_or_process_stims:MissingDatePath', ...
                ['Acquisition %d/%d | %s | ' ...
                'date folder path is missing.'], ...
                m, numAcquisitions, tseries_name);

            fprintf('Status: skipped because date folder is missing.\n');
            continue;
        end

        if isempty(tseries_path_m)

            warning( ...
                'load_or_process_stims:MissingTSeriesPath', ...
                ['Acquisition %d/%d | %s | ' ...
                'TSeries path is missing.'], ...
                m, numAcquisitions, date_name);

            fprintf('Status: skipped because TSeries path is missing.\n');
            continue;
        end

        stim_src = fullfile( ...
            date_path_m, ...
            'stim');

        stim_dst = fullfile( ...
            tseries_path_m, ...
            'stim');

        % =========================================================
        % Données déjà complètes en mémoire
        % =========================================================

        if stim_already_complete(data, m)

            fprintf('Memory status: complete.\n');
            fprintf('Action       : no reload required.\n');

            print_stim_summary(data, m);

            continue;
        end

        fprintf('Memory status: incomplete.\n');

        % =========================================================
        % Localisation et déplacement éventuel du dossier stim
        % =========================================================

        fprintf('\nStim folder\n');

        if exist(stim_src, 'dir') == 7 && ...
                ~strcmpi(stim_src, stim_dst)

            fprintf('  Status: stim folder found in date directory.\n');
            fprintf('  Source: %s\n', stim_src);
            fprintf('  Target: %s\n', stim_dst);

            if exist(stim_dst, 'dir') == 7

                fprintf(['  Action: target stim folder already exists; ' ...
                    'source folder not moved.\n']);

            else

                try
                    movefile(stim_src, stim_dst);

                    fprintf('  Action: stim folder moved into TSeries.\n');

                catch ME

                    warning( ...
                        'load_or_process_stims:StimMoveFailed', ...
                        ['Acquisition %d/%d | %s | ' ...
                        'unable to move stim folder: %s'], ...
                        m, numAcquisitions, ...
                        tseries_name, ME.message);

                    fprintf('  Action: stim folder move failed.\n');
                end
            end

        elseif exist(stim_dst, 'dir') == 7

            fprintf('  Status: stim folder already present in TSeries.\n');
            fprintf('  Folder: %s\n', stim_dst);

        else

            fprintf('  Status: no stim folder found.\n');
            fprintf('  Date location   : %s\n', stim_src);
            fprintf('  TSeries location: %s\n', stim_dst);
        end

        % =========================================================
        % Fichiers de stimulation attendus
        % =========================================================

        files = struct( ...
            'stim_frames_log_group', ...
                fullfile(stim_dst, 'stim_frames_log.npy'), ...
            'stim_protocol_group', ...
                fullfile(stim_dst, 'stim_protocol.npy'), ...
            'stim_reply_log_group', ...
                fullfile(stim_dst, 'stim_reply_log.npy'), ...
            'stim_times_group', ...
                fullfile(stim_dst, 'stim_times.npy'), ...
            'stim_values_log_group', ...
                fullfile(stim_dst, 'stim_values_log.npy') ...
        );

        file_fields = fieldnames(files);

        fprintf('\nStim files\n');

        numLoaded = 0;
        numExisting = 0;
        numMissing = 0;
        numFailed = 0;

        for i = 1:numel(file_fields)

            fieldName = file_fields{i};
            filepath = files.(fieldName);

            display_name = get_stim_display_name( ...
                fieldName);

            fprintf('  %s\n', display_name);

            % -----------------------------------------------------
            % Champ déjà présent en mémoire
            % -----------------------------------------------------

            if stim_field_has_value( ...
                    data, fieldName, m)

                fprintf('    Status: already available in memory.\n');

                numExisting = numExisting + 1;
                continue;
            end

            % -----------------------------------------------------
            % Fichier absent
            % -----------------------------------------------------

            if exist(filepath, 'file') ~= 2

                data.stim.(fieldName){m} = [];

                fprintf('    Status: file not found.\n');
                fprintf('    File  : %s\n', filepath);

                numMissing = numMissing + 1;
                continue;
            end

            % -----------------------------------------------------
            % Lecture avec readNPY
            % -----------------------------------------------------

            try
                data.stim.(fieldName){m} = ...
                    readNPY(filepath);

                fprintf('    Status: loaded successfully.\n');
                fprintf('    File  : %s\n', filepath);

                numLoaded = numLoaded + 1;

            catch ME_readNPY

                % -------------------------------------------------
                % Lecture alternative avec Python
                % -------------------------------------------------

                try
                    mod = py.importlib.import_module( ...
                        'python_function');

                    py_val = mod.read_npy_file(filepath);

                    data.stim.(fieldName){m} = ...
                        convert_python_value_to_matlab(py_val);

                    fprintf('    Status: loaded using Python fallback.\n');
                    fprintf('    File  : %s\n', filepath);

                    numLoaded = numLoaded + 1;

                catch ME_python

                    warning( ...
                        'load_or_process_stims:StimReadFailed', ...
                        ['Acquisition %d/%d | %s | ' ...
                        'unable to read %s. readNPY error: %s | ' ...
                        'Python error: %s'], ...
                        m, numAcquisitions, ...
                        tseries_name, ...
                        filepath, ...
                        ME_readNPY.message, ...
                        ME_python.message);

                    data.stim.(fieldName){m} = [];

                    fprintf('    Status: loading failed.\n');
                    fprintf('    File  : %s\n', filepath);

                    numFailed = numFailed + 1;
                end
            end
        end

        % =========================================================
        % Résumé de l'acquisition
        % =========================================================

        fprintf('\nStimulation summary\n');
        fprintf('  TSeries            : %s\n', tseries_name);
        fprintf('  Loaded now         : %d\n', numLoaded);
        fprintf('  Already in memory  : %d\n', numExisting);
        fprintf('  Missing files      : %d\n', numMissing);
        fprintf('  Failed files       : %d\n', numFailed);

        if stim_already_complete(data, m)

            fprintf('  Final status       : complete.\n');

        elseif numLoaded + numExisting > 0

            fprintf('  Final status       : partially available.\n');

        else

            fprintf('  Final status       : no stimulation data.\n');
        end
    end

    % =============================================================
    % Réalignement final selon les TSeries sélectionnés
    % =============================================================

    data = keep_only_selected_tseries_stim( ...
        data, ...
        stim_fields, ...
        current_gcamp_TSeries_path);

    fprintf('\n');
    fprintf('============================================================\n');
    fprintf('STIMULATION PROCESSING COMPLETED\n');
    fprintf('Acquisitions: %d\n', numAcquisitions);
    fprintf('============================================================\n');
end


% =====================================================================
% Helpers
% =====================================================================

function data = init_stim_data_struct_if_needed( ...
    data, ...
    numAcquisitions, ...
    stim_fields)

    if ~isfield(data, 'stim') || ...
            ~isstruct(data.stim) || ...
            isempty(data.stim)

        data.stim = struct();
    end

    for f = 1:numel(stim_fields)

        fieldName = stim_fields{f};

        if ~isfield(data.stim, fieldName) || ...
                ~iscell(data.stim.(fieldName))

            data.stim.(fieldName) = ...
                cell(1, numAcquisitions);

        elseif numel(data.stim.(fieldName)) < ...
                numAcquisitions

            old_values = ...
                data.stim.(fieldName);

            new_values = ...
                cell(1, numAcquisitions);

            new_values(1:numel(old_values)) = ...
                old_values(:);

            data.stim.(fieldName) = ...
                new_values;
        end
    end
end


function data = ensure_stim_entry_exists( ...
    data, ...
    stim_fields, ...
    numAcquisitions, ...
    m)

    data = init_stim_data_struct_if_needed( ...
        data, ...
        numAcquisitions, ...
        stim_fields);

    for f = 1:numel(stim_fields)

        fieldName = stim_fields{f};

        if numel(data.stim.(fieldName)) < m

            new_values = ...
                cell(1, numAcquisitions);

            new_values(1:numel( ...
                data.stim.(fieldName))) = ...
                data.stim.(fieldName)(:);

            data.stim.(fieldName) = ...
                new_values;
        end
    end
end


function tf = stim_field_slot_exists( ...
    data, ...
    fieldName, ...
    m)

    tf = ...
        isfield(data, 'stim') && ...
        isfield(data.stim, fieldName) && ...
        iscell(data.stim.(fieldName)) && ...
        numel(data.stim.(fieldName)) >= m;
end


function tf = stim_field_has_value( ...
    data, ...
    fieldName, ...
    m)

    tf = ...
        stim_field_slot_exists( ...
            data, fieldName, m) && ...
        ~isempty(data.stim.(fieldName){m});
end


function tf = stim_already_complete(data, m)

    tf = ...
        stim_field_has_value( ...
            data, 'stim_frames_log_group', m) && ...
        stim_field_has_value( ...
            data, 'stim_protocol_group', m) && ...
        stim_field_has_value( ...
            data, 'stim_reply_log_group', m) && ...
        stim_field_has_value( ...
            data, 'stim_times_group', m) && ...
        stim_field_has_value( ...
            data, 'stim_values_log_group', m);
end


function data = keep_only_selected_tseries_stim( ...
    data, ...
    stim_fields, ...
    current_gcamp_TSeries_path)

    if ~isfield(data, 'stim') || ...
            ~isstruct(data.stim)

        return;
    end

    selected_paths = normalize_path_list( ...
        current_gcamp_TSeries_path);

    numAcquisitions = numel(selected_paths);

    if ~isfield(data.stim, 'stim_tseries_path') || ...
            ~iscell(data.stim.stim_tseries_path) || ...
            isempty(data.stim.stim_tseries_path)

        for f = 1:numel(stim_fields)

            fieldName = stim_fields{f};

            if isfield(data.stim, fieldName) && ...
                    iscell(data.stim.(fieldName))

                old_values = data.stim.(fieldName);

                new_values = cell(1, numAcquisitions);

                nCopy = min( ...
                    numel(old_values), ...
                    numAcquisitions);

                if nCopy > 0
                    new_values(1:nCopy) = ...
                        old_values(1:nCopy);
                end

                data.stim.(fieldName) = ...
                    new_values;
            end
        end

        data.stim.stim_tseries_path = ...
            selected_paths(:)';

        return;
    end

    old_paths = normalize_path_list( ...
        data.stim.stim_tseries_path);

    new_stim = struct();

    for f = 1:numel(stim_fields)

        fieldName = stim_fields{f};

        new_stim.(fieldName) = ...
            cell(1, numAcquisitions);
    end

    for m = 1:numAcquisitions

        selected_path = selected_paths{m};
        old_idx = [];

        for j = 1:numel(old_paths)

            if isempty(old_paths{j})
                continue;
            end

            if strcmpi( ...
                    normalize_single_path(old_paths{j}), ...
                    normalize_single_path(selected_path))

                old_idx = j;
                break;
            end
        end

        for f = 1:numel(stim_fields)

            fieldName = stim_fields{f};

            if strcmp(fieldName, 'stim_tseries_path')

                new_stim.(fieldName){m} = ...
                    selected_path;

                continue;
            end

            if ~isempty(old_idx) && ...
                    isfield(data.stim, fieldName) && ...
                    iscell(data.stim.(fieldName)) && ...
                    numel(data.stim.(fieldName)) >= old_idx

                new_stim.(fieldName){m} = ...
                    data.stim.(fieldName){old_idx};

            else

                new_stim.(fieldName){m} = [];
            end
        end
    end

    data.stim = new_stim;
end


function paths = normalize_path_list(path_values)

    if isempty(path_values)

        paths = {};
        return;
    end

    if ischar(path_values) || ...
            isstring(path_values)

        paths = {char(string(path_values))};
        return;
    end

    paths = cell(numel(path_values), 1);

    for i = 1:numel(path_values)

        if isempty(path_values{i})
            paths{i} = '';
        else
            paths{i} = char(string(path_values{i}));
        end
    end
end


function path_value = get_path_entry( ...
    path_values, ...
    index)

    path_value = '';

    if isempty(path_values)
        return;
    end

    if ischar(path_values) || ...
            isstring(path_values)

        if index == 1
            path_value = char(string(path_values));
        end

        return;
    end

    if ~iscell(path_values) || ...
            index > numel(path_values) || ...
            isempty(path_values{index})

        return;
    end

    path_value = char(string( ...
        path_values{index}));
end


function normalized_path = normalize_single_path( ...
    path_value)

    if isempty(path_value)

        normalized_path = '';
        return;
    end

    normalized_path = char(string(path_value));

    normalized_path = strrep( ...
        normalized_path, ...
        '/', ...
        '\');

    while endsWith(normalized_path, '\')
        normalized_path(end) = [];
    end
end


function folder_name = get_folder_name_or_default( ...
    folder_path, ...
    default_name)

    folder_name = default_name;

    if isempty(folder_path)
        return;
    end

    [~, candidate_name] = ...
        fileparts(folder_path);

    if ~isempty(candidate_name)
        folder_name = candidate_name;
    end
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


function display_name = get_stim_display_name( ...
    fieldName)

    switch fieldName

        case 'stim_frames_log_group'
            display_name = 'Stimulation frame indices';

        case 'stim_protocol_group'
            display_name = 'Stimulation protocol';

        case 'stim_reply_log_group'
            display_name = 'Stimulation reply log';

        case 'stim_times_group'
            display_name = 'Stimulation times';

        case 'stim_values_log_group'
            display_name = 'Stimulation values';

        otherwise
            display_name = fieldName;
    end
end


function matlab_value = convert_python_value_to_matlab( ...
    py_value)

    try
        matlab_value = double(py_value);
        return;
    catch
    end

    try
        matlab_value = py_value.tolist();
        matlab_value = double(matlab_value);
        return;
    catch
    end

    matlab_value = py_value;
end


function print_stim_summary(data, m)

    stim_fields = { ...
        'stim_frames_log_group', ...
        'stim_protocol_group', ...
        'stim_reply_log_group', ...
        'stim_times_group', ...
        'stim_values_log_group' ...
    };

    numAvailable = 0;

    for i = 1:numel(stim_fields)

        if stim_field_has_value( ...
                data, stim_fields{i}, m)

            numAvailable = numAvailable + 1;
        end
    end

    fprintf('\nStimulation summary\n');
    fprintf('  Available fields: %d/%d\n', ...
        numAvailable, numel(stim_fields));

    if numAvailable == numel(stim_fields)
        fprintf('  Final status    : complete.\n');
    elseif numAvailable > 0
        fprintf('  Final status    : partially available.\n');
    else
        fprintf('  Final status    : no stimulation data.\n');
    end
end