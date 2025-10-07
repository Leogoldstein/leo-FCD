function [animal_date_list, selected_groups] = pipeline_for_data_preprocessing()
    %===================%
    %   Définition des chemins de base
    %===================%
    jm_folder = '\\10.51.106.233\jm';
    destinationFolder = 'D:/Imaging/jm/';
    fcd_folder = 'D:\Imaging\FCD';
    ctrl_folder = 'D:\Imaging\WT';
    sham_folder = 'D:\Imaging\SHAM';
    PathSave = 'D:\Imaging';

    %===================%
    %   Initialisation
    %===================%
    gcampdataFolders_all = string([]);
    selected_groups = struct([]);
    group_order = {'jm', 'FCD', 'WT', 'SHAM'};

    %===================%
    %   Choix utilisateur
    %===================%
    disp('Please choose one or more folders to process:');
    disp('1 : JM (.npy data)');
    disp('2 : FCD (Fall.mat data)');
    disp('3 : WT (Fall.mat data)');
    disp('4 : SHAM (Fall.mat data)');
    choices = input('Enter your choice (e.g., 1 2): ', 's');
    choices = str2double(strsplit(choices));
    if any(isnan(choices)) || any(~ismember(choices, [1, 2, 3, 4]))
        error('Choix invalide. Veuillez relancer la fonction et choisir 1, 2, 3 ou 4.');
    end

    %===================%
    %   Chargement existant
    %===================%
    if evalin('base', 'exist(''selected_groups'', ''var'')')
        selected_groups_old = evalin('base', 'selected_groups');
    else
        selected_groups_old = struct([]);
    end

    kept_groups = string.empty(1, 0); % Liste des groupes explicitement conservés
    replace_all = []; % mémorisation du choix utilisateur "remplacer tous" ou non

    %===================%
    %   Traitement des choix
    %===================%
    if ismember(1, choices)
        disp('Processing JM data...');
        dataFolders = select_folders(jm_folder);
        [true_env_paths_jm, TSeriesPaths_jm, ~, statPaths, FPaths, iscellPaths, opsPaths, spksPaths] = find_npy_folders(dataFolders);
        TSeriesPaths_jm = TSeriesPaths_jm(~cellfun('isempty', TSeriesPaths_jm));
        true_env_paths_jm = true_env_paths_jm(~cellfun('isempty', true_env_paths_jm));
        [~, ~, ~, ~, ~, gcampdataFolders] = preprocess_npy_files(FPaths, statPaths, iscellPaths, opsPaths, spksPaths, destinationFolder);
        gcampdataFolders_all = [gcampdataFolders_all; gcampdataFolders(:)];
        disp('Traitement JM terminé.');
    end

    if ismember(2, choices)
        disp('Processing FCD data...');
        dataFolders = select_folders(fcd_folder);
        dataFolders = organize_data_by_animal(dataFolders, group_order{2});
        [TseriesFolders_fcd, TSeriesPaths_fcd, ~, true_env_paths_fcd, lastFolderNames_fcd] = find_Fall_folders(dataFolders);
        gcampdataFolders_all = [gcampdataFolders_all; TseriesFolders_fcd(:, 1)];
        disp('Traitement FCD terminé.');
    end

    if any(ismember([3 4], choices))
        if ismember(3, choices)
            disp('Processing WT data...');
            dataFolders = select_folders(ctrl_folder);
            dataFolders = organize_data_by_animal(dataFolders, group_order{3});
        elseif ismember(4, choices)
            disp('Processing SHAM data...');
            dataFolders = select_folders(sham_folder);
            dataFolders = organize_data_by_animal(dataFolders, group_order{4});
        end
        [TseriesFolders_ctrl, TSeriesPaths_ctrl, ~, true_env_paths_ctrl, lastFolderNames_ctrl] = find_Fall_folders(dataFolders);
        gcampdataFolders_all = [gcampdataFolders_all; TseriesFolders_ctrl(:, 1)];
        disp('Traitement terminé.');
    end

    %===================%
    %   Création de la liste
    %===================%
    gcampdataFolders_all = gcampdataFolders_all(~cellfun('isempty', gcampdataFolders_all));
    animal_date_list = create_animal_date_list(gcampdataFolders_all, PathSave);

    %===================%
    %   Construction des structures
    %===================%
    idx = 1;

    for j = 1:length(choices)
        group_type = group_order{choices(j)};
        group_rows = strcmp(animal_date_list(:, 1), group_type);
        group_data = animal_date_list(group_rows, :);
        if isempty(group_data), continue; end

        animal_part = string(group_data(:, 3));
        mTor_part = string(group_data(:, 2));
        date_part_all = string(group_data(:, 4));
        age_part_all = string(group_data(:, 5));

        animal_group = strings(size(animal_part));
        for i = 1:length(animal_part)
            if mTor_part(i) == ""
                animal_group(i) = animal_part(i);
            else
                animal_group(i) = strcat(animal_part(i), '_', mTor_part(i));
            end
        end

        unique_animal_group = unique(animal_group);

        for k = 1:length(unique_animal_group)
            current_animal_group = unique_animal_group(k);
            date_indices = find(strcmp(animal_group, current_animal_group));
            if isempty(date_indices), continue; end

            parts = strsplit(current_animal_group, '_');
            if isscalar(parts)
                ani_path = fullfile(PathSave, group_type, parts{1});
            else
                ani_path = fullfile(PathSave, group_type, parts{2}, parts{1});
            end
            ani_path = string(ani_path);

            % Vérifier si groupe déjà existant
            existing_idx = [];
            if ~isempty(selected_groups_old)
                for sg = 1:numel(selected_groups_old)
                    if isfield(selected_groups_old(sg), 'animal_group') && ...
                       strcmp(selected_groups_old(sg).animal_group, current_animal_group)
                        existing_idx = sg;
                        break;
                    end
                end
            end

            % === Gestion du remplacement ===
            if ~isempty(existing_idx)
                if isempty(replace_all)
                    fprintf('\nDes groupes déjà existants ont été détectés.\n');
                    disp('1 : Remplacer tous les groupes existants');
                    disp('2 : Conserver les groupes existants');
                    choice_replace = input('Votre choix (1/2) : ');
                    replace_all = (choice_replace == 1);
                end

                if ~replace_all
                    fprintf('Groupe "%s" déjà existant conservé (aucune modification)\n', current_animal_group);
                    kept_groups(end+1) = current_animal_group; % Sauvegarde pour le garder
                    continue;
                else
                    fprintf('Remplacement automatique du groupe "%s"\n', current_animal_group);
                    % Supprimer ancien avant d'ajouter le nouveau
                    selected_groups_old(existing_idx) = [];
                end
            end

            % === Nouveau groupe ===
            selected_groups(idx).animal_group = current_animal_group;
            selected_groups(idx).dates = date_part_all(date_indices);
            selected_groups(idx).animal_type = string(group_type);
            selected_groups(idx).ages = age_part_all(date_indices);
            selected_groups(idx).path = ani_path;

            switch group_type
                case "jm"
                    selected_groups(idx).pathTSeries = TSeriesPaths_jm(date_indices, :);
                    selected_groups(idx).folders = gcampdataFolders_all(date_indices, :);
                    selected_groups(idx).env = true_env_paths_jm(date_indices);
                    selected_groups(idx).folders_names = [];
                case "FCD"
                    selected_groups(idx).pathTSeries = TSeriesPaths_fcd(date_indices, :);
                    selected_groups(idx).folders = TseriesFolders_fcd(date_indices, :);
                    selected_groups(idx).env = true_env_paths_fcd(date_indices);
                    selected_groups(idx).folders_names = string(lastFolderNames_fcd(date_indices, :));
                otherwise
                    selected_groups(idx).pathTSeries = TSeriesPaths_ctrl(date_indices, :);
                    selected_groups(idx).folders = TseriesFolders_ctrl(date_indices, :);
                    selected_groups(idx).env = true_env_paths_ctrl(date_indices);
                    selected_groups(idx).folders_names = string(lastFolderNames_ctrl(date_indices, :));
            end
            idx = idx + 1;
        end
    end

    %===================%
    %   Nettoyage final
    %===================%
    if ~isempty(selected_groups_old)
        old_names = string({selected_groups_old.animal_group});
        new_names = string([]);
        if isfield(selected_groups, 'animal_group')
            new_names = string({selected_groups.animal_group});
        end
        all_kept_names = unique([new_names, kept_groups]); % garde aussi ceux conservés

        keep_mask = ismember(old_names, all_kept_names);
        removed_groups = old_names(~keep_mask);

        if ~isempty(removed_groups)
            fprintf('\nGroupes non sélectionnés détectés : %s\n', strjoin(removed_groups, ', '));
            disp('1 : Supprimer les groupes non sélectionnés');
            disp('2 : Conserver tous les groupes existants');
            choice_clean = input('Votre choix (1/2) : ');
            if choice_clean == 1
                fprintf('Suppression des groupes non sélectionnés...\n');
                selected_groups_old = selected_groups_old(keep_mask);
            else
                fprintf('Aucun groupe supprimé — tous les groupes existants sont conservés.\n');
            end
        end

        % Fusion propre anciens + nouveaux
        selected_groups = [selected_groups_old(:); selected_groups(:)];
    end

    %===================%
    %   Sauvegarde finale
    %===================%
    selected_groups = selected_groups(~cellfun(@isempty, {selected_groups.animal_group}));
    fprintf('\n Mise à jour terminée : %d groupes actifs dans le workspace.\n', numel(selected_groups));
end
