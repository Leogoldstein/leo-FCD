function [selected_groups, daytime] = process_selected_group(selected_groups, processing_choice1, processing_choice2, checking_choice2, include_blue_cells)
    
    % Perform analyses for each group
    for k = 1:length(selected_groups)
        current_animal_group = selected_groups(k).animal_group;
        current_animal_type = selected_groups(k).animal_type;       
        current_ani_path_group = selected_groups(k).path;
        current_dates_group = selected_groups(k).dates;
        current_ages_group = selected_groups(k).ages;
        
        % Create paths for each date group
        date_group_paths = cell(length(current_dates_group), 1);  
        for l = 1:length(current_dates_group)
            date_path = fullfile(current_ani_path_group, current_dates_group{l});
            date_group_paths{l} = date_path;
        end

        current_gcamp_TSeries_path = selected_groups(k).pathTSeries(:, 1);
        current_blue_TSeries_path = selected_groups(k).pathTSeries(:, 3);

        if ~strcmp(current_animal_type, 'jm')
            current_gcamp_folders_group = selected_groups(k).Fallmat_folders(:, 1);
            current_red_folders_group   = selected_groups(k).Fallmat_folders(:, 2);
            current_blue_folders_group  = selected_groups(k).Fallmat_folders(:, 3);
            current_green_folders_group = selected_groups(k).Fallmat_folders(:, 4);
        
            current_gcamp_folders_names_group  = selected_groups(k).TSeries_folders_names(:, 1);
            % current_red_folders_names_group    = selected_groups(k).TSeries_folders_names(:, 2);
            % current_blue_folders_names_group   = selected_groups(k).TSeries_folders_names(:, 3);
            % current_green_folders_names_group  = selected_groups(k).TSeries_folders_names(:, 4);
        else
            current_gcamp_folders_group = selected_groups(k).Fallmat_folders;
            current_red_folders_group   = cell(size(current_gcamp_folders_group));
            current_blue_folders_group  = cell(size(current_gcamp_folders_group));
            current_green_folders_group = cell(size(current_gcamp_folders_group));
        
            current_gcamp_folders_names_group = cell(size(current_gcamp_folders_group));
            current_red_folders_names_group   = cell(size(current_gcamp_folders_group));
            current_blue_folders_names_group  = cell(size(current_gcamp_folders_group));
            current_green_folders_names_group = cell(size(current_gcamp_folders_group));
        
            for l = 1:length(current_gcamp_TSeries_path)
                [~, lastFolderName] = fileparts(current_gcamp_TSeries_path{l});
                current_gcamp_folders_names_group{l} = lastFolderName;
        
                current_red_folders_group{l}   = [];
                current_blue_folders_group{l}  = [];
                current_green_folders_group{l} = [];
                current_red_folders_names_group{l}   = [];
                current_blue_folders_names_group{l}  = [];
                current_green_folders_names_group{l} = [];
            end
        end
        
        current_xml_group = selected_groups(k).xml;
        
        currentDatetime = datetime('now');
        daytime = datestr(currentDatetime, 'yy_mm_dd_HH_MM');
        gcamp_output_folders = create_base_folders(date_group_paths, current_gcamp_folders_names_group, daytime, processing_choice1, processing_choice2, current_animal_group);     
        
        for m = 1:length(gcamp_output_folders)
            folder_path = gcamp_output_folders{m};
            parent_fig = fileparts(folder_path);  % dossier parent

            %Lister tous les fichiers et dossiers à l'intérieur de parent_fig
            contents = dir(parent_fig);
            contents = contents(~ismember({contents.name}, {'.','..'})); % exclure . et ..

            %Supprimer chaque élément sauf folder_path lui-même
            for i = 1:length(contents)
                item_path = fullfile(parent_fig, contents(i).name);
                if strcmp(item_path, folder_path)
                    continue; % ne rien faire pour folder_path
                end
                if contents(i).isdir
                    %Supprimer le sous-dossier et son contenu
                    rmdir(item_path, 's');
                else
                    %Supprimer le fichier
                    delete(item_path);
                end
             end

            fprintf('Contenu de %s supprimé (sauf %s).\n', parent_fig, folder_path);
        end

        metadata_results = save_metadata_results(selected_groups, gcamp_output_folders);
        assignin('base', 'metadata_results', metadata_results);
        meta_tbl = metadata_results{k};
        
        % Performing mean images
        meanImgs_gcamp = save_mean_images(current_animal_group, current_dates_group, current_ages_group, gcamp_output_folders, current_gcamp_folders_group);

        % Preprocess and process data
        if ~isfield(selected_groups(k), 'data') || isempty(selected_groups(k).data)
            data = load_or_process_raster_data(gcamp_output_folders, current_gcamp_folders_group, current_red_folders_group, current_blue_folders_group, current_green_folders_group, current_xml_group, current_blue_TSeries_path, current_animal_group, current_ages_group, date_group_paths, current_gcamp_TSeries_path, include_blue_cells, meta_tbl, meanImgs_gcamp);                    
            selected_groups(k).data = data;
        else
            data = selected_groups(k).data;
        end

        % Performing motion_energy
        avg_block = 5; % Moyenne toutes les 5 frames
        [motion_energy_group, avg_motion_energy_group]  = load_or_process_movie(current_gcamp_TSeries_path, gcamp_output_folders, avg_block);      
            
        if ~isempty(checking_choice2)
            %plot_random_F_and_DF(data, current_animal_group, current_ages_group);
            [~, selected_gcamp_neurons_original, selected_blue_neurons_original, suite2p] = data_checking(data, gcamp_output_folders, current_gcamp_folders_group, current_animal_group, current_dates_group, current_ages_group, meanImgs_gcamp, checking_choice2);

            checked_indices = find(~cellfun(@isempty, selected_gcamp_neurons_original) | ~cellfun(@isempty, selected_blue_neurons_original)); % Indices des dossiers avec des neurones sélectionnés

            if ~isempty(checked_indices)            
                
                bad_gcamp_ind_list = selected_gcamp_neurons_original(checked_indices);
                bad_blue_ind_list = selected_blue_neurons_original(checked_indices);
                data = load_or_process_raster_data(gcamp_output_folders(checked_indices), current_gcamp_folders_group(checked_indices), current_xml_group(checked_indices), current_blue_folders_group(checked_indices), current_animal_group, current_ages_group(checked_indices), date_group_paths(checked_indices), current_gcamp_TSeries_path(checked_indices), include_blue_cells, bad_gcamp_ind_list, bad_blue_ind_list, suite2p);                    
            end

            build_rasterplot_checking(data, gcamp_output_folders, current_animal_group, current_ages_group, avg_motion_energy_group);
        end
        
        build_rasterplot(data, gcamp_output_folders, current_animal_group, current_ages_group, avg_motion_energy_group)
       
        % Store processed data in selected_groups for this group
        selected_groups(k).gcamp_output_folders = gcamp_output_folders;
        selected_groups(k).current_blue_folders_group = current_blue_folders_group;
        

    end
