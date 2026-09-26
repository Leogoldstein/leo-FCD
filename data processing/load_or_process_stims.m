function data = load_or_process_stims( ...
        date_folders, ...
        TSeries_folders, ...
        numAcquisitions, ...
        data)

% LOAD_OR_PROCESS_STIMS
%
% Charge les donnees de stimulation pour chaque recording.
%
% IMPORTANT :
%   l'association recording <-> TSeries est deja geree en amont dans
%   folder_selection / update_selected_groups_in_place.
%
% Ici, l'indice m est donc considere comme fiable :
%
%   date_folders{m}
%   TSeries_folders{m}
%   data.stim.<field>{m}
%
% Cette fonction ne fait AUCUN realignement supplementaire.

    if nargin < 4 || isempty(data)
        data = struct();
    end


    stim_fields = { ...
        'stim_frames_log_group', ...
        'stim_protocol_group', ...
        'stim_reply_log_group', ...
        'stim_times_group', ...
        'stim_values_log_group'};

    data = ...
        init_stim_data_struct_if_needed( ...
            data, ...
            numAcquisitions, ...
            stim_fields);

    fprintf('\n');
    fprintf('============================================================\n');
    fprintf('STIMULATION PROCESSING\n');
    fprintf('Acquisitions: %d\n',numAcquisitions);
    fprintf('============================================================\n');

    for m = 1:numAcquisitions

        date_folder_m = date_folders{m};
        TSeries_folder_m = TSeries_folders{m};

        [~,date_name] = fileparts(date_folder_m);
        [~,tseries_name] = fileparts(TSeries_folder_m);

        fprintf('\n------------------------------------------------------------\n');
        fprintf('Stimulation acquisition %d/%d\n',m,numAcquisitions);
        fprintf('Date   : %s\n',date_name);
        fprintf('TSeries: %s\n',tseries_name);
        fprintf('------------------------------------------------------------\n');

        % =========================================================
        % Donnees deja completes
        % =========================================================
        if stim_already_complete(data,m)

            fprintf('Status: complete in memory -> no reload.\n');
            continue;
        end

        % =========================================================
        % Dossier stim
        % =========================================================
        stim_src = fullfile(date_folder_m,'stim');
        stim_dst = fullfile(TSeries_folder_m,'stim');

        if isfolder(stim_src) && ~isfolder(stim_dst)

            try
                movefile(stim_src,stim_dst);
                fprintf('Stim folder moved into TSeries.\n');

            catch ME
                warning( ...
                    'load_or_process_stims:StimMoveFailed', ...
                    '%s | impossible de deplacer le dossier stim : %s', ...
                    tseries_name, ...
                    ME.message);
            end
        end

        if ~isfolder(stim_dst)

            fprintf('Stim folder: not found.\n');
            continue;
        end

        % =========================================================
        % Fichiers attendus
        % =========================================================
        files = struct( ...
            'stim_frames_log_group', ...
                fullfile(stim_dst,'stim_frames_log.npy'), ...
            'stim_protocol_group', ...
                fullfile(stim_dst,'stim_protocol.npy'), ...
            'stim_reply_log_group', ...
                fullfile(stim_dst,'stim_reply_log.npy'), ...
            'stim_times_group', ...
                fullfile(stim_dst,'stim_times.npy'), ...
            'stim_values_log_group', ...
                fullfile(stim_dst,'stim_values_log.npy'));

        file_fields = fieldnames(files);

        numLoaded = 0;
        numExisting = 0;
        numMissing = 0;
        numFailed = 0;

        % =========================================================
        % Chargement selectif
        % =========================================================
        for i = 1:numel(file_fields)

            fieldName = file_fields{i};

            if stim_field_has_value(data,fieldName,m)
                numExisting = numExisting + 1;
                continue;
            end

            filepath = files.(fieldName);

            if ~isfile(filepath)

                data.stim.(fieldName){m} = [];
                numMissing = numMissing + 1;
                continue;
            end

            try

                data.stim.(fieldName){m} = ...
                    readNPY(filepath);

                numLoaded = numLoaded + 1;

            catch ME

                data.stim.(fieldName){m} = [];
                numFailed = numFailed + 1;

                warning( ...
                    'load_or_process_stims:StimReadFailed', ...
                    '%s | impossible de lire %s : %s', ...
                    tseries_name, ...
                    filepath, ...
                    ME.message);
            end
        end

        % =========================================================
        % Resume
        % =========================================================
        fprintf('Loaded now       : %d\n',numLoaded);
        fprintf('Already in memory: %d\n',numExisting);
        fprintf('Missing files    : %d\n',numMissing);
        fprintf('Failed files     : %d\n',numFailed);

        if stim_already_complete(data,m)
            fprintf('Final status     : complete.\n');
        elseif numLoaded + numExisting > 0
            fprintf('Final status     : partially available.\n');
        else
            fprintf('Final status     : no stimulation data.\n');
        end
    end

    fprintf('\n');
    fprintf('============================================================\n');
    fprintf('STIMULATION PROCESSING COMPLETED\n');
    fprintf('Acquisitions: %d\n',numAcquisitions);
    fprintf('============================================================\n');
end


% =====================================================================
% Initialisation
% =====================================================================

function data = init_stim_data_struct_if_needed( ...
        data, numAcquisitions, stim_fields)

    if ~isfield(data,'stim') || ...
            ~isstruct(data.stim)

        data.stim = struct();
    end

    for i = 1:numel(stim_fields)

        fieldName = stim_fields{i};

        if ~isfield(data.stim,fieldName) || ...
                ~iscell(data.stim.(fieldName))

            data.stim.(fieldName) = ...
                cell(numAcquisitions,1);

        elseif numel(data.stim.(fieldName)) < numAcquisitions

            old_values = data.stim.(fieldName);
            new_values = cell(numAcquisitions,1);
            new_values(1:numel(old_values)) = old_values(:);
            data.stim.(fieldName) = new_values;
        end
    end
end


% =====================================================================
% Etat des champs
% =====================================================================

function tf = stim_field_has_value(data,fieldName,m)

    tf = ...
        isfield(data,'stim') && ...
        isstruct(data.stim) && ...
        isfield(data.stim,fieldName) && ...
        iscell(data.stim.(fieldName)) && ...
        numel(data.stim.(fieldName)) >= m && ...
        ~isempty(data.stim.(fieldName){m});
end


function tf = stim_already_complete(data,m)

    tf = ...
        stim_field_has_value(data,'stim_frames_log_group',m) && ...
        stim_field_has_value(data,'stim_protocol_group',m) && ...
        stim_field_has_value(data,'stim_reply_log_group',m) && ...
        stim_field_has_value(data,'stim_times_group',m) && ...
        stim_field_has_value(data,'stim_values_log_group',m);
end
