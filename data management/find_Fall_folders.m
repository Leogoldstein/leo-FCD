function [TseriesFolders, TSeriesPaths, xml_paths_all, true_xml_paths, lastFolderNames] = find_Fall_folders(selectedFolders)
    numFolders = length(selectedFolders);
    
    % TseriesFolders :
    %   - colonne 1 (Gcamp) : cell array de Fall.mat (un par plan si présent)
    %   - colonnes 2–4 : cell array de dossiers plane* pour Red, Blue, Green
    TseriesFolders   = cell(numFolders, 4);  % Gcamp, Red, Blue, Green
    TSeriesPaths     = cell(numFolders, 4);  % Chemins TSeries par canal
    true_xml_paths   = cell(numFolders, 1);  % Store the xmlironment paths
    lastFolderNames  = cell(numFolders, 4);  % Nom du dernier dossier (par canal)
    xml_paths_all    = {};                   % rempli par processEnvFile (écrasé à chaque idx comme dans ton code)

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
        
        TSeriesPathsTemp = {'' '' '' ''};      % Gcamp, Red, Blue, Green
        labels           = {'Gcamp', 'Red', 'Blue', 'Green'};
        foundFolders     = {{} {} {} {}};      % chemins TSeries par label
        
        % --- Tri des TSeries* par label (Gcamp / Red / Blue / Green) ---
        for i = 1:length(TSeriesFoldersList)
            folderName = TSeriesFoldersList(i).name;
            fullPath   = fullfile(selectedFolder, folderName);
            matched    = false;
            
            for k = 1:length(labels)
                if contains(lower(folderName), lower(labels{k}))
                    foundFolders{k}{end+1} = fullPath;
                    matched = true;
                end
            end
            
            if ~matched
                % Si aucun label ne matche, on met par défaut dans Gcamp
                foundFolders{1}{end+1} = fullPath;
            end
        end
        
        % --- Sélection d’un TSeries par canal (ou via listdlg s’il y en a plusieurs) ---
        for k = 1:length(labels)
            if ~isempty(foundFolders{k})
                if isscalar(foundFolders{k})
                    TSeriesPathsTemp{k} = foundFolders{k}{1};  % Un seul dossier -> direct
                else
                    % Plusieurs dossiers -> choix utilisateur
                    [~, lastFolderNamesList] = cellfun(@(x) fileparts(x), foundFolders{k}, 'UniformOutput', false);
                    choice = listdlg('ListString', lastFolderNamesList, ...
                                     'SelectionMode', 'single', ...
                                     'PromptString', ['Select the ', labels{k}, ' folder:']);
                    if ~isempty(choice)
                        TSeriesPathsTemp{k} = foundFolders{k}{choice};
                    else
                        TSeriesPathsTemp{k} = '';  % Annulation -> vide
                    end
                end
            end
        end
        
        TSeriesPaths(idx, :) = TSeriesPathsTemp;
        
        % --- Nom du dernier dossier par canal ---
        for k = 1:length(TSeriesPathsTemp)
            if ~isempty(TSeriesPathsTemp{k})
                [~, lastFolderName] = fileparts(TSeriesPathsTemp{k});
                lastFolderNames{idx, k} = lastFolderName;
            else
                lastFolderNames{idx, k} = '';
            end
        end
        
        % --- Cas spécial canal "Blue"/"Green" regroupés dans TSeriesPaths{idx,3} ---
        if ~isempty(TSeriesPaths{idx, 3})
            blueFolder  = fullfile(TSeriesPaths{idx, 3}, 'Blue');
            greenFolder = fullfile(TSeriesPaths{idx, 3}, 'Green');
            
            % Blue (Ch3)
            if ~exist(blueFolder, 'dir')
                mkdir(blueFolder);
                tiffFiles = dir(fullfile(TSeriesPaths{idx, 3}, '*Ch3*.tif'));
                for j = 1:length(tiffFiles)
                    movefile(fullfile(TSeriesPaths{idx, 3}, tiffFiles(j).name), ...
                             fullfile(blueFolder, tiffFiles(j).name));
                end
            end
            
            % Green (Ch2)
            if ~exist(greenFolder, 'dir')
                tiffFiles = dir(fullfile(TSeriesPaths{idx, 3}, '*Ch2*.tif'));
                if ~isempty(tiffFiles)
                    mkdir(greenFolder);
                    for j = 1:length(tiffFiles)
                        movefile(fullfile(TSeriesPaths{idx, 3}, tiffFiles(j).name), ...
                                 fullfile(greenFolder, tiffFiles(j).name));
                    end
                else
                    disp("Green folder hasn't been created for this TSeries Blue folder")
                end
            end
            
            % On remplace le chemin "Blue/Green combiné" par les sous-dossiers
            TSeriesPaths{idx, 3} = blueFolder;
            TSeriesPaths{idx, 4} = greenFolder;
        end
        
        % --- XML dans le dossier Gcamp ---
        if ~isempty(TSeriesPaths{idx, 1})
            [xml_paths_all, xml_path] = processEnvFile(TSeriesPaths{idx, 1});
        else
            xml_path = '';
        end
        true_xml_paths{idx} = xml_path;
        
        % --- Récupération des dossiers plane* via suite2p pour chaque canal ---
        dataFolderss_channel = {{} {} {} {}};  % un cell array de plane* par canal
        for j = 1:4
            currentPath = TSeriesPaths{idx, j};
            if ~isempty(currentPath)
                dataFolders = process_TSeries(currentPath);  % <-- retourne maintenant tous les plane*
                if ~isempty(dataFolders)
                    dataFolderss_channel{j} = dataFolders;   % dataFolders est déjà une cell array
                end
            end
        end
        
        % On stocke d’abord cette info brute
        TseriesFolders(idx, :) = dataFolderss_channel;
        
        % --- Maintenant, pour Gcamp (canal 1), on cherche les Fall.mat dans chaque plan ---
        if ~isempty(dataFolderss_channel{1})
            planeFoldersGcamp = dataFolderss_channel{1};  % cell array de dossiers plane*
            fallPaths = {};
            
            for p = 1:numel(planeFoldersGcamp)
                planePath = planeFoldersGcamp{p};
                file_path = fullfile(planePath, 'Fall.mat');
                if exist(file_path, 'file') == 2
                    fallPaths{end+1} = file_path; %#ok<AGROW>
                else
                    disp(['Error: No Fall.mat found in folder: ', planePath]);
                end
            end
            
            if ~isempty(fallPaths)
                % On remplace la cellule Gcamp par la liste des Fall.mat
                TseriesFolders{idx, 1} = fallPaths;
            else
                TseriesFolders{idx, 1} = {};  % Aucun Fall.mat trouvé
            end
        else
            TseriesFolders{idx, 1} = {};      % Aucun dossier Gcamp
        end
    end
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
        disp(['Error: No ''suite2p'' folder found in ', TSeriesPath, '. Skipping processing.']);
        dataFolders = {};
        return;
    end
    
    planeFolders = dir(fullfile(suite2pFolder, 'plane*'));
    planeFolders = planeFolders([planeFolders.isdir]); % ne garder que les dossiers
    
    if isempty(planeFolders)
        disp(['Error: No ''plane'' folder found in ', suite2pFolder, '. Skipping processing.']);
        dataFolders = {};
        return;
    end
    
    % Retourner tous les dossiers plane*
    dataFolders = cell(1, numel(planeFolders));
    for k = 1:numel(planeFolders)
        dataFolders{k} = fullfile(suite2pFolder, planeFolders(k).name);
    end
end