end

%% HELPER FUNCTIONS

function metadata_results = save_metadata_results(selected_groups, gcamp_output_folders)
% save_metadata_results - extrait les métadonnées de groupes XML 
% et les enregistre dans un fichier EXCEL par groupe.
%
% INPUTS :
%   selected_groups        : structure contenant les groupes et leurs fichiers XML
%   gcamp_output_folders   : dossier de sortie pour chaque groupe
%
% OUTPUT :
%   metadata_results       : cell array de tables, une par groupe
%
% La fonction utilise "find_key_value" (externe) pour extraire les infos.

    metadata_results = cell(length(selected_groups), 1);  % sortie

    for k = 1:length(selected_groups)

        % Récupération du groupe XML
        current_xml_group = selected_groups(k).xml;
        results = table();  % tableau résultat pour ce groupe

        for idx = 1:length(current_xml_group)

            % Extraction des métadonnées XML
            [recording_time, sampling_rate, optical_zoom, position, ...
             time_minutes, pixel_size, num_planes] = ...
                find_key_value(current_xml_group{idx});

            % Convertir position Z (scalaire ou vecteur) en string
            if num_planes == 1
                pos_str = sprintf('%.4f', position);
            else
                pos_str = sprintf('%.4f ', position);
                pos_str = strtrim(pos_str);
            end

            % Ajouter une ligne au tableau
            newRow = {
                current_xml_group{idx}, ...
                recording_time, ...
                sampling_rate, ...
                optical_zoom, ...
                pos_str, ...
                time_minutes, ...
                pixel_size, ...
                num_planes ...
            };

            results = [results ; newRow]; %#ok<AGROW>
        end

        % Définir les noms de colonnes
        results.Properties.VariableNames = { ...
            'Filename', 'RecordingTime', 'SamplingRate', 'OpticalZoom', ...
            'PositionZ', 'TimeMinutes', 'PixelSize', 'NumPlanes' ...
        };

        % Path de sortie (Excel)
        output_path = fullfile(gcamp_output_folders{k}, 'metadata_results.xlsx');

        % Sauvegarde EXCEL
        writetable(results, output_path, 'FileType', 'spreadsheet');

        fprintf('Metadata saved for group %d → %s\n', k, output_path);

        % Stocker aussi le tableau en sortie
        metadata_results{k} = results;
    end
