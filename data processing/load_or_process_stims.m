function data = load_or_process_stims(date_group_paths, current_gcamp_TSeries_path, data)
% 1. Identifier chaque stim par son TSeries réel
% 2. Supprimer les anciens TSeries non sélectionnés
% 3. Réordonner les données si l’ordre de sélection change
% 4. Ne pas recharger ce qui est déjà en mémoire
% 5. Charger seulement les champs manquants

    numFolders = numel(date_group_paths);

    if nargin < 3 || isempty(data)
        data = struct();
    end

    if ~isfield(data, 'stim') || ~isstruct(data.stim) || isempty(data.stim)
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

    data = init_stim_data_struct_if_needed(data, numFolders, stim_fields);

    % Garder uniquement les TSeries actuellement sélectionnés
    data = keep_only_selected_tseries_stim(data, stim_fields, current_gcamp_TSeries_path);

    for m = 1:numFolders

        data = ensure_stim_entry_exists(data, stim_fields, numFolders, m);
        data.stim.stim_tseries_path{m} = char(current_gcamp_TSeries_path{m});

        [~, date_name] = fileparts(date_group_paths{m});

        stim_src = fullfile(date_group_paths{m}, 'stim');
        stim_dst = fullfile(current_gcamp_TSeries_path{m}, 'stim');

        % -------------------------------------------------------------
        % Si tout est déjà en mémoire : ne rien recharger
        % -------------------------------------------------------------
        if stim_already_complete(data, m)
            fprintf('Date %s : stim déjà en mémoire, aucun rechargement.\n', date_name);
            continue;
        end

        % -------------------------------------------------------------
        % Déplacement éventuel du dossier stim
        % -------------------------------------------------------------
        if exist(stim_src, 'dir') && ~strcmp(stim_src, stim_dst)

            fprintf('Date %s : dossier stim trouvé dans le dossier date\n', date_name);

            try
                movefile(stim_src, stim_dst);
                fprintf('Date %s : stim déplacé vers %s\n', date_name, stim_dst);
            catch ME
                warning('Date %s : erreur déplacement stim : %s', date_name, ME.message);
            end

        elseif exist(stim_dst, 'dir')

            fprintf('Date %s : stim déjà présent dans TSeries (%s)\n', date_name, stim_dst);

        else

            fprintf('Date %s : aucun dossier stim trouvé (ni dans date, ni dans TSeries)\n', date_name);

        end

        files = struct( ...
            'stim_frames_log_group', fullfile(stim_dst, 'stim_frames_log.npy'), ...
            'stim_protocol_group',   fullfile(stim_dst, 'stim_protocol.npy'), ...
            'stim_reply_log_group',  fullfile(stim_dst, 'stim_reply_log.npy'), ...
            'stim_times_group',      fullfile(stim_dst, 'stim_times.npy'), ...
            'stim_values_log_group', fullfile(stim_dst, 'stim_values_log.npy') ...
        );

        fn = fieldnames(files);

        for i = 1:numel(fn)

            field = fn{i};
            filepath = files.(field);

            % Ne recharge pas un champ déjà présent
            if stim_field_has_value(data, field, m)
                continue;
            end

            if exist(filepath, 'file') ~= 2
                data.stim.(field){m} = [];
                continue;
            end

            try
                data.stim.(field){m} = readNPY(filepath);

            catch
                try
                    mod = py.importlib.import_module('python_function');
                    py_val = mod.read_npy_file(filepath);

                    data.stim.(field){m} = double(py_val);

                catch ME2
                    warning('Date %s : lecture impossible %s : %s', ...
                        date_name, filepath, ME2.message);

                    data.stim.(field){m} = [];
                end
            end
        end
    end

    data = keep_only_selected_tseries_stim(data, stim_fields, current_gcamp_TSeries_path);
end


% =====================================================================
% Helpers
% =====================================================================

