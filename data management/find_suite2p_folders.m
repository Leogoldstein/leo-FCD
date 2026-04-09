function [suite2p_folders, TSeriesPaths, xml_paths_all, true_xml_paths, lastFolderNames, Fallmat_paths] = find_suite2p_folders(selectedFolders)

    numFolders = numel(selectedFolders);

    % suite2p_folders :
    %   - colonne 1 (Gcamp) : cell array de dossiers plane* valides si ops.npy présent
    %   - colonnes 2–4 : idem pour Red, Blue, Green
    suite2p_folders = cell(numFolders, 4);

    % TSeriesPaths :
    %   - chemins des TSeries par canal
    TSeriesPaths = cell(numFolders, 4);

    % Fallmat_paths :
    %   - chemins vers Fall.mat si présent
    Fallmat_paths = cell(numFolders, 4);

    true_xml_paths  = cell(numFolders, 1);
    lastFolderNames = cell(numFolders, 4);
    xml_paths_all   = cell(numFolders, 1);

    labels = {'Gcamp', 'Red', 'Blue', 'Green'};

    for idx = 1:numFolders
        selectedFolder = selectedFolders{idx};

        if ~isfolder(selectedFolder)
            disp(['Warning: Folder does not exist: ', selectedFolder]);
            continue;
        end

        TSeriesFoldersList = dir(fullfile(selectedFolder, 'TSeries*'));
        if isempty(TSeriesFoldersList)
            disp(['No TSeries folders found in folder: ', selectedFolder, '. Skipping.']);
            continue;
        end

        TSeriesPathsTemp = repmat({''}, 1, numel(labels));
        foundFolders     = cell(1, numel(labels));
        [foundFolders{:}] = deal({});

        % ------------------------------------------------------------
        % Tri des TSeries* par label
        % ------------------------------------------------------------
        for i = 1:numel(TSeriesFoldersList)
            folderName = TSeriesFoldersList(i).name;
            fullPath   = fullfile(selectedFolder, folderName);
            matched    = false;

            folderNameLower = lower(folderName);

            for k = 1:numel(labels)
                labelLower = lower(labels{k});

                % Cas spécial pour éviter que blue_transfert rentre aussi dans blue
                if strcmpi(labelLower, 'blue')
                    tf = contains(folderNameLower, '-blue-') && ...
                         ~contains(folderNameLower, 'blue-transfert') && ...
                         ~contains(folderNameLower, 'blue_transfert');
                else
                    tf = contains(folderNameLower, labelLower);
                end

                if tf
                    foundFolders{k}{end+1} = fullPath;
                    matched = true;
                end
            end

            % Si rien ne matche, ne rien ajouter
            if ~matched
                continue;
            end
        end

        % ------------------------------------------------------------
        % 1) Sélection GCAMP d'abord
        % ------------------------------------------------------------
        gcamp_idx = find(strcmpi(labels, 'gcamp'), 1);

        if ~isempty(gcamp_idx) && ~isempty(foundFolders{gcamp_idx})
            if numel(foundFolders{gcamp_idx}) == 1
                TSeriesPathsTemp{gcamp_idx} = foundFolders{gcamp_idx}{1};
            else
                start_path    = selectedFolder;
                titleTxt      = 'Select TSeries gcamp folder';
                selected_path = uigetdir(start_path, titleTxt);

                if isequal(selected_path, 0)
                    TSeriesPathsTemp{gcamp_idx} = '';
                else
                    if ~contains(lower(selected_path), 'tseries')
                        warning('Le dossier choisi ne ressemble pas à un dossier TSeries: %s', selected_path);
                    end
                    TSeriesPathsTemp{gcamp_idx} = selected_path;
                end
            end
        end

        % ------------------------------------------------------------
        % 2) Sélection des autres canaux
        % ------------------------------------------------------------
        for k = 1:numel(labels)

            % déjà traité
            if k == gcamp_idx
                continue;
            end

            if isempty(foundFolders{k})
                continue;
            end

            % --------------------------------------------------------
            % Cas spécial BLUE
            % --------------------------------------------------------
            if strcmpi(labels{k}, 'blue')

                all_paths = foundFolders{k};

                % vrais blue uniquement
                is_blue = contains(lower(all_paths), '-blue-') & ...
                          ~contains(lower(all_paths), 'blue-transfert') & ...
                          ~contains(lower(all_paths), 'blue_transfert');

                blue_paths = all_paths(is_blue);

                % Si aucun vrai blue trouvé, on retombe sur les dossiers trouvés
                if isempty(blue_paths)
                    blue_paths = all_paths;
                end

                % Si gcamp est disponible, matcher le suffixe final
                if ~isempty(gcamp_idx) && ~isempty(TSeriesPathsTemp{gcamp_idx})
                    gcamp_path = TSeriesPathsTemp{gcamp_idx};
                    [~, gcamp_name] = fileparts(gcamp_path);
                    gcamp_num = regexp(gcamp_name, '-(\d+)$', 'tokens', 'once');

                    if ~isempty(gcamp_num)
                        gcamp_num = gcamp_num{1};

                        matched_blue = {};
                        for b = 1:numel(blue_paths)
                            [~, blue_name] = fileparts(blue_paths{b});
                            this_num = regexp(blue_name, '-(\d+)$', 'tokens', 'once');

                            if ~isempty(this_num) && strcmp(this_num{1}, gcamp_num)
                                matched_blue{end+1} = blue_paths{b}; %#ok<AGROW>
                            end
                        end

                        if numel(matched_blue) == 1
                            TSeriesPathsTemp{k} = matched_blue{1};
                            continue;
                        elseif numel(matched_blue) > 1
                            TSeriesPathsTemp{k} = matched_blue{1};
                            warning('Plusieurs dossiers blue matchent le numéro GCAMP (%s). Premier choisi: %s', ...
                                gcamp_num, matched_blue{1});
                            continue;
                        end
                    end
                end

                % Sinon, si un seul blue dispo, on le prend
                if numel(blue_paths) == 1
                    TSeriesPathsTemp{k} = blue_paths{1};
                    continue;
                end

                % Sinon sélection manuelle
                start_path    = selectedFolder;
                titleTxt      = sprintf('Select TSeries %s folder', labels{k});
                selected_path = uigetdir(start_path, titleTxt);

                if isequal(selected_path, 0)
                    TSeriesPathsTemp{k} = '';
                else
                    if ~contains(lower(selected_path), 'tseries')
                        warning('Le dossier choisi ne ressemble pas à un dossier TSeries: %s', selected_path);
                    end
                    TSeriesPathsTemp{k} = selected_path;
                end

                continue;
            end

            % --------------------------------------------------------
            % Cas normal
            % --------------------------------------------------------
            if numel(foundFolders{k}) == 1
                TSeriesPathsTemp{k} = foundFolders{k}{1};
            else
                start_path    = selectedFolder;
                titleTxt      = sprintf('Select TSeries %s folder', labels{k});
                selected_path = uigetdir(start_path, titleTxt);

                if isequal(selected_path, 0)
                    TSeriesPathsTemp{k} = '';
                else
                    if ~contains(lower(selected_path), 'tseries')
                        warning('Le dossier choisi ne ressemble pas à un dossier TSeries: %s', selected_path);
                    end
                    TSeriesPathsTemp{k} = selected_path;
                end
            end
        end

        % ------------------------------------------------------------
        % Cas spécial Blue/Green regroupés
        % ------------------------------------------------------------
        blue_idx  = find(strcmpi(labels, 'blue'), 1);
        green_idx = find(strcmpi(labels, 'green'), 1);

        if ~isempty(blue_idx) && ~isempty(TSeriesPathsTemp{blue_idx})

            baseFolder = TSeriesPathsTemp{blue_idx};

            blueFolder  = fullfile(baseFolder, 'Blue');
            greenFolder = fullfile(baseFolder, 'Green');

            % =======================
            % BLUE
            % =======================
            if ~exist(blueFolder, 'dir')
                tiffFiles = dir(fullfile(baseFolder, '*Ch3*.tif'));

                if ~isempty(tiffFiles)
                    mkdir(blueFolder);
                    for j = 1:numel(tiffFiles)
                        movefile(fullfile(baseFolder, tiffFiles(j).name), ...
                                 fullfile(blueFolder, tiffFiles(j).name));
                    end
                end
            end

            blueFiles = dir(fullfile(blueFolder, '*.tif'));
            if exist(blueFolder, 'dir') && ~isempty(blueFiles)
                TSeriesPathsTemp{blue_idx} = blueFolder;
            else
                TSeriesPathsTemp{blue_idx} = '';
            end

            % =======================
            % GREEN
            % =======================
            if ~isempty(green_idx)
                if ~exist(greenFolder, 'dir')
                    tiffFiles = dir(fullfile(baseFolder, '*Ch2*.tif'));

                    if ~isempty(tiffFiles)
                        mkdir(greenFolder);
                        for j = 1:numel(tiffFiles)
                            movefile(fullfile(baseFolder, tiffFiles(j).name), ...
                                     fullfile(greenFolder, tiffFiles(j).name));
                        end
                    else
                        disp('Green folder hasn''t been created for this TSeries Blue folder');
                    end
                end

                greenFiles = dir(fullfile(greenFolder, '*.tif'));
                if exist(greenFolder, 'dir') && ~isempty(greenFiles)
                    TSeriesPathsTemp{green_idx} = greenFolder;
                else
                    TSeriesPathsTemp{green_idx} = '';
                end
            end
        end

        % ------------------------------------------------------------
        % Récupération des dossiers plane* pour chaque canal
        % ------------------------------------------------------------
        planeFolders_by_channel = cell(1, 4);
        for j = 1:4
            currentPath = TSeriesPathsTemp{j};

            if ~isempty(currentPath)
                planeFolders = process_TSeries(currentPath);
                if ~isempty(planeFolders)
                    planeFolders_by_channel{j} = planeFolders;
                else
                    planeFolders_by_channel{j} = {};
                end
            else
                planeFolders_by_channel{j} = {};
            end
        end

        % ------------------------------------------------------------
        % Condition demandée :
        % si aucun dossier suite2p/plane* pour Gcamp => on ignore la ligne
        % ------------------------------------------------------------
        if isempty(planeFolders_by_channel{1})
            warning('Aucun dossier suite2p/plane* trouvé pour Gcamp dans %s. Dossier ignoré.', ...
                to_char_path(TSeriesPathsTemp{1}));
            continue;
        end

        % ------------------------------------------------------------
        % On remplit les sorties seulement si Gcamp est valide
        % ------------------------------------------------------------
        TSeriesPaths(idx, :) = TSeriesPathsTemp;

        % Nom du dernier dossier par canal
        for k = 1:numel(TSeriesPathsTemp)
            if ~isempty(TSeriesPathsTemp{k})
                [~, lastFolderName] = fileparts(TSeriesPathsTemp{k});
                lastFolderNames{idx, k} = lastFolderName;
            else
                lastFolderNames{idx, k} = '';
            end
        end

        % XML dans le dossier Gcamp
        if ~isempty(TSeriesPaths{idx, 1})
            [xml_list_tmp, xml_path] = processEnvFile(TSeriesPaths{idx, 1});
        else
            xml_list_tmp = {''};
            xml_path = '';
        end
        xml_paths_all{idx}  = xml_list_tmp;
        true_xml_paths{idx} = xml_path;

        % ------------------------------------------------------------
        % Analyse des plans
        % ------------------------------------------------------------
        for j = 1:4
            planeFolders = planeFolders_by_channel{j};

            currentFallPaths    = {};
            currentSuite2pPaths = {};

            if ~isempty(TSeriesPaths{idx, j}) && isempty(planeFolders)
                warning('TSeries existe mais aucun dossier suite2p/plane* pour %s (%s).', ...
                    labels{j}, to_char_path(TSeriesPaths{idx, j}));
                Fallmat_paths{idx, j} = {};
                suite2p_folders{idx, j} = {};
                continue;
            end

            for p = 1:numel(planeFolders)
                planePath = planeFolders{p};
                if isstring(planePath)
                    planePath = char(planePath);
                end

                fall_mat_path = fullfile(planePath, 'Fall.mat');
                ops_npy_path  = fullfile(planePath, 'ops.npy');

                if exist(fall_mat_path, 'file') == 2
                    currentFallPaths{end+1} = fall_mat_path; %#ok<AGROW>
                end

                if exist(ops_npy_path, 'file') == 2
                    currentSuite2pPaths{end+1} = planePath; %#ok<AGROW>
                    fprintf('Info: using suite2p folder (ops.npy found): %s\n', planePath);
                end

                if exist(fall_mat_path, 'file') ~= 2 && exist(ops_npy_path, 'file') ~= 2
                    warning('No Fall.mat or ops.npy found in folder: %s', planePath);
                end
            end

            Fallmat_paths{idx, j}   = currentFallPaths(:).';
            suite2p_folders{idx, j} = currentSuite2pPaths(:).';

            if ~isempty(TSeriesPaths{idx, j}) && isempty(currentFallPaths) && isempty(currentSuite2pPaths)
                warning('TSeries existe mais aucun Fall.mat/ops.npy trouvé pour %s : %s', ...
                    labels{j}, to_char_path(TSeriesPaths{idx, j}));
            end
        end
    end

    % ============================================================
    % Filtrage final : garder uniquement les lignes valides Gcamp
    % ============================================================
    valid_rows = ~cellfun(@isempty, TSeriesPaths(:, 1));

    suite2p_folders = suite2p_folders(valid_rows, :);
    TSeriesPaths    = TSeriesPaths(valid_rows, :);
    xml_paths_all   = xml_paths_all(valid_rows, :);
    true_xml_paths  = true_xml_paths(valid_rows, :);
    lastFolderNames = lastFolderNames(valid_rows, :);
    Fallmat_paths   = Fallmat_paths(valid_rows, :);
end


% --------- Sous-fonctions --------- %

function [xml_paths_all, xml_path] = processEnvFile(TSeriesPathGcamp)
    xml_file = dir(fullfile(TSeriesPathGcamp, '*.xml'));
    xml_paths_all = {};

    if ~isempty(xml_file)
        xml_path = fullfile(TSeriesPathGcamp, xml_file(1).name);
        xml_paths_all{end+1} = xml_path;
    else
        disp(['Warning: No .xml file found in GCaMP folder: ', TSeriesPathGcamp]);
        xml_path = '';
        xml_paths_all{end+1} = '';
    end
end

function dataFolders = process_TSeries(TSeriesPath)
    suite2pFolder = fullfile(TSeriesPath, 'suite2p');
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

function s = to_char_path(x)
% Convertit x (char/string/cell) en char pour affichage warnings
    if isempty(x)
        s = '';
        return;
    end
    if iscell(x)
        x = x{1};
    end
    if isstring(x)
        x = x(1);
    end
    s = char(x);
end