end


function data = load_or_process_raster_data(gcamp_output_folders, current_gcamp_folders_group, current_red_folders_group, current_blue_folders_group, current_green_folders_group, current_xml_group, current_blue_TSeries_path, current_animal_group, current_ages_group, date_group_paths, current_gcamp_TSeries_path, include_blue_cells, meta_tbl, meanImgs_gcamp, bad_gcamp_ind_list, bad_blue_ind_list, suite2p)
    
    if nargin < 17
        bad_gcamp_ind_list = cell(size(gcamp_output_folders));  % cellule vide
    end

    if nargin < 18
        bad_blue_ind_list = cell(size(gcamp_output_folders));  % cellule vide
    end

    if nargin < 19
        suite2p = false;
    end

    data   = struct();
    fields = {};
    
    % 1) GCaMP d'abord
    [data, fields] = process_gcamp_cells( ...
        gcamp_output_folders, suite2p, ...
        current_xml_group, meta_tbl, ...
        current_gcamp_folders_group, ...
        current_animal_group, current_ages_group, ...
        data, fields);
    
    % 2) Puis les cellules bleues
    [data, fields] = process_blue_cells( ...
        gcamp_output_folders, include_blue_cells, suite2p, ...
        date_group_paths, ...
        current_gcamp_folders_group, current_red_folders_group, current_blue_folders_group, current_green_folders_group, ...
        current_blue_TSeries_path, ...
        meanImgs_gcamp, ...
        data, fields);

    % 3) Combinaison GCaMP + bleu
    [data, fields] = combined_gcamp_blue_cells( ...
        gcamp_output_folders, current_gcamp_folders_group, ...
        data, fields);

end




function removeFieldsByName(filePath, fieldsToRemove)
    % Vérifie si le fichier existe
    if exist(filePath, 'file') ~= 2
        error('Le fichier %s n''existe pas.', filePath);
    end

    % Charger les données
    loaded = load(filePath);
    allFields = fieldnames(loaded);

    % Vérifier que fieldsToRemove est une cellule de chaînes
    if ~iscellstr(fieldsToRemove)
        error('fieldsToRemove doit être une cellule de chaînes de caractères.');
    end

    % Liste finale de champs à supprimer
    expandedFields = {};

    for i = 1:numel(fieldsToRemove)
        token = fieldsToRemove{i};

        % Vérifie si c'est une plage (format "champ1:champ2")
        parts = strsplit(token, ':');
        if numel(parts) == 2
            startIdx = find(strcmp(allFields, parts{1}));
            endIdx   = find(strcmp(allFields, parts{2}));
            if isempty(startIdx) || isempty(endIdx)
                warning('Plage "%s" ignorée car champs introuvables.', token);
                continue;
            end
            if startIdx <= endIdx
                expandedFields = [expandedFields; allFields(startIdx:endIdx)];
            else
                expandedFields = [expandedFields; allFields(endIdx:startIdx)];
            end
        else
            expandedFields = [expandedFields; token];
        end
    end

    % Suppression effective des champs
    for i = 1:numel(expandedFields)
        fieldName = expandedFields{i};
        if isfield(loaded, fieldName)
            loaded = rmfield(loaded, fieldName);
            fprintf('Champ "%s" supprimé.\n', fieldName);
        else
            warning('Champ "%s" absent du fichier.\n', fieldName);
        end
    end

    % Sauvegarder les données mises à jour
    save(filePath, '-struct', 'loaded');
    fprintf('Mise à jour terminée.\n');
end


