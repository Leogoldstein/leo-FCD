function [animal_date_list, selected_groups, metadata_results, daytime] = pipeline_for_data_preprocessing(processing_choice1, processing_choice2)
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
        [true_xml_paths_jm, TSeriesPaths_jm, ~, statPaths, FPaths, iscellPaths, opsPaths, spksPaths] = find_npy_folders(dataFolders);
        TSeriesPaths_jm = TSeriesPaths_jm(~cellfun('isempty', TSeriesPaths_jm));
        true_xml_paths_jm = true_xml_paths_jm(~cellfun('isempty', true_xml_paths_jm));
        [~, ~, ~, ~, ~, gcampdataFolders] = preprocess_npy_files(FPaths, statPaths, iscellPaths, opsPaths, spksPaths, destinationFolder);
        gcampdataFolders_all = [gcampdataFolders_all; gcampdataFolders(:)];
        disp('Traitement JM terminé.');
    end

    if ismember(2, choices)
        disp('Processing FCD data...');
        dataFolders = select_folders(fcd_folder);
        dataFolders = organize_data_by_animal(dataFolders, group_order{2});
        [TseriesFolders_fcd, TSeriesPaths_fcd, ~, true_xml_paths_fcd, lastFolderNames_fcd, gcampdataFolders_all] = find_Fall_folders(dataFolders);     
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
        [TseriesFolders_ctrl, TSeriesPaths_ctrl, ~, true_xml_paths_ctrl, lastFolderNames_ctrl, gcampdataFolders_all] = find_Fall_folders(dataFolders);
    end

    %===================%
    %   Création de la liste
    %===================%
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
                    selected_groups(idx).Fallmat_folders = gcampdataFolders_all(date_indices, :);
                    selected_groups(idx).xml = true_xml_paths_jm(date_indices);
                    selected_groups(idx).TSeries_folders_names = [];
                case "FCD"
                    selected_groups(idx).pathTSeries = TSeriesPaths_fcd(date_indices, :);
                    selected_groups(idx).Fallmat_folders = TseriesFolders_fcd(date_indices, :);
                    selected_groups(idx).xml = true_xml_paths_fcd(date_indices);
                    selected_groups(idx).TSeries_folders_names = string(lastFolderNames_fcd(date_indices, :));
                otherwise
                    selected_groups(idx).pathTSeries = TSeriesPaths_ctrl(date_indices, :);
                    selected_groups(idx).Fallmat_folders = TseriesFolders_ctrl(date_indices, :);
                    selected_groups(idx).xml = true_xml_paths_ctrl(date_indices);
                    selected_groups(idx).TSeries_folders_names = string(lastFolderNames_ctrl(date_indices, :));
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
        all_kept_names = unique([new_names, kept_groups]);
    
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
    end
    
    %===================%
    %  Harmonisation universelle des champs
    %===================%
    if isempty(selected_groups_old) && isempty(selected_groups)
        selected_groups = struct([]);
    elseif isempty(selected_groups_old)
        selected_groups = selected_groups(:);
    elseif isempty(selected_groups)
        selected_groups = selected_groups_old(:);
    else
        % Normalisation complète des champs
        fields_old = fieldnames(selected_groups_old);
        fields_new = fieldnames(selected_groups);
        all_fields = unique([fields_old; fields_new]);
    
        for f = 1:numel(all_fields)
            fn = all_fields{f};
            if ~isfield(selected_groups_old, fn)
                [selected_groups_old.(fn)] = deal([]);
            end
            if ~isfield(selected_groups, fn)
                [selected_groups.(fn)] = deal([]);
            end
        end
    
        % Fusion finale
        selected_groups = [selected_groups_old(:); selected_groups(:)];
    end
    
    %===================%
    %   Nettoyage et sauvegarde finale
    %===================%
    if ~isempty(selected_groups) && isfield(selected_groups, 'animal_group')
        selected_groups = selected_groups(~cellfun(@isempty, {selected_groups.animal_group}));
    end

    %===================%
    %   Création des gcamp_output_folders + daytime
    %===================%
    if ~isempty(selected_groups)
        currentDatetime = datetime('now');
        daytime = datestr(currentDatetime, 'yy_mm_dd_HH_MM');

        % même daytime pour tous les groupes
        [selected_groups.daytime] = deal(daytime);

        gcamp_output_folders_all = cell(numel(selected_groups), 1);

        for k = 1:numel(selected_groups)
            current_animal_group      = selected_groups(k).animal_group;
            current_ani_path_group    = selected_groups(k).path;
            current_dates_group       = selected_groups(k).dates;
            current_animal_type       = selected_groups(k).animal_type;

            % Chemins par date
            date_group_paths = cell(length(current_dates_group), 1);
            for l = 1:length(current_dates_group)
                date_group_paths{l} = fullfile(current_ani_path_group, current_dates_group{l});
            end

            % Noms de dossiers TSeries / Fall
            if ~strcmp(current_animal_type, 'jm')
                current_gcamp_folders_names_group  = selected_groups(k).TSeries_folders_names(:, 1);
            else
                % Pour JM, on reconstruit à partir des pathTSeries
                current_gcamp_TSeries_path = selected_groups(k).pathTSeries(:, 1);
                current_gcamp_folders_names_group = cell(size(current_gcamp_TSeries_path));
                for l = 1:length(current_gcamp_TSeries_path)
                    [~, lastFolderName] = fileparts(current_gcamp_TSeries_path{l});
                    current_gcamp_folders_names_group{l} = lastFolderName;
                end
            end

            % Création des dossiers de sortie pour ce groupe
            gcamp_output_folders = create_base_folders( ...
                date_group_paths, ...
                current_gcamp_folders_names_group, ...
                daytime, ...
                processing_choice1, ...
                processing_choice2, ...
                current_animal_group);

            % Stockage dans la structure pour usage ultérieur
            selected_groups(k).gcamp_output_folders = gcamp_output_folders;

            % Dossier de référence pour les métadonnées (on prend le 1er si dispo)
            if ~isempty(gcamp_output_folders)
                gcamp_output_folders_all{k} = gcamp_output_folders;
            else
                gcamp_output_folders_all{k} = '';
            end
        end

        % Sauvegarde des métadonnées dans les dossiers créés
        metadata_results = save_metadata_results(selected_groups, gcamp_output_folders_all);
    else
        daytime = '';
        metadata_results = {};
    end
