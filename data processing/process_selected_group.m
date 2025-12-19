function [selected_groups, daytime, results_analysis_all, plots_data_all] = process_selected_group(selected_groups, metadata_results, checking_choice2, include_blue_cells)
    
    % Récupérer daytime depuis selected_groups si déjà créé dans le pipeline
    if isfield(selected_groups, 'daytime') && ~isempty(selected_groups(1).daytime)
        daytime = selected_groups(1).daytime;
    else
        % fallback au cas où on appellerait encore cette fonction "à l'ancienne"
        currentDatetime = datetime('now');
        daytime = datestr(currentDatetime, 'yy_mm_dd_HH_MM');
    end
    
    results_analysis_all = cell(length(selected_groups), 1);
    plots_data_all       = cell(length(selected_groups), 1);
    data   = struct();
    fields = {};
    
    % Perform analyses for each group
    for k = 1:length(selected_groups)
        current_animal_group   = selected_groups(k).animal_group;
        current_animal_type    = selected_groups(k).animal_type;       
        current_ani_path_group = selected_groups(k).path;
        current_dates_group    = selected_groups(k).dates;
        current_ages_group     = selected_groups(k).ages;
        
        % Create paths for each date group
        date_group_paths = cell(length(current_dates_group), 1);  
        for l = 1:length(current_dates_group)
            date_path = fullfile(current_ani_path_group, current_dates_group{l});
            date_group_paths{l} = date_path;
        end

        current_gcamp_TSeries_path = selected_groups(k).pathTSeries(:, 1);
        current_blue_TSeries_path  = selected_groups(k).pathTSeries(:, 3);

        if ~strcmp(current_animal_type, 'jm')
            current_gcamp_folders_group = selected_groups(k).Fallmat_folders(:, 1);
            current_red_folders_group   = selected_groups(k).Fallmat_folders(:, 2);
            current_blue_folders_group  = selected_groups(k).Fallmat_folders(:, 3);
            current_green_folders_group = selected_groups(k).Fallmat_folders(:, 4);
        
            current_gcamp_folders_names_group  = selected_groups(k).TSeries_folders_names(:, 1);
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

        if isfield(selected_groups, 'gcamp_output_folders') && ~isempty(selected_groups(k).gcamp_output_folders)
            gcamp_output_folders = selected_groups(k).gcamp_output_folders;
        else
            error('gcamp_output_folders manquant pour le groupe %s. Assure-toi que pipeline_for_data_preprocessing a été appelé avec la nouvelle version.', current_animal_group);
        end
        
        % Nettoyage du contenu des dossiers parent (comme avant)
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

        meta_tbl = metadata_results{k};
        
        % Performing mean images
        meanImgs_gcamp = save_mean_images(current_animal_group, current_dates_group, current_ages_group, gcamp_output_folders, current_gcamp_folders_group);

        % Preprocess and process data
        if ~isfield(selected_groups(k), 'data') || isempty(selected_groups(k).data)
            % 1) GCaMP d'abord
            [data, fields] = process_gcamp_cells( ...
                gcamp_output_folders, ...
                current_xml_group, meta_tbl, ...
                current_gcamp_folders_group, ...
                current_animal_group, current_ages_group, ...
                data, fields);
            
            % 2) Puis les cellules bleues
            [data, fields] = process_blue_cells( ...
                gcamp_output_folders, include_blue_cells, ...
                date_group_paths, ...
                current_gcamp_folders_group, current_red_folders_group, current_blue_folders_group, current_green_folders_group, ...
                current_blue_TSeries_path, ...
                meanImgs_gcamp, ...
                data, fields);
        
            % 3) Combinaison GCaMP + bleu
            [data, fields] = combined_gcamp_blue_cells( ...
                gcamp_output_folders, current_gcamp_folders_group, ...
                data, fields);

            selected_groups(k).data = data;
        else
            data = selected_groups(k).data;
        end

        % Performing motion_energy
        avg_block = 5; % Moyenne toutes les 5 frames
        [motion_energy_group, avg_motion_energy_group]  = load_or_process_movie(current_gcamp_TSeries_path, gcamp_output_folders, avg_block);      
            
        if ~isempty(checking_choice2)
            [~, selected_gcamp_neurons_original, selected_blue_neurons_original, suite2p] = data_checking(data, gcamp_output_folders, current_gcamp_folders_group, ...
                  current_animal_group, current_dates_group, ...
                  current_ages_group, meanImgs_gcamp, checking_choice2);

            checked_indices = find(~cellfun(@isempty, selected_gcamp_neurons_original) | ~cellfun(@isempty, selected_blue_neurons_original)); % Indices des dossiers avec des neurones sélectionnés
            
            build_rasterplot_checking(data, gcamp_output_folders, current_animal_group, current_ages_group, avg_motion_energy_group);
        end
        
        build_rasterplot(data, gcamp_output_folders, current_animal_group, current_ages_group, avg_motion_energy_group)
        
        %Global analysis of activity
        % [results_analysis, plots_data] = compute_export_basic_metrics( ...
        %     current_animal_group, ...
        %     data, ...
        %     gcamp_output_folders, ...
        %     current_xml_group, ...
        %     current_gcamp_folders_group, ...
        %     current_gcamp_folders_names_group, ...
        %     current_ages_group, ...
        %     current_animal_type, ...
        %     daytime);
        % 
        % results_analysis_all{k} = results_analysis;
        % plots_data_all{k}       = plots_data;

    end    
end
