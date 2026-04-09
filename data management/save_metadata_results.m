function [metadata_results, selected_groups] = save_metadata_results(selected_groups)
% save_metadata_results
% Extrait les métadonnées XML et les enregistre :
%   1) dans chaque dossier gcamp_output_folders d'un groupe
%   2) en version agrégée par groupe dans animal_path
%
% Si le fichier agrégé existe déjà dans le groupe, la fonction skip et recharge.
%
% INPUTS :
%   selected_groups          : structure de groupes
%   gcamp_output_folders_all : cell array des dossiers de sortie
%
% OUTPUTS :
%   metadata_results         : cell array de tables
%   selected_groups          : structure mise à jour avec .metadata_results

    %===================%
    %   Cas vide
    %===================%
    if nargin < 1 || isempty(selected_groups)
        metadata_results = {};
        return;
    end

    %===================%
    %   Gestion sauvegarde Excel
    %===================%
    save_to_excel = true;
    
    gcamp_output_folders_all = selected_groups.gcamp_root_folders;

    nGroups = numel(selected_groups);
    metadata_results = cell(nGroups, 1);

    for k = 1:nGroups

        %===================%
        %   Dossiers du groupe
        %===================%
        if save_to_excel && k <= numel(gcamp_output_folders_all)
            this_group_folders = gcamp_output_folders_all{k};
            if ~iscell(this_group_folders)
                this_group_folders = {this_group_folders};
            end
        else
            this_group_folders = {};
        end

        %===================%
        %   Chemin animal / groupe
        %===================%
        if isfield(selected_groups(k), 'animal_path') && ~isempty(selected_groups(k).animal_path)
            current_ani_path_group = selected_groups(k).animal_path;
        else
            current_ani_path_group = '';
        end

        %===================%
        %   Skip si déjà traité
        %===================%
        if save_to_excel
            group_output_path = fullfile(current_ani_path_group, 'metadata_results_group.xlsx');

            if ~isempty(current_ani_path_group) && exist(group_output_path, 'file') == 2
                fprintf('Group %d: grouped metadata already exists -> skipping.\n', k);

                try
                    metadata_results{k} = readtable(group_output_path);
                catch
                    warning('Impossible de relire %s, table vide renvoyee.', group_output_path);
                    metadata_results{k} = table();
                end

                selected_groups(k).metadata_results = metadata_results{k};
                continue;
            end
        end

        %===================%
        %   Récupération des XML du groupe
        %===================%
        if isfield(selected_groups(k), 'xml_path') && ~isempty(selected_groups(k).xml_path)
            current_xml_group = selected_groups(k).xml_path;
        else
            current_xml_group = {};
        end

        if isrow(current_xml_group)
            current_xml_group = current_xml_group(:);
        end

        nXml = numel(current_xml_group);

        % Table agrégée pour tout le groupe
        group_table = table();

        for idx = 1:nXml

            %===================%
            %   XML courant
            %===================%
            xml_file = current_xml_group{idx};

            if isempty(xml_file) || exist(xml_file, 'file') ~= 2
                warning('XML introuvable pour groupe %d, index %d.', k, idx);
                continue;
            end

            %===================%
            %   Extraction depuis le XML
            %===================%
            [recording_time, sampling_rate, sampling_rate_per_plane, optical_zoom, position, ...
             time_minutes, pixel_size, num_planes] = find_key_value(xml_file);

            % Conversion position Z en string
            if isempty(position)
                pos_str = '';
            elseif num_planes == 1
                pos_str = sprintf('%.4f', position);
            else
                pos_str = sprintf('%.4f ', position);
                pos_str = strtrim(pos_str);
            end

            % Ligne de résultat
            newRow = {
                xml_file, ...
                recording_time, ...
                sampling_rate, ...
                sampling_rate_per_plane, ...
                optical_zoom, ...
                pos_str, ...
                time_minutes, ...
                pixel_size, ...
                num_planes ...
            };

            rowTable = cell2table(newRow, 'VariableNames', { ...
                'Filename', 'RecordingTime', 'SamplingRate', 'SamplingRatePlane', 'OpticalZoom', ...
                'PositionZ', 'TimeMinutes', 'PixelSize', 'NumPlanes' ...
            });

            group_table = [group_table; rowTable]; %#ok<AGROW>

            %===================%
            %   Sauvegarde locale
            %===================%
            if save_to_excel && idx <= numel(this_group_folders) && ~isempty(this_group_folders{idx})

                this_folder = this_group_folders{idx};

                % si structure {m}{p}, prendre le root session
                if iscell(this_folder)
                    if ~isempty(this_folder) && ~isempty(this_folder{1})
                        this_folder = fileparts(this_folder{1});
                    else
                        this_folder = '';
                    end
                end

                if ~isempty(this_folder)
                    if ~exist(this_folder, 'dir')
                        mkdir(this_folder);
                    end

                    output_path_single = fullfile(this_folder, 'metadata_results.xlsx');
                    writetable(rowTable, output_path_single, 'FileType', 'spreadsheet');

                    fprintf('Metadata (enregistrement %d) saved -> %s\n', idx, output_path_single);
                end
            end
        end

        %===================%
        %   Sauvegarde agrégée
        %===================%
        if save_to_excel
            if ~isempty(current_ani_path_group)
                if ~exist(current_ani_path_group, 'dir')
                    mkdir(current_ani_path_group);
                end

                group_output_path = fullfile(current_ani_path_group, 'metadata_results_group.xlsx');
                writetable(group_table, group_output_path, 'FileType', 'spreadsheet');
                fprintf('Metadata groupees pour groupe %d -> %s\n', k, group_output_path);
            else
                fprintf('Attention : pas de chemin animal_path pour le groupe %d, pas de fichier agrege.\n', k);
            end
        else
            fprintf('Metadata for group %d computed (pas de dossier de sortie fourni, pas de fichier Excel).\n', k);
        end

        metadata_results{k} = group_table;
        selected_groups(k).metadata_results = group_table;
    end
end