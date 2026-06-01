function data = load_or_process_stims(date_group_paths, current_gcamp_TSeries_path, data)

    numFolders = numel(date_group_paths);

    % Initialisation data.stim
    if ~isfield(data, 'stim') || isempty(data.stim)
        data.stim = struct();
    end

    stim_fields = { ...
        'stim_frames_log_group', ...
        'stim_protocol_group', ...
        'stim_reply_log_group', ...
        'stim_times_group', ...
        'stim_values_log_group' ...
    };

    % Init cellules
    for f = 1:numel(stim_fields)
        field = stim_fields{f};
        if ~isfield(data.stim, field)
            data.stim.(field) = cell(1, numFolders);
        end
    end

    for m = 1:numFolders

        % Nom de la date
        [~, date_name] = fileparts(date_group_paths{m});

        % Chemins
        stim_src = fullfile(date_group_paths{m}, 'stim');
        stim_dst = fullfile(current_gcamp_TSeries_path{m}, 'stim');

        % --- Déplacement ---
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

        % --- Chargement ---
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

            if ~exist(filepath, 'file')
                data.stim.(field){m} = [];
                continue;
            end

            try
                % Lecture MATLAB
                data.stim.(field){m} = readNPY(filepath);

            catch
                % Fallback Python
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
end