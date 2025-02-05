function [TseriesFolders, env_paths_all, true_env_paths] = find_Fall_folders(selectedFolders)
    % Initialiser la cellule pour stocker les chemins pour chaque type de dossier
    numFolders = length(selectedFolders);
    TseriesFolders = cell(numFolders, 4); 
    true_env_paths = {};  % Initialiser la cellule pour les chemins d'environnement

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
            continue;  % Passer au dossier suivant si aucun dossier 'TSeries' trouvé
        end
        
        % Initialiser un tableau cellulaire pour les chemins TSeries (Gcamp, Red, Blue)
        TSeriesPaths = {[], [], [], []};  % [Gcamp, Red, Blue, Green]

        % Traiter chaque dossier TSeries
        for i = 1:length(TSeriesFolders)
            folderName = TSeriesFolders(i).name;
            fullPath = fullfile(selectedFolder, folderName);
            
            % Classer les dossiers TSeries par leur nom
            if contains(lower(folderName), 'gcamp')
                TSeriesPaths{1} = fullPath;  % Gcamp
            end
            if contains(lower(folderName), 'red')
                TSeriesPaths{2} = fullPath;  % Red
            end
            if contains(lower(folderName), 'blue')
                % Définition des chemins des sous-dossiers
                blueFolder = fullfile(fullPath, 'Blue');
                greenFolder = fullfile(fullPath, 'Green');
        
                % Vérifier et créer le dossier "Blue" si nécessaire
                if ~exist(blueFolder, 'dir')
                    mkdir(blueFolder);
                    
                    % Lister les fichiers .tiff contenant "Ch3" dans fullPath
                    tiffFiles = dir(fullfile(fullPath, '*Ch3*.tif'));
                    
                    % Déplacer les fichiers trouvés dans le sous-dossier "Blue"
                    for j = 1:length(tiffFiles)
                        oldFilePath = fullfile(fullPath, tiffFiles(j).name);
                        newFilePath = fullfile(blueFolder, tiffFiles(j).name);
                        movefile(oldFilePath, newFilePath);
                    end
                end
                
                % Vérifier et créer le dossier "Green" si nécessaire
                if ~exist(greenFolder, 'dir')
                    mkdir(greenFolder);
                    
                    % Lister les fichiers .tiff contenant "Ch2" dans fullPath
                    tiffFiles = dir(fullfile(fullPath, '*Ch2*.tif'));
                    
                    % Déplacer les fichiers trouvés dans le sous-dossier "Green"
                    for j = 1:length(tiffFiles)
                        oldFilePath = fullfile(fullPath, tiffFiles(j).name);
                        newFilePath = fullfile(greenFolder, tiffFiles(j).name);
                        movefile(oldFilePath, newFilePath);
                    end
                end
                
                % Sauvegarder les chemins des dossiers "Blue" et "Green"
                TSeriesPaths{3} = blueFolder;
                TSeriesPaths{4} = greenFolder;
            end
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
        TseriesFolders{idx, 3} = dataFolders{4};  % Green

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