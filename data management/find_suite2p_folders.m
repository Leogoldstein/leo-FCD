function [suite2p_folders, TSeriesPaths, xml_paths_all, ...
    true_xml_paths, lastFolderNames, Fallmat_paths] = ...
    find_suite2p_folders(selectedFolders)

    labels = {'Gcamp', 'Red', 'Blue', 'Green'};

    suite2p_folders = cell(0,4);
    TSeriesPaths    = cell(0,4);
    Fallmat_paths   = cell(0,4);

    true_xml_paths  = cell(0,1);
    lastFolderNames = cell(0,4);
    xml_paths_all   = cell(0,1);

    output_idx = 0;

    for idx = 1:numel(selectedFolders)

        selectedFolder = selectedFolders{idx};

        if ~isfolder(selectedFolder)

            warning('Folder does not exist: %s', ...
                selectedFolder);

            continue;
        end

        TSeriesFoldersList = dir( ...
            fullfile(selectedFolder, 'TSeries*'));

        TSeriesFoldersList = ...
            TSeriesFoldersList([TSeriesFoldersList.isdir]);

        if isempty(TSeriesFoldersList)

            fprintf('No TSeries folders found in: %s\n', ...
                selectedFolder);

            continue;
        end

        % ==========================================================
        % Identifier tous les TSeries GCaMP
        % ==========================================================
        gcamp_paths = {};

        all_paths = cell(numel(TSeriesFoldersList),1);

        for i = 1:numel(TSeriesFoldersList)

            folderName = TSeriesFoldersList(i).name;

            fullPath = fullfile( ...
                selectedFolder, ...
                folderName);

            all_paths{i} = fullPath;

            if contains(lower(folderName), 'gcamp')

                gcamp_paths{end+1,1} = fullPath;
            end
        end

        if isempty(gcamp_paths)

            warning('No GCaMP TSeries found in: %s', ...
                selectedFolder);

            continue;
        end
        
        % ==========================================================
        % Sélection manuelle si plusieurs TSeries GCaMP existent
        % ==========================================================
        if numel(gcamp_paths) > 1
        
            fprintf('\n');
            fprintf('Plusieurs TSeries GCaMP trouvés dans :\n%s\n', ...
                selectedFolder);
        
            for ii = 1:numel(gcamp_paths)
                fprintf('    %d) %s\n', ii, gcamp_paths{ii});
            end
        
            selected_gcamp_path = select_one_gcamp_tseries( ...
                selectedFolder, gcamp_paths);
        
            if isempty(selected_gcamp_path)
        
                fprintf([ ...
                    'Aucun TSeries GCaMP sélectionné pour :\n' ...
                    '%s\n'], selectedFolder);
        
                continue;
            end
        
            % Ne conserver que le TSeries choisi par l'utilisateur
            gcamp_paths = {selected_gcamp_path};
        end

        % ==========================================================
        % UNE LIGNE PAR TSERIES GCAMP
        % ==========================================================
        for g = 1:numel(gcamp_paths)

            output_idx = output_idx + 1;

            gcamp_path = gcamp_paths{g};

            TSeriesPaths{output_idx,1} = gcamp_path;

            % ======================================================
            % Numéro final du GCaMP
            % ======================================================
            [~, gcamp_name] = fileparts(gcamp_path);

            gcamp_num = regexp( ...
                gcamp_name, ...
                '-(\d+)$', ...
                'tokens', ...
                'once');

            if ~isempty(gcamp_num)
                gcamp_num = gcamp_num{1};
            else
                gcamp_num = '';
            end

            % ======================================================
            % Matcher les autres canaux
            % ======================================================
            for k = 2:numel(labels)

                matched_path = '';

                for i = 1:numel(all_paths)

                    this_path = all_paths{i};

                    [~, this_name] = fileparts(this_path);

                    this_name_lower = lower(this_name);

                    % ----------------------------------------------
                    % Vérifier le label
                    % ----------------------------------------------
                    if strcmpi(labels{k}, 'blue')

                        label_match = ...
                            ~isempty(regexp(this_name_lower, 'blue-\d+$', 'once')) && ...
                            ~contains(this_name_lower, 'blue-transfert') && ...
                            ~contains(this_name_lower, 'blue_transfert');
                    else

                        label_match = contains( ...
                            this_name_lower, ...
                            lower(labels{k}));
                    end

                    if ~label_match
                        continue;
                    end

                    % ----------------------------------------------
                    % Vérifier le suffixe recording
                    % ----------------------------------------------
                    this_num = regexp( ...
                        this_name, ...
                        '-(\d+)$', ...
                        'tokens', ...
                        'once');

                    if isempty(this_num)
                        continue;
                    end

                    if strcmp(this_num{1}, gcamp_num)

                        matched_path = this_path;
                        break;
                    end
                end

                TSeriesPaths{output_idx,k} = matched_path;
            end

            % ======================================================
            % Blue / Green sous-dossiers
            % ======================================================
            blue_path = TSeriesPaths{output_idx,3};

            if ~isempty(blue_path)

                blueFolder = fullfile(blue_path, 'Blue');
                greenFolder = fullfile(blue_path, 'Green');

                % BLUE
                if ~exist(blueFolder, 'dir')

                    tiffFiles = dir( ...
                        fullfile(blue_path, '*Ch3*.tif'));

                    if ~isempty(tiffFiles)

                        mkdir(blueFolder);

                        for j = 1:numel(tiffFiles)

                            movefile( ...
                                fullfile( ...
                                    blue_path, ...
                                    tiffFiles(j).name), ...
                                fullfile( ...
                                    blueFolder, ...
                                    tiffFiles(j).name));
                        end
                    end
                end

                blueFiles = dir( ...
                    fullfile(blueFolder, '*.tif'));

                if exist(blueFolder, 'dir') && ...
                        ~isempty(blueFiles)

                    TSeriesPaths{output_idx,3} = blueFolder;
                else
                    TSeriesPaths{output_idx,3} = '';
                end

                % GREEN
                if ~exist(greenFolder, 'dir')

                    tiffFiles = dir( ...
                        fullfile(blue_path, '*Ch2*.tif'));

                    if ~isempty(tiffFiles)

                        mkdir(greenFolder);

                        for j = 1:numel(tiffFiles)

                            movefile( ...
                                fullfile( ...
                                    blue_path, ...
                                    tiffFiles(j).name), ...
                                fullfile( ...
                                    greenFolder, ...
                                    tiffFiles(j).name));
                        end
                    end
                end

                greenFiles = dir( ...
                    fullfile(greenFolder, '*.tif'));

                if exist(greenFolder, 'dir') && ...
                        ~isempty(greenFiles)

                    TSeriesPaths{output_idx,4} = greenFolder;
                else
                    TSeriesPaths{output_idx,4} = '';
                end
            end

            % ======================================================
            % Noms TSeries
            % ======================================================
            for k = 1:4

                if ~isempty(TSeriesPaths{output_idx,k})

                    [~, lastFolderName] = fileparts( ...
                        TSeriesPaths{output_idx,k});

                    lastFolderNames{output_idx,k} = ...
                        lastFolderName;
                else

                    lastFolderNames{output_idx,k} = '';
                end
            end

            % ======================================================
            % XML
            % ======================================================
            [xml_list_tmp, xml_path] = ...
                processEnvFile(gcamp_path);

            xml_paths_all{output_idx,1} = xml_list_tmp;
            true_xml_paths{output_idx,1} = xml_path;

            % ======================================================
            % Suite2p / Fall.mat
            % ======================================================
            for j = 1:4

                currentPath = ...
                    TSeriesPaths{output_idx,j};

                if isempty(currentPath)

                    suite2p_folders{output_idx,j} = {};
                    Fallmat_paths{output_idx,j} = {};

                    continue;
                end

                planeFolders = process_TSeries(currentPath);

                if isempty(planeFolders)

                    fprintf([ ...
                        'TSeries conservé sans suite2p | ' ...
                        '%s | %s\n'], ...
                        labels{j}, ...
                        currentPath);

                    suite2p_folders{output_idx,j} = {};
                    Fallmat_paths{output_idx,j} = {};

                    continue;
                end

                currentFallPaths = {};
                currentSuite2pPaths = {};

                for p = 1:numel(planeFolders)

                    planePath = planeFolders{p};

                    fall_mat_path = ...
                        fullfile(planePath, 'Fall.mat');

                    ops_npy_path = ...
                        fullfile(planePath, 'ops.npy');

                    if exist(fall_mat_path, 'file') == 2

                        currentFallPaths{end+1} = ...
                            fall_mat_path; %#ok<AGROW>
                    end

                    if exist(ops_npy_path, 'file') == 2

                        currentSuite2pPaths{end+1} = ...
                            planePath; %#ok<AGROW>
                    end
                end

                Fallmat_paths{output_idx,j} = ...
                    currentFallPaths(:).';

                suite2p_folders{output_idx,j} = ...
                    currentSuite2pPaths(:).';
            end

            fprintf( ...
                'Recording added: %s\n', ...
                gcamp_path);
        end
    end
