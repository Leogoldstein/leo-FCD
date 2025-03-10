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
            % Exclure les éléments vides dans la première colonne de TseriesFolders
            gcampdataFolders = cellfun(@string, TseriesFolders(:, 1), 'UniformOutput', false);
            disp('Traitement FCD terminé.');

        case 3
            % Traitement CTRL
            disp('Traitement des données CTRL...');
            initial_folder = ctrl_folder; % Point de départ pour la sélection
            dataFolders = select_folders(initial_folder);
            dataFolders = organize_data_by_animal(dataFolders);
            [TseriesFolders, TSeriesPaths, env_paths_all, true_env_paths, lastFolderNames] = find_Fall_folders(dataFolders);
            % Exclure les éléments vides dans la première colonne de TseriesFolders
            gcampdataFolders = cellfun(@string, TseriesFolders(:, 1), 'UniformOutput', false);
            disp('Traitement CTRL terminé.');

        otherwise
            % Option invalide
            error('Choix invalide. Veuillez relancer la fonction et choisir 1, 2 ou 3.');
    end  

    % Créer une liste des animaux et des dates
    PathSave = 'D:\after_processing';
    
    % Créer une liste des animaux et des dates
    animal_date_list = create_animal_date_list(gcampdataFolders, PathSave);
    disp(animal_date_list);
    
    % Ensure all parts are strings, replace empty values with empty strings
    type_part = animal_date_list(~cellfun('isempty', animal_date_list(:,1)), :);
    animal_part = cellfun(@(x) char(x), animal_date_list(:, 3), 'UniformOutput', false);
    mTor_part = cellfun(@(x) char(x), animal_date_list(:, 2), 'UniformOutput', false);
    date_part = animal_date_list(:, 4);
    age_part = animal_date_list(:, 5);
    
    % Replace empty arrays with empty strings
    type_part(cellfun(@isempty, type_part)) = {''};
    mTor_part(cellfun(@isempty, mTor_part)) = {''};
    animal_part(cellfun(@isempty, animal_part)) = {''};
    
    disp(['type_part{1} = ', type_part{1}]);  % Vérification de type_part{1}
    
    disp('Vérification des valeurs extraites :');
    disp('type_part:'), disp(type_part);
    disp('animal_part:'), disp(animal_part);
    disp('mTor_part:'), disp(mTor_part);
    
    % Correction: Traiter chaque ligne indépendamment
    animal_group = cell(size(animal_part));
    for i = 1:length(animal_part)
        if isempty(mTor_part{i})
            animal_group{i} = animal_part{i};
        else
            animal_group{i} = strcat(animal_part{i}, '_', mTor_part{i});
        end
    end
    unique_animal_group = unique(animal_group);
    
    % Initialize save paths and selection storage
    ani_paths = cell(length(unique_animal_group), 1);
    selected_groups = struct();
    
    for k = 1:length(unique_animal_group)
        current_animal_group = unique_animal_group{k};
        parts = strsplit(current_animal_group, '_');
    
        % Construction du chemin avec une vérification correcte
        if isscalar(parts)
            ani_path = fullfile(PathSave, type_part{1}, parts{1});
        else
            ani_path = fullfile(PathSave, type_part{1}, parts{2}, parts{1});
        end
    
        ani_paths{k} = ani_path;
        disp(['Chemin généré : ', ani_path]);  % Vérification du chemin construit
    
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
    valid_rows = ~cellfun(@(x) isempty(x) || strcmp(x, '_'), {selected_groups.animal_group});

    % Filtrer la structure pour ne garder que les lignes valides
    selected_groups = selected_groups(valid_rows);
end