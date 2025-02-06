function [TseriesFolders, env_paths_all, true_env_paths, lastFolderNames] = find_Fall_folders(selectedFolders)
    % Initialiser la cellule pour stocker les chemins pour chaque type de dossier
    numFolders = length(selectedFolders);
    TseriesFolders = cell(numFolders, 4); 
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
        TSeriesFolders = dir(fullfile(selectedFolder, 'TSeries*'));
        
        % Gérer les cas où aucun dossier 'TSeries' n'est trouvé
        if isempty(TSeriesFolders)
            disp(['No TSeries folders found in folder: ', selectedFolder, '. Skipping.']);
            return;
        end
        
        % Initialiser un tableau cellulaire pour les chemins TSeries (Gcamp, Red, Blue, Green)
        TSeriesPaths = {[], [], [], []};  % [Gcamp, Red, Blue, Green]
        labels = {'Gcamp', 'Red', 'Blue'};
        
        % Stocker les correspondances potentielles
        foundFolders = {[], [], []};
        
        % Parcourir les dossiers trouvés
        for i = 1:length(TSeriesFolders)
            folderName = TSeriesFolders(i).name;
            fullPath = fullfile(selectedFolder, folderName);
            
            for k = 1:length(labels)
                if contains(lower(folderName), lower(labels{k}))
                    foundFolders{k} = [foundFolders{k}; {fullPath}];
                end
            end
        end
        
        % Sélectionner un seul dossier par catégorie
        for k = 1:length(labels)
            if isscalar(foundFolders{k})
                TSeriesPaths{k} = foundFolders{k}{1};
            elseif length(foundFolders{k}) > 1
                % Extraire le dernier dossier de chaque chemin
                [~, lastFolders] = cellfun(@(x) fileparts(x), foundFolders{k}, 'UniformOutput', false);
                
                % Extraire uniquement le nom du dernier dossier (pas tout le chemin)
                lastFolderNames = cellfun(@(x) strrep(x, filesep, ''), lastFolders, 'UniformOutput', false);
                
                % Afficher uniquement les derniers dossiers
                choice = listdlg('ListString', lastFolderNames, 'SelectionMode', 'single', ...
                                 'PromptString', ['Select the ', labels{k}, ' folder:']);
                if ~isempty(choice)
                    TSeriesPaths{k} = foundFolders{k}{choice};
                end
            end
        end

        % Récupérer le nom du dernier dossier pour chaque label et le stocker
        for k = 1:length(TSeriesPaths)
            if ~isempty(TSeriesPaths{k})  % Vérifier que TSeriesPaths{k} n'est pas vide
                [~, lastFolderName] = fileparts(TSeriesPaths{k});
                lastFolderNames{idx, k} = lastFolderName;  % Sauvegarder le nom du dernier dossier pour chaque label
            else
                lastFolderNames{idx, k} = NaN;  % Si le chemin est vide, mettre NaN
            end
        end
 
        % Vérifier et organiser les fichiers dans le dossier 'Blue'
        if ~isempty(TSeriesPaths{3})
            blueFolder = fullfile(TSeriesPaths{3}, 'Blue');
            greenFolder = fullfile(TSeriesPaths{3}, 'Green');
            
            if ~exist(blueFolder, 'dir')
                mkdir(blueFolder);
                tiffFiles = dir(fullfile(TSeriesPaths{3}, '*Ch3*.tif'));
                for j = 1:length(tiffFiles)
                    movefile(fullfile(TSeriesPaths{3}, tiffFiles(j).name), fullfile(blueFolder, tiffFiles(j).name));
                end
            end
            
            if ~exist(greenFolder, 'dir')
                mkdir(greenFolder);
                tiffFiles = dir(fullfile(TSeriesPaths{3}, '*Ch2*.tif'));
                for j = 1:length(tiffFiles)
                    movefile(fullfile(TSeriesPaths{3}, tiffFiles(j).name), fullfile(greenFolder, tiffFiles(j).name));
                end
            end
            
            % Sauvegarder les chemins des dossiers Blue et Green
            TSeriesPaths{3} = blueFolder;
            TSeriesPaths{4} = greenFolder;
        end

        % Traiter le fichier .env uniquement pour TSeriesPathGcamp
        if ~isempty(TSeriesPaths{1})
            [env_paths_all, env_path] = processEnvFile(TSeriesPaths{1});
        else
            disp('No GCaMP TSeries found, skipping .env processing.');
            env_path = '';  % Si aucun fichier .env trouvé
        end
        
        % Traiter suite2p et la sélection des dossiers 'plane' pour tous les types de TSeries
        dataFolders = {NaN, NaN, NaN, NaN};  % Correspond à Gcamp, Red, Blue, Green
        
        % Boucler à travers chaque chemin TSeries et traiter
        for j = 1:4  % Gcamp, Red, Blue, Green
            currentPath = TSeriesPaths{j};
            
            if ~isempty(currentPath)
                dataFolder = process_TSeries(currentPath);
            
                % Vérifier que dataFolder n'est pas NaN, et ajouter le dossier correspondant
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
        dataFolder = NaN;  % Valeur par défaut si suite2p n'est pas trouvé
        return
    end
    
    % List 'plane' folders in suite2pFolder
    planeFolders = dir(fullfile(suite2pFolder, 'plane*'));
    
    if isempty(planeFolders)
        disp(['Error: No ''plane'' folder found in ', suite2pFolder, '. Skipping processing.']);
        dataFolder = NaN;  % Valeur par défaut si aucun dossier 'plane' n'est trouvé
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
            dataFolder = NaN;  % Valeur par défaut si l'utilisateur annule la sélection
            return;
        end
    end
end