end

% --------- Sous-fonctions --------- %

function [xml_paths_all, xml_path] = processEnvFile(TSeriesPathGcamp)

    xml_paths_all = {};
    xml_path = '';

    % ------------------------------------------------------
    % 1) Recherche dans raw_data
    % ------------------------------------------------------
    xml_folder = fullfile(TSeriesPathGcamp, 'raw_data');

    if isfolder(xml_folder)
        xml_file = dir(fullfile(xml_folder, '*.xml'));

        if ~isempty(xml_file)
            xml_path = fullfile(xml_folder, xml_file(1).name);
        end
    end

    % ------------------------------------------------------
    % 2) Si absent, recherche directement dans le dossier TSeries
    % ------------------------------------------------------
    if isempty(xml_path)

        xml_file = dir(fullfile(TSeriesPathGcamp, '*.xml'));

        if ~isempty(xml_file)
            xml_path = fullfile(TSeriesPathGcamp, xml_file(1).name);
        end
    end

    % ------------------------------------------------------
    % 3) Sortie
    % ------------------------------------------------------
    if isempty(xml_path)
        warning('No XML file found in %s or %s.', ...
            fullfile(TSeriesPathGcamp,'raw_data'), TSeriesPathGcamp);

        xml_paths_all{1} = '';
    else
        xml_paths_all{1} = xml_path;
    end
