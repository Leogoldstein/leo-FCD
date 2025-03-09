function [animal_date_list, env_paths_all, selected_groups] = pipeline_for_data_preprocessing()
    % pipeline_for_data_preprocessing : Fonction pour traiter les données
    % selon le choix de l'utilisateur.
    %
    % Choix possibles :
    % 1 : JM (Jure's data avec fichiers .npy)
    % 2 : FCD (données Fall.mat pour FCD)
    % 3 : CTRL (données Fall.mat pour CTRL)
    %
    % Sorties :
    % - gcampdataFolders : Dossiers des données valides
    % - animal_date_list : Liste des animaux et dates
    % - F : Données brutes
    % - DF : Données dF/F
    % - ops : Paramètres d'opérations
    % - stat : Données statistiques
    % - iscell : Indicateurs de cellules

    % Définir les chemins de base
    jm_folder = '\\10.51.106.5\data\Data\jm\'; % Dossiers pour JM
    destinationFolder = 'D:/imaging/jm/'; % Destination des fichiers JM
    fcd_folder = 'D:\imaging\FCD\'; % Dossiers pour FCD
    ctrl_folder = 'D:\imaging\CTRL'; % Dossiers pour CTRL
    PathSave = 'D:\after_processing';

    % Demander à l'utilisateur de choisir un dossier
    disp('Veuillez choisir un dossier à traiter :');
    disp('1 : JM (Jure''s data)');
    disp('2 : FCD (Fall.mat data)');
    disp('3 : CTRL (Fall.mat data)');
    choice = input('Entrez le numéro de votre choix (1, 2 ou 3) : ');

    % Traitement selon le choix
    switch choice
        case 1
            % Traitement JM (Jure's data)
            disp('Traitement des données JM...');
            dataFolders = select_folders(jm_folder);
            [true_env_paths, TSeriesPaths, env_paths_all, statPaths, FPaths, iscellPaths, opsPaths, spksPaths] = find_npy_folders(dataFolders);
            [newFPaths, newStatPaths, newIscellPaths, newOpsPaths, newSpksPaths, gcampdataFolders] = preprocess_npy_files(FPaths, statPaths, iscellPaths, opsPaths, spksPaths, destinationFolder);
            disp('Traitement JM terminé.');

        case 2
            % Traitement FCD
            disp('Traitement des données FCD...');
            initial_folder = fcd_folder; % Point de départ pour la sélection
            dataFolders = select_folders(initial_folder);
            dataFolders = organize_data_by_animal(dataFolders);
            [TseriesFolders, TSeriesPaths, env_paths_all, true_env_paths, lastFolderNames] = find_Fall_folders(dataFolders);
            gcampdataFolders = cellfun(@string, TseriesFolders(:, 1), 'UniformOutput', false);
            disp('Traitement FCD terminé.');

        case 3
            % Traitement CTRL
            disp('Traitement des données CTRL...');
            initial_folder = ctrl_folder; % Point de départ pour la sélection
            dataFolders = select_folders(initial_folder);
            dataFolders = organize_data_by_animal(dataFolders);
            [TseriesFolders, TSeriesPaths, env_paths_all, true_env_paths, lastFolderNames] = find_Fall_folders(dataFolders);
            gcampdataFolders = cellfun(@string, TseriesFolders(:, 1), 'UniformOutput', false);
            disp('Traitement CTRL terminé.');

        otherwise
            % Option invalide
            error('Choix invalide. Veuillez relancer la fonction et choisir 1, 2 ou 3.');
    end
    
    % Vérifier si gcampdataFolders existe et n'est pas vide
    if ~isempty(gcampdataFolders)
        % Créer une liste des animaux et des dates
        animal_date_list = create_animal_date_list(gcampdataFolders, PathSave);
        disp(animal_date_list)
    
        % Ensure all parts are strings, replace empty values with empty strings
        type_part = animal_date_list(:, 1);
        animal_part = cellfun(@(x) char(x), animal_date_list(:, 3), 'UniformOutput', false);
        mTor_part = cellfun(@(x) char(x), animal_date_list(:, 2), 'UniformOutput', false);
        date_part = animal_date_list(:, 4);
        age_part = animal_date_list(:, 5);
        
        % Replace empty arrays with empty strings
        mTor_part(cellfun(@isempty, mTor_part)) = {''};  % Replace empty mTor entries with empty strings
        animal_part(cellfun(@isempty, animal_part)) = {''};  % Ensure animal_part is not empty
    
        % Determine unique groups for analysis
        if isempty(mTor_part) || all(cellfun(@isempty, mTor_part))
            % Group by animal only
            animal_group = animal_part; 
            unique_animal_group = unique(animal_part);
        else
            % Group by animal and mTor
            % Concatenate animal and mTor into a single string for unique grouping
            animal_group = strcat(animal_part, '_', mTor_part);
            unique_animal_group = unique(animal_group);
        end
    
        % Initialize save paths and selection storage
        ani_paths = cell(length(unique_animal_group), 1);
        selected_groups = struct();
    
        for k = 1:length(unique_animal_group)
            current_animal_group = unique_animal_group{k};
            if isempty(mTor_part) || all(cellfun(@isempty, mTor_part))
                % When mTor_part is empty or all values are empty, group by animal only
                ani_path = fullfile(PathSave, type_part{1}, current_animal_group);
            else
                % Split the current animal group into animal and mTor
                parts = strsplit(current_animal_group, '_');
                current_animal = parts{1};
                current_mTor = parts{2};
    
                % Construct path using both animal and mTor
                ani_path = fullfile(PathSave, type_part{1}, current_mTor, current_animal);
            end
            % Create directory if it does not exist
            if ~exist(ani_path, 'dir')
                mkdir(ani_path);
                disp(['Created folder: ', ani_path]);
            end
    
            % Save the path
            ani_paths{k} = ani_path;
    
            % Get indices of dates for the current animal group
            date_indices = find(strcmp(animal_group, current_animal_group));
    
            % Save the selected dates and folders for this group
            selected_groups(k).animal_group = current_animal_group;
            selected_groups(k).animal_type = unique(type_part(date_indices)); % Save unique types
            selected_groups(k).dates = date_part(date_indices);
            selected_groups(k).pathTSeries = TSeriesPaths(date_indices, :);
            selected_groups(k).folders = TseriesFolders(date_indices, :);
            selected_groups(k).folders_names = lastFolderNames(date_indices, :);
            selected_groups(k).env = true_env_paths(date_indices);
            selected_groups(k).ages = age_part(date_indices);
            selected_groups(k).path = ani_path;
        end
    else
        animal_date_list = [];
        selected_groups = [];
        disp('No directories with Fall.mat or .npy files found:');
    end
end