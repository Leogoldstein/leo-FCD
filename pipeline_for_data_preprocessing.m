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
    % - truedataFolders : Dossiers des données valides
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

    % Initialisation des sorties
    truedataFolders = [];
    animal_date_list = [];

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
            [env_paths, statPaths, FPaths, iscellPaths, opsPaths] = find_npy_folders(dataFolders);
            [newFPaths, newStatPaths, newIscellPaths, newOpsPaths, truedataFolders] = preprocess_npy_files(FPaths, statPaths, iscellPaths, opsPaths, destinationFolder);
            disp('Traitement JM terminé.');

        case 2
            % Traitement FCD
            disp('Traitement des données FCD...');
            initial_folder = fcd_folder; % Point de départ pour la sélection
            dataFolders = select_folders(initial_folder);
            dataFolders = organize_data_by_animal(dataFolders);
            [truedataFolders, env_paths_all, env_paths] = find_Fall_folders(dataFolders); % Identifier les fichiers Fall.mat
            disp('Traitement FCD terminé.');

        case 3
            % Traitement CTRL
            disp('Traitement des données CTRL...');
            initial_folder = ctrl_folder; % Point de départ pour la sélection
            dataFolders = select_folders(initial_folder);
            dataFolders = organize_data_by_animal(dataFolders);
            [truedataFolders, env_paths_all, env_paths] = find_Fall_folders(dataFolders); % Identifier les fichiers Fall.mat
            disp('Traitement CTRL terminé.');

        otherwise
            % Option invalide
            error('Choix invalide. Veuillez relancer la fonction et choisir 1, 2 ou 3.');
    end

    % Créer une liste des animaux et des dates
    animal_date_list = create_animal_date_list(truedataFolders, PathSave);

    % Extract parts from the animal_date_list
    type_part = animal_date_list(:, 1);
    mTor_part = animal_date_list(:, 2);
    animal_part = animal_date_list(:, 3);
    date_part = animal_date_list(:, 4);
    age_part = animal_date_list(:, 5);

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
        selected_groups(k).dates = date_part(date_indices);
        selected_groups(k).folders = truedataFolders(date_indices);
        selected_groups(k).env = env_paths(date_indices);
        selected_groups(k).ages = age_part(date_indices);
        selected_groups(k).path = ani_path;

    end
    assignin('base', 'selected_groups', selected_groups);
end