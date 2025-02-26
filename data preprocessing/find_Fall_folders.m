function [TseriesFolders, TSeriesPaths, env_paths_all, true_env_paths, lastFolderNames] = find_Fall_folders(selectedFolders)
    % Initialiser la cellule pour stocker les chemins pour chaque type de dossier
    numFolders = length(selectedFolders);
    TseriesFolders = cell(numFolders, 4);  % Stocker les chemins Gcamp, Red, Blue, Green
    TSeriesPaths = cell(numFolders, 4);   % Stocker les chemins pour chaque type de dossier
    true_env_paths = {};  % Initialiser la cellule pour les chemins d'environnement
    lastFolderNames = cell(numFolders, 4); % Cellule pour stocker les noms des derniers dossiers

    % Boucler à travers chaque dossier sélectionné
    for idx = 1:numFolders
        selectedFolder = selectedFolders{idx};
        
        % Vérifier si le dossier existe
        if ~isfolder(selectedFolder)
            disp(['Warning: Folder does not exist: ', selectedFolder]);
            continue;  % Passer au dossier suivant
        end
        
        % Vérifier les dossiers 'TSeries' dans le répertoire sélectionné
        TSeriesFoldersList = dir(fullfile(selectedFolder, 'TSeries*'));
        
        % Gérer les cas où aucun dossier 'TSeries' n'est trouvé
        if isempty(TSeriesFoldersList)
            disp(['No TSeries folders found in folder: ', selectedFolder, '. Skipping.']);
            continue;  % Passer au dossier suivant
        end
        
        % Initialiser un tableau cellulaire pour les chemins TSeries (Gcamp, Red, Blue, Green)
        TSeriesPathsTemp = {[], [], [], []};  % [Gcamp, Red, Blue, Green]
        labels = {'Gcamp', 'Red', 'Blue', 'Green'};
        
        % Stocker les correspondances potentielles
        foundFolders = {[], [], [], []}; % [Gcamp, Red, Blue, Green]
        
        % Parcourir les dossiers trouvés
        for i = 1:length(TSeriesFoldersList)
            folderName = TSeriesFoldersList(i).name;
            fullPath = fullfile(selectedFolder, folderName);
            
            matched = false; % Indicateur pour voir si le dossier correspond à un label
            
            % Parcourir les labels et associer les dossiers
            for k = 1:length(labels)
                if contains(lower(folderName), lower(labels{k}))
                    foundFolders{k} = [foundFolders{k}; {fullPath}];
                    matched = true; % Marquer comme trouvé
                end
            end
            
            % Si aucun label ne correspond, classer dans Gcamp (index 1)
            if ~matched
                foundFolders{1} = [foundFolders{1}; {fullPath}];
            end
        end

        % Sélectionner un seul dossier par catégorie
        for k = 1:length(labels)
            if isscalar(foundFolders{k})
                TSeriesPathsTemp{k} = foundFolders{k}{1};
            elseif length(foundFolders{k}) > 1
                % Extraire le dernier dossier de chaque chemin
                [~, lastFolders] = cellfun(@(x) fileparts(x), foundFolders{k}, 'UniformOutput', false);
                
                % Extraire uniquement le nom du dernier dossier (pas tout le chemin)
                lastFolderNamesList = cellfun(@(x) strrep(x, filesep, ''), lastFolders, 'UniformOutput', false);
                
                % Afficher uniquement les derniers dossiers
                choice = listdlg('ListString', lastFolderNamesList, 'SelectionMode', 'single', ...
                                 'PromptString', ['Select the ', labels{k}, ' folder:']);
                if ~isempty(choice)
                    TSeriesPathsTemp{k} = foundFolders{k}{choice};
                end
            end
        end

        % Mettre à jour TSeriesPaths avec les chemins correspondants
        TSeriesPaths(idx, :) = TSeriesPathsTemp;  % Mettre à jour la cellule pour chaque dossier

        % Sauvegarder les noms des derniers dossiers pour chaque type
        for k = 1:length(TSeriesPathsTemp)
            if ~isempty(TSeriesPathsTemp{k})
                [~, lastFolderName] = fileparts(TSeriesPathsTemp{k});
                lastFolderNames{idx, k} = lastFolderName;
            else
                lastFolderNames{idx, k} = [];  % Si le chemin est vide, mettre []
            end
        end
        
        % Vérifier et organiser les fichiers dans le dossier 'Blue'
        if ~isempty(TSeriesPaths{idx, 3})  % Blue folder
            blueFolder = fullfile(TSeriesPaths{idx, 3}, 'Blue');
            greenFolder = fullfile(TSeriesPaths{idx, 3}, 'Green');
            
            if ~exist(blueFolder, 'dir')
                mkdir(blueFolder);
                tiffFiles = dir(fullfile(TSeriesPaths{idx, 3}, '*Ch3*.tif'));
                for j = 1:length(tiffFiles)
                    movefile(fullfile(TSeriesPaths{idx, 3}, tiffFiles(j).name), fullfile(blueFolder, tiffFiles(j).name));
                end
            end
            
            if ~exist(greenFolder, 'dir')
                mkdir(greenFolder);
                tiffFiles = dir(fullfile(TSeriesPaths{idx, 3}, '*Ch2*.tif'));
                for j = 1:length(tiffFiles)
                    movefile(fullfile(TSeriesPaths{idx, 3}, tiffFiles(j).name), fullfile(greenFolder, tiffFiles(j).name));
                end
            end
            
            % Sauvegarder les chemins des dossiers Blue et Green
            TSeriesPaths{idx, 3} = blueFolder;
            TSeriesPaths{idx, 4} = greenFolder;
        end

        % Traiter le fichier .env uniquement pour TSeriesPathGcamp
        if ~isempty(TSeriesPaths{idx, 1})
            [env_paths_all, env_path] = processEnvFile(TSeriesPaths{idx, 1});
        else
            disp('No GCaMP TSeries found, skipping .env processing.');
            env_path = '';  % Si aucun fichier .env trouvé
        end
        
        % Traiter suite2p et la sélection des dossiers 'plane' pour tous les types de TSeries
        dataFolders = {[], [], [], []};  % Correspond à Gcamp, Red, Blue, Green
        
        % Boucler à travers chaque chemin TSeries et traiter
        for j = 1:4  % Gcamp, Red, Blue, Green
            currentPath = TSeriesPaths{idx, j};
            
            if ~isempty(currentPath)
                dataFolder = process_TSeries(currentPath);
            
                % Vérifier que dataFolder n'est pas [], et ajouter le dossier correspondant
                if ~isnan(dataFolder)
                    dataFolders{j} = dataFolder;
                end
            end
        end

        % Ajouter les résultats de chaque dossier dans TseriesFolders
        TseriesFolders{idx, 1} = dataFolders{1};  % Gcamp
        TseriesFolders{idx, 2} = dataFolders{2};  % Red
        TseriesFolders{idx, 3} = dataFolders{3};  % Blue
        TseriesFolders{idx, 4} = dataFolders{4};  % Green

        % Traiter Fall.mat **SEULEMENT** pour TSeriesPathGcamp
        if ~isempty(dataFolders{1}) && ~any(isnan(dataFolders{1}))
            file_path = fullfile(dataFolders{1}, 'Fall.mat');
            FallMatPaths = {};  % Initialize the output variable
            
            if exist(file_path, 'file') == 2
                FallMatPaths{end+1} = file_path;  % Add the path to Fall.mat
                true_env_paths{end+1} = env_path;  % Add the corresponding env_path
            else
                disp(['Error: No Fall.mat found in folder: ', dataFolders{1}]);
            end

            % Mettre à jour TseriesFolders avec le chemin de Fall.mat
            TseriesFolders{idx, 1} = FallMatPaths;  % Store Fall.mat path in the output
        end
    end
