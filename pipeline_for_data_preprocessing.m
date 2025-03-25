function [results, animal_date_list, selected_groups] = pipeline_for_data_preprocessing()
    % Définition des chemins de base
    jm_folder = '\\10.51.106.5\data\Data\jm\'; 
    destinationFolder = 'D:/imaging/jm/'; 
    fcd_folder = 'D:\imaging\FCD\'; 
    ctrl_folder = 'D:\imaging\CTRL'; 
    PathSave = 'D:\after_processing';

    % Initialisation des variables globales
    results = struct();
    gcampdataFolders_all = {}; 
    TSeriesPaths_all = {};
    true_env_paths_all = {};
    lastFolderNames_all = {};
    TseriesFolders_all = {};

    % Demande des choix utilisateurs
    disp('Please choose one or more folders to process:');
    disp('1 : JM (.npy data)');
    disp('2 : FCD (Fall.mat data)');
    disp('3 : CTRL (Fall.mat data)');
    choices = input('Enter your choice (e.g., 1 2): ', 's'); 
    choices = str2num(choices);  

    if isempty(choices) || any(~ismember(choices, [1, 2, 3]))
        error('Choix invalide. Veuillez relancer la fonction et choisir 1, 2 ou 3.');
    end

    % Traitement JM
    if ismember(1, choices)
        disp('Processing JM data...');
        dataFolders = select_folders(jm_folder);
        [true_env_paths, TSeriesPaths, env_paths_all, statPaths, FPaths, iscellPaths, opsPaths, spksPaths] = find_npy_folders(dataFolders);
        [~, ~, ~, ~, ~, gcampdataFolders] = preprocess_npy_files(FPaths, statPaths, iscellPaths, opsPaths, spksPaths, destinationFolder);  

        results.JM = struct('gcampdataFolders', {gcampdataFolders}, 'env_paths_all', {env_paths_all});
        gcampdataFolders_all = vertcat(gcampdataFolders_all, gcampdataFolders(:));  % Correction ici
        TSeriesPaths_all = vertcat(TSeriesPaths_all, TSeriesPaths(:));
        true_env_paths_all = vertcat(true_env_paths_all, true_env_paths(:));

        disp('Traitement JM terminé.');
    end

    % Traitement FCD
    if ismember(2, choices)
        disp('Processing FCD data...');
        dataFolders = select_folders(fcd_folder);
        dataFolders = organize_data_by_animal(dataFolders);
        [TseriesFolders, TSeriesPaths, env_paths_all, true_env_paths, lastFolderNames] = find_Fall_folders(dataFolders);

        gcampdataFolders = cellfun(@string, TseriesFolders(:, 1), 'UniformOutput', false);
        results.FCD = struct('gcampdataFolders', {gcampdataFolders}, 'env_paths_all', {env_paths_all});
        gcampdataFolders_all = vertcat(gcampdataFolders_all, gcampdataFolders(:));
        TSeriesPaths_all = vertcat(TSeriesPaths_all, TSeriesPaths(:));
        true_env_paths_all = vertcat(true_env_paths_all, true_env_paths(:));
        lastFolderNames_all = vertcat(lastFolderNames_all, lastFolderNames(:));
        TseriesFolders_all = vertcat(TseriesFolders_all, TseriesFolders(:));

        disp('Traitement FCD terminé.');
    end

    % Traitement CTRL
    if ismember(3, choices)
        disp('Processing CTRL data...');
        dataFolders = select_folders(ctrl_folder);
        dataFolders = organize_data_by_animal(dataFolders);
        [TseriesFolders, TSeriesPaths, env_paths_all, true_env_paths, lastFolderNames] = find_Fall_folders(dataFolders);

        gcampdataFolders = cellfun(@string, TseriesFolders(:, 1), 'UniformOutput', false);
        results.CTRL = struct('gcampdataFolders', {gcampdataFolders}, 'env_paths_all', {env_paths_all});
        gcampdataFolders_all = vertcat(gcampdataFolders_all, gcampdataFolders(:));
        TSeriesPaths_all = vertcat(TSeriesPaths_all, TSeriesPaths(:));
        true_env_paths_all = vertcat(true_env_paths_all, true_env_paths(:));
        lastFolderNames_all = vertcat(lastFolderNames_all, lastFolderNames(:));
        TseriesFolders_all = vertcat(TseriesFolders_all, TseriesFolders(:));

        disp('Traitement CTRL terminé.');
    end

    % Création de la liste des animaux et des dates
    animal_date_list = create_animal_date_list(gcampdataFolders_all, PathSave);
    disp(animal_date_list);

    % Extraction des colonnes
    type_part = animal_date_list(:, 1);
    animal_part = animal_date_list(:, 3);
    mTor_part = animal_date_list(:, 2);
    date_part_all = animal_date_list(:, 4);
    age_part_all = animal_date_list(:, 5);

    % Gestion des valeurs vides
    type_part(cellfun(@isempty, type_part)) = {''};
    mTor_part(cellfun(@isempty, mTor_part)) = {''};
    animal_part(cellfun(@isempty, animal_part)) = {''};

    % Construction des groupes animaux
    animal_group = cell(size(animal_part));
    for i = 1:length(animal_part)
        if isempty(mTor_part{i})
            animal_group{i} = animal_part{i};
        else
            animal_group{i} = strcat(animal_part{i}, '_', mTor_part{i});
        end
    end
    unique_animal_group = unique(animal_group);

    % Initialisation de selected_groups
    selected_groups = struct();
    for k = 1:length(unique_animal_group)
        current_animal_group = unique_animal_group{k};
        parts = strsplit(current_animal_group, '_');

        if isscalar(parts)
            ani_path = fullfile(PathSave, type_part{1}, parts{1});
        else
            ani_path = fullfile(PathSave, type_part{1}, parts{2}, parts{1});
        end

        % Indices des dates correspondantes
        date_indices = find(strcmp(animal_group, current_animal_group));

        % Stockage dans selected_groups
        selected_groups(k).animal_group = current_animal_group;
        selected_groups(k).animal_type = unique(type_part(date_indices)); 
        selected_groups(k).dates = date_part_all(date_indices);
        selected_groups(k).pathTSeries = TSeriesPaths_all(date_indices, :);

        % Condition pour différencier JM des autres groupes
        if ~ismember(1, choices)
            selected_groups(k).folders = TseriesFolders_all(date_indices, :);
            selected_groups(k).folders_names = lastFolderNames_all(date_indices, :);
        else
            selected_groups(k).folders = gcampdataFolders_all(date_indices, :);
        end

        selected_groups(k).env = true_env_paths_all(date_indices);
        selected_groups(k).ages = age_part_all(date_indices);
        selected_groups(k).path = ani_path;
    end

    % Suppression des groupes vides
    valid_rows = ~cellfun(@(x) isempty(x) || strcmp(x, '_'), {selected_groups.animal_group});
    selected_groups = selected_groups(valid_rows);
end