end

function dataFolders = process_TSeries(TSeriesPath)
    suite2pOldFolder = fullfile(TSeriesPath, 'suite2p');
    suite2pNewFolder = fullfile(TSeriesPath, 'suite2p_new');

    if isfolder(suite2pNewFolder)
        suite2pFolder = suite2pNewFolder;
    else
        suite2pFolder = suite2pOldFolder;
    end

    if ~isfolder(suite2pFolder)
        dataFolders = {};
        return;
    end

    planeFolders = dir(fullfile(suite2pFolder, 'plane*'));
    planeFolders = planeFolders([planeFolders.isdir]);

    if isempty(planeFolders)
        disp(['Error: No ''plane'' folder found in ', suite2pFolder, '. Skipping processing.']);
        dataFolders = {};
        return;
    end

    dataFolders = cell(1, numel(planeFolders));
    for k = 1:numel(planeFolders)
        dataFolders{k} = fullfile(suite2pFolder, planeFolders(k).name);
    end
end

function selected_path = select_one_gcamp_tseries( ...
        parent_folder, available_gcamp_paths)

    selected_path = '';

    if isempty(available_gcamp_paths)
        return;
    end

    if numel(available_gcamp_paths) == 1
        selected_path = available_gcamp_paths{1};
        return;
    end

    while true

        chosen_folder = uigetdir( ...
            parent_folder, ...
            sprintf([ ...
                'Plusieurs TSeries GCaMP trouvés - ' ...
                'sélectionnez le TSeries à utiliser']));

        % Annulation par l'utilisateur
        if isequal(chosen_folder, 0)

            choice = questdlg( ...
                ['Aucun dossier sélectionné. ' ...
                 'Voulez-vous ignorer cette date ?'], ...
                'Sélection TSeries', ...
                'Ignorer la date', ...
                'Réessayer', ...
                'Ignorer la date');

            if strcmp(choice, 'Réessayer')
                continue;
            end

            selected_path = '';
            return;
        end

        chosen_folder_normalized = normalize_folder_path( ...
            chosen_folder);

        available_normalized = cellfun( ...
            @normalize_folder_path, ...
            available_gcamp_paths, ...
            'UniformOutput', false);

        matched_idx = find(strcmpi( ...
            available_normalized, ...
            chosen_folder_normalized), 1);

        if ~isempty(matched_idx)

            selected_path = ...
                available_gcamp_paths{matched_idx};

            fprintf('TSeries GCaMP sélectionné :\n%s\n', ...
                selected_path);

            return;
        end

        uiwait(warndlg( ...
            sprintf([ ...
                'Le dossier sélectionné ne correspond pas à un ' ...
                'TSeries GCaMP valide trouvé dans cette date.\n\n' ...
                'Dossier sélectionné :\n%s'], ...
                chosen_folder), ...
            'TSeries invalide', ...
            'modal'));
    end
end


function path_out = normalize_folder_path(path_in)

    if isempty(path_in)
        path_out = '';
        return;
    end

    path_out = char(string(path_in));
    path_out = strrep(path_out, '/', '\');

    while numel(path_out) > 3 && ...
            path_out(end) == '\'

        path_out(end) = [];
    end
end