end

function metadata_results = save_metadata_results(selected_groups, gcamp_output_folders_all)
% save_metadata_results - extrait les métadonnées XML
% et les enregistre :
%   1) dans chaque dossier gcamp_output_folders d'un groupe
%   2) en version agrégée par groupe dans current_ani_path_group.
%
% INPUTS :
%   selected_groups          : structure de groupes (champ .xml, .path, etc.)
%   gcamp_output_folders_all : cell array {k} contenant pour chaque groupe
%                              un cell array de dossiers de sortie
%                              gcamp_output_folders_all{k}{idx}
%
% OUTPUT :
%   metadata_results         : cell array de tables, une table agrégée par groupe
%
% La fonction utilise "find_key_value" (externe) pour extraire les infos.

    % --- Gérer l'argument optionnel / vide ---
    save_to_excel = true;
    if nargin < 2 || isempty(gcamp_output_folders_all)
        save_to_excel = false;    % on ne sauvegarde pas si pas fourni
    end

    nGroups = numel(selected_groups);
    metadata_results = cell(nGroups, 1);  % sortie

    for k = 1:nGroups

        % Récupération des XML du groupe
        current_xml_group = selected_groups(k).xml;   % cell de chemins XML
        nXml = numel(current_xml_group);

        % Récupération des dossiers de sortie du groupe
        if save_to_excel
            this_group_folders = gcamp_output_folders_all{k};
            % Assurer que c'est bien un cell array
            if ~iscell(this_group_folders)
                this_group_folders = {this_group_folders};
            end
        else
            this_group_folders = {};
        end

        % Table agrégée pour tout le groupe
        group_table = table();

        for idx = 1:nXml

            % ---------- Extraction des métadonnées à partir du XML ----------
            xml_file = current_xml_group{idx};

            [recording_time, sampling_rate, optical_zoom, position, ...
             time_minutes, pixel_size, num_planes] = ...
                find_key_value(xml_file);

            % Convertir position Z (scalaire ou vecteur) en string
            if num_planes == 1
                pos_str = sprintf('%.4f', position);
            else
                pos_str = sprintf('%.4f ', position);
                pos_str = strtrim(pos_str);
            end

            % Ligne pour ce fichier XML
            newRow = {
                xml_file, ...
                recording_time, ...
                sampling_rate, ...
                optical_zoom, ...
                pos_str, ...
                time_minutes, ...
                pixel_size, ...
                num_planes ...
            };

            % Construire une table 1-ligne
            rowTable = cell2table(newRow, 'VariableNames', { ...
                'Filename', 'RecordingTime', 'SamplingRate', 'OpticalZoom', ...
                'PositionZ', 'TimeMinutes', 'PixelSize', 'NumPlanes' ...
            });

            % Ajouter à la table agrégée du groupe
            group_table = [group_table ; rowTable]; %#ok<AGROW>

            % ---------- Sauvegarde par enregistrement (par gcamp_output_folder) ----------
            if save_to_excel && idx <= numel(this_group_folders) ...
                              && ~isempty(this_group_folders{idx})

                this_folder = this_group_folders{idx};

                % fichier local à cet enregistrement
                output_path_single = fullfile(this_folder, 'metadata_results.xlsx');

                % Ici on choisit de sauvegarder uniquement la ligne correspondant
                % à cet enregistrement (rowTable). Si tu veux dupliquer toute la
                % table du groupe dans chaque dossier, remplace rowTable par group_table.
                writetable(rowTable, output_path_single, 'FileType', 'spreadsheet');
                fprintf('Metadata (enregistrement %d) saved → %s\n', idx, output_path_single);
            end
        end

        % ---------- Sauvegarde agrégée pour tout le groupe ----------
        if save_to_excel
            current_ani_path_group = selected_groups(k).path;  % dossier animal

            if ~isempty(current_ani_path_group)
                % fichier cumulatif du groupe
                group_output_path = fullfile(current_ani_path_group, 'metadata_results_group.xlsx');
                writetable(group_table, group_output_path, 'FileType', 'spreadsheet');
                fprintf('Metadata groupées pour groupe %d → %s\n', k, group_output_path);
            else
                fprintf('Attention : pas de chemin .path pour le groupe %d, pas de fichier agrégé.\n', k);
            end
        else
            fprintf('Metadata for group %d computed (pas de dossier de sortie fourni, pas de fichier Excel).\n', k);
        end

        % Stocker la table agrégée en sortie
        metadata_results{k} = group_table;
    end
end