end



% Function to process the .env file for GCaMP folder
function [env_paths_all, env_path] = processEnvFile(TSeriesPathGcamp)
    % Recherche des fichiers .env dans le dossier GCaMP
    env_file = dir(fullfile(TSeriesPathGcamp, '*.env'));
    
    % Initialisation du tableau pour stocker les chemins .env
    env_paths_all = {};  
    
    % Si un fichier .env est trouvé
    if ~isempty(env_file)
        % Prendre le chemin du premier fichier .env trouvé
        env_path = fullfile(TSeriesPathGcamp, env_file(1).name);
        % Ajouter le chemin au tableau des chemins .env
        env_paths_all{end+1} = env_path;
    else
        % Avertir si aucun fichier .env n'est trouvé
        disp(['Warning: No .env file found in GCaMP folder: ', TSeriesPathGcamp]);
        % Assigner une chaîne vide si aucun fichier .env trouvé
        env_path = '';  
        % Ajouter une entrée vide dans le tableau des chemins .env
        env_paths_all{end+1} = '';  
    end
end

% Function to process each identified TSeries path (for suite2p and plane* selection)
function dataFolder = process_TSeries(TSeriesPath)
    suite2pFolder = fullfile(TSeriesPath, 'suite2p');
    if ~isfolder(suite2pFolder)
        disp(['Error: No ''suite2p'' folder found in ', TSeriesPath, '. Skipping processing.']);
        dataFolder = [];  % Valeur par défaut si suite2p n'est pas trouvé
        return
    end
    
    % List 'plane' folders in suite2pFolder
    planeFolders = dir(fullfile(suite2pFolder, 'plane*'));
    
    if isempty(planeFolders)
        disp(['Error: No ''plane'' folder found in ', suite2pFolder, '. Skipping processing.']);
        dataFolder = [];  % Valeur par défaut si aucun dossier 'plane' n'est trouvé
        return;  % Skip to the next iteration if no plane folders are found
    end
    
    if isscalar(planeFolders) && planeFolders(1).isdir
        % If only one 'plane' folder exists, select it automatically
        dataFolder = fullfile(suite2pFolder, planeFolders(1).name);
    else
        % If multiple plane folders exist, ask the user to select one
        dataFolder = uigetdir(suite2pFolder, 'Select a plane folder');
        if dataFolder == 0
            disp(['User clicked Cancel for folder: ', TSeriesPath]);
            dataFolder = [];  % Valeur par défaut si l'utilisateur annule la sélection
            return;
        end
    end
end