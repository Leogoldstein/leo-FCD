function [animal_date_list, selected_groups] = pipeline_for_data_preprocessing()
    % Définition des chemins de base
    jm_folder = '\\10.51.106.5\data\Data\jm\'; 
    destinationFolder = 'D:/imaging/jm/'; 
    fcd_folder = 'D:\imaging\FCD\'; 
    ctrl_folder = 'D:\imaging\CTRL'; 
    PathSave = 'D:\after_processing';

    % Initialisation des variables globales
    gcampdataFolders_all = string([]);
    selected_groups = struct([]);

    % Demande des choix utilisateurs
    disp('Please choose one or more folders to process:');
    disp('1 : JM (.npy data)');
    disp('2 : FCD (Fall.mat data)');
    disp('3 : CTRL (Fall.mat data)');
    choices = input('Enter your choice (e.g., 1 2): ', 's'); 
    choices = str2double(strsplit(choices));  

    if any(isnan(choices)) || any(~ismember(choices, [1, 2, 3]))
        error('Choix invalide. Veuillez relancer la fonction et choisir 1, 2 ou 3.');
    end

    % Traitement JM
    if ismember(1, choices)
        disp('Processing JM data...');
        dataFolders = select_folders(jm_folder);
        [~, TSeriesPaths_jm, ~, statPaths, FPaths, iscellPaths, opsPaths, spksPaths] = find_npy_folders(dataFolders);
        [~, ~, ~, ~, ~, gcampdataFolders] = preprocess_npy_files(FPaths, statPaths, iscellPaths, opsPaths, spksPaths, destinationFolder);  
        gcampdataFolders_all = [gcampdataFolders_all; gcampdataFolders(:)];
        disp('Traitement JM terminé.');
    end

    % Traitement FCD
    if ismember(2, choices)
        disp('Processing FCD data...');
        dataFolders = select_folders(fcd_folder);
        dataFolders = organize_data_by_animal(dataFolders);
        [TseriesFolders_fcd, TSeriesPaths_fcd, env_paths_all_fcd, true_env_paths_fcd, lastFolderNames_fcd] = find_Fall_folders(dataFolders);    
        gcampdataFolders_all = [gcampdataFolders_all; TseriesFolders_fcd(:, 1)];
        disp('Traitement FCD terminé.');
    end
    
    % Traitement CTRL
    if ismember(3, choices)
        disp('Processing CTRL data...');
        dataFolders = select_folders(ctrl_folder);
        dataFolders = organize_data_by_animal(dataFolders);
        [TseriesFolders_ctrl, TSeriesPaths_ctrl, env_paths_all_ctrl, true_env_paths_ctrl, lastFolderNames_ctrl] = find_Fall_folders(dataFolders);
        gcampdataFolders_all = [gcampdataFolders_all; TseriesFolders_ctrl(:, 1)];
        disp('Traitement CTRL terminé.');
    end

    % Création de la liste des animaux et des dates
    animal_date_list = create_animal_date_list(gcampdataFolders_all, PathSave);

    % Trier animal_date_list selon l'ordre des choix utilisateur
    group_order = {'jm', 'FCD', 'CTRL'};  
    group_priority = group_order(choices);
    sorted_animal_date_list = {};
    
    for i = 1:length(group_priority)
        group = group_priority{i};  
        group_rows = strcmp(animal_date_list(:, 1), group);
        sorted_animal_date_list = [sorted_animal_date_list; animal_date_list(group_rows, :)];
    end
    
    animal_date_list = sorted_animal_date_list;
    disp(animal_date_list)

    % Extraction des colonnes avec filtrage des valeurs vides
    type_part = string(animal_date_list(:, 1));
    animal_part = string(animal_date_list(:, 3));
    mTor_part = string(animal_date_list(:, 2));
    date_part_all = string(animal_date_list(:, 4));
    age_part_all = string(animal_date_list(:, 5));

    % Construction des groupes animaux
    animal_group = strings(size(animal_part));
    for i = 1:length(animal_part)
        if mTor_part(i) == ""
            animal_group(i) = animal_part(i);
        else
            animal_group(i) = strcat(animal_part(i), '_', mTor_part(i));
        end
    end

    % Initialisation des structures de données
    idx = 1;
    for j = 1:length(choices)
        % Obtenir le type choisi par l'utilisateur dans l'ordre
        current_type = group_priority{choices(j)}; % 'jm', 'FCD', 'CTRL'
        
        % Filtrer les animaux par type
        type_indices = type_part == current_type;
        unique_animal_group_filtered = unique(animal_group(type_indices)); 
    
        for k = 1:length(unique_animal_group_filtered)
            current_animal_group = unique_animal_group_filtered(k);
            
            % Trouver les indices de `current_animal_group` dans `animal_group`
            date_indices = find(strcmp(animal_group(type_indices), current_animal_group));
            
            % Vérification pour éviter l'accès à un indice qui dépasse les limites
            if isempty(date_indices)
                continue;
            end
            
            % Créer le chemin d'animal
            ani_path = fullfile(PathSave, current_type, current_animal_group);
    
            % Stockage structuré selon le type
            selected_groups(idx).animal_group = current_animal_group;
            selected_groups(idx).dates = date_part_all(date_indices);
            selected_groups(idx).animal_type = current_type;
    
            % Traitement par type d'animal
            if current_type == "jm"
                selected_groups(idx).pathTSeries = TSeriesPaths_jm(date_indices, :);
                selected_groups(idx).folders = gcampdataFolders_all(date_indices, :);
                selected_groups(idx).env = [];
                selected_groups(idx).folders_names = [];
            elseif current_type == "FCD"
                selected_groups(idx).pathTSeries = TSeriesPaths_fcd(date_indices, :);
                selected_groups(idx).folders = TseriesFolders_fcd(date_indices, :);
                selected_groups(idx).env = true_env_paths_fcd(date_indices);
                selected_groups(idx).folders_names = lastFolderNames_fcd(date_indices, :);
            else
                selected_groups(idx).pathTSeries = TSeriesPaths_ctrl(date_indices, :);
                selected_groups(idx).folders = TseriesFolders_ctrl(date_indices, :);
                selected_groups(idx).env = true_env_paths_ctrl(date_indices);
                selected_groups(idx).folders_names = lastFolderNames_ctrl(date_indices, :);
            end
    
            selected_groups(idx).ages = age_part_all(date_indices);
            selected_groups(idx).path = ani_path;
            idx = idx + 1;
        end
    end

    % Filtrer les structures vides
    selected_groups = selected_groups(~cellfun(@isempty, {selected_groups.animal_group}));

end
