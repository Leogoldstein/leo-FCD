function [animal_date_list, selected_groups, metadata_results, daytime] = pipeline_for_data_preprocessing(processing_choice1, processing_choice2)
   

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