function data = init_stim_data_struct_if_needed(data, numFolders, stim_fields)

    if ~isfield(data, 'stim') || ~isstruct(data.stim) || isempty(data.stim)
        data.stim = struct();
    end

    for f = 1:numel(stim_fields)

        field = stim_fields{f};

        if ~isfield(data.stim, field) || ~iscell(data.stim.(field))
            data.stim.(field) = cell(1, numFolders);

        elseif numel(data.stim.(field)) < numFolders
            oldv = data.stim.(field);
            tmp = cell(1, numFolders);
            tmp(1:numel(oldv)) = oldv(:);
            data.stim.(field) = tmp;
        end
    end
end


function data = ensure_stim_entry_exists(data, stim_fields, numFolders, m)

    data = init_stim_data_struct_if_needed(data, numFolders, stim_fields);

    for f = 1:numel(stim_fields)

        field = stim_fields{f};

        if numel(data.stim.(field)) < m
            tmp = cell(1, numFolders);
            tmp(1:numel(data.stim.(field))) = data.stim.(field)(:);
            data.stim.(field) = tmp;
        end
    end
end


function tf = stim_field_slot_exists(data, field, m)

    tf = isfield(data, 'stim') && ...
         isfield(data.stim, field) && ...
         iscell(data.stim.(field)) && ...
         numel(data.stim.(field)) >= m;
end


function tf = stim_field_has_value(data, field, m)

    tf = stim_field_slot_exists(data, field, m) && ...
         ~isempty(data.stim.(field){m});
end


function tf = stim_already_complete(data, m)

    tf = ...
        stim_field_has_value(data, 'stim_frames_log_group', m) && ...
        stim_field_has_value(data, 'stim_protocol_group', m) && ...
        stim_field_has_value(data, 'stim_reply_log_group', m) && ...
        stim_field_has_value(data, 'stim_times_group', m) && ...
        stim_field_has_value(data, 'stim_values_log_group', m);
end


function data = keep_only_selected_tseries_stim(data, stim_fields, current_gcamp_TSeries_path)

    if ~isfield(data, 'stim') || ~isstruct(data.stim)
        return;
    end

    selected_paths = cellfun(@char, current_gcamp_TSeries_path(:), 'UniformOutput', false);
    numFolders = numel(selected_paths);

    if ~isfield(data.stim, 'stim_tseries_path') || ...
            ~iscell(data.stim.stim_tseries_path) || ...
            isempty(data.stim.stim_tseries_path)

        for f = 1:numel(stim_fields)

            field = stim_fields{f};

            if isfield(data.stim, field) && iscell(data.stim.(field))

                data.stim.(field) = data.stim.(field)(1:min(numel(data.stim.(field)), numFolders));

                if numel(data.stim.(field)) < numFolders
                    tmp = cell(1, numFolders);
                    tmp(1:numel(data.stim.(field))) = data.stim.(field)(:);
                    data.stim.(field) = tmp;
                end
            end
        end

        data.stim.stim_tseries_path = selected_paths(:)';
        return;
    end

    old_paths = data.stim.stim_tseries_path(:);
    new_stim = struct();

    for f = 1:numel(stim_fields)
        field = stim_fields{f};
        new_stim.(field) = cell(1, numFolders);
    end

    for m = 1:numFolders

        selected_path = selected_paths{m};
        old_idx = [];

        for j = 1:numel(old_paths)
            if ~isempty(old_paths{j}) && strcmp(char(old_paths{j}), selected_path)
                old_idx = j;
                break;
            end
        end

        for f = 1:numel(stim_fields)

            field = stim_fields{f};

            if strcmp(field, 'stim_tseries_path')
                new_stim.(field){m} = selected_path;
                continue;
            end

            if ~isempty(old_idx) && ...
                    isfield(data.stim, field) && ...
                    iscell(data.stim.(field)) && ...
                    numel(data.stim.(field)) >= old_idx

                new_stim.(field){m} = data.stim.(field){old_idx};
            else
                new_stim.(field){m} = [];
            end
        end
    end

    data.stim = new_stim;
end