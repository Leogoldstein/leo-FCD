function [selected_groups, sampling_rate_group] = process_selected_group( ...
    selected_groups, metadata_results, checking_choice2, include_blue_cells)

    % Récupérer daytime depuis selected_groups si déjà créé dans le pipeline
    if isfield(selected_groups, 'daytime') && ~isempty(selected_groups) && ~isempty(selected_groups(1).daytime)
        daytime = selected_groups(1).daytime;
    else
        currentDatetime = datetime('now');
        daytime = datestr(currentDatetime, 'yy_mm_dd_HH_MM');
    end

    fields = {};
    sampling_rate_group = [];

    % Perform analyses for each group
    for k = 1:length(selected_groups)
        current_animal_group   = selected_groups(k).animal_group;
        current_animal_type    = selected_groups(k).animal_type;
        current_ani_path_group = selected_groups(k).path;
        current_dates_group    = selected_groups(k).dates;
        current_ages_group     = selected_groups(k).ages;

        %===================%
        %   Paths by date
        %===================%
        date_group_paths = cell(length(current_dates_group), 1);
        for l = 1:length(current_dates_group)
            date_group_paths{l} = fullfile(current_ani_path_group, current_dates_group{l});
        end

        %===================%
        %   TSeries paths
        %===================%
        current_TSeries_group = selected_groups(k).pathTSeries;

        if size(current_TSeries_group, 2) < 4
            tmp = cell(size(current_TSeries_group, 1), 4);
            tmp(:, 1:size(current_TSeries_group, 2)) = current_TSeries_group;
            current_TSeries_group = tmp;
        end

        current_gcamp_TSeries_path = current_TSeries_group(:, 1);
        current_red_TSeries_path   = current_TSeries_group(:, 2);
        current_blue_TSeries_path  = current_TSeries_group(:, 3);
        current_green_TSeries_path = current_TSeries_group(:, 4);

        %===================%
        %   Fallmat paths
        %===================%
        if isfield(selected_groups, 'Fallmat_paths') && ~isempty(selected_groups(k).Fallmat_paths)
            current_fallmat_group = selected_groups(k).Fallmat_paths;
        else
            current_fallmat_group = cell(size(current_TSeries_group));
        end

        if size(current_fallmat_group, 2) < 4
            tmp = cell(size(current_fallmat_group, 1), 4);
            tmp(:, 1:size(current_fallmat_group, 2)) = current_fallmat_group;
            current_fallmat_group = tmp;
        end

        current_gcamp_fallmat_group = current_fallmat_group(:, 1);
        current_red_fallmat_group   = current_fallmat_group(:, 2);
        current_blue_fallmat_group  = current_fallmat_group(:, 3);
        current_green_fallmat_group = current_fallmat_group(:, 4);

        %===================%
        %   Suite2p folders
        %===================%
        if isfield(selected_groups, 'suite2p_folder') && ~isempty(selected_groups(k).suite2p_folder)
            current_suite2p_group = selected_groups(k).suite2p_folder;
        else
            current_suite2p_group = cell(size(current_TSeries_group));
        end

        if size(current_suite2p_group, 2) < 4
            tmp = cell(size(current_suite2p_group, 1), 4);
            tmp(:, 1:size(current_suite2p_group, 2)) = current_suite2p_group;
            current_suite2p_group = tmp;
        end

        current_gcamp_folders_group = current_suite2p_group(:, 1);
        current_red_folders_group   = current_suite2p_group(:, 2);
        current_blue_folders_group  = current_suite2p_group(:, 3);
        current_green_folders_group = current_suite2p_group(:, 4);

        %===================%
        %   Cas JM
        %===================%
        if strcmp(current_animal_type, 'jm')
            current_red_TSeries_path   = cell(size(current_gcamp_TSeries_path));
            current_blue_TSeries_path  = cell(size(current_gcamp_TSeries_path));
            current_green_TSeries_path = cell(size(current_gcamp_TSeries_path));

            current_red_fallmat_group   = cell(size(current_gcamp_fallmat_group));
            current_blue_fallmat_group  = cell(size(current_gcamp_fallmat_group));
            current_green_fallmat_group = cell(size(current_gcamp_fallmat_group));

            current_red_folders_group   = cell(size(current_gcamp_folders_group));
            current_blue_folders_group  = cell(size(current_gcamp_folders_group));
            current_green_folders_group = cell(size(current_gcamp_folders_group));
        end

        %===================%
        %   XML
        %===================%
        current_xml_group = selected_groups(k).xml;

        %===================%
        %   Output folders
        %===================%
        if isfield(selected_groups, 'gcamp_output_folders') && ~isempty(selected_groups(k).gcamp_output_folders)
            gcamp_output_folders = selected_groups(k).gcamp_output_folders;
        else
            error(['gcamp_output_folders manquant pour le groupe %s. ' ...
                   'Assure-toi que create_gcamp_output_folders a été appelée avant process_selected_group.'], ...
                   current_animal_group);
        end
        
        gcamp_root_folders = selected_groups(k).gcamp_root_folders;
        
   
        %===================%
        %   Metadata / sync
        %===================%
        meta_tbl = metadata_results{k};

        [sampling_rate_group, synchronous_frames_group] = fill_sampling_and_sync_frames( ...
            gcamp_root_folders, current_xml_group, meta_tbl, 0.2);

        %===================%
        %   Mean images
        %===================%
        meanImgs_gcamp = save_mean_images( ...
            'GCaMP', current_animal_group, current_ages_group, ...
            gcamp_output_folders, current_gcamp_folders_group);

        meanImgs_blue = save_mean_images( ...
            'Electroporated', current_animal_group, current_ages_group, ...
            gcamp_output_folders, current_blue_folders_group);

        %===================%
        %   Motion energy
        %===================%
        avg_block = 5;
        [motion_energy_group, motion_energy_smooth_group, ...
         avg_active_motion_onsets_group, avg_active_motion_offsets_group, ...
         active_motion_onsets_group, active_motion_offsets_group, speed_active_group] = ...
            load_or_process_movie( ...
                current_gcamp_TSeries_path, ...
                gcamp_root_folders, ...
                avg_block, ...
                sampling_rate_group, ...
                current_animal_group);

        %===================%
        %   GCaMP cells
        %===================%
        if ~isfield(data,'F_gcamp_by_plane') || is_nested_cell_empty(data.F_gcamp_by_plane)

            [data, fields] = process_gcamp_cells( ...
                gcamp_output_folders, ...
                current_gcamp_fallmat_group, ...
                meanImgs_gcamp, ...
                data, fields);
        
            selected_groups(k).data = data;
        end

        %===================%
        %   Blue cells
        %===================%
        if ~isfield(data,'F_blue_by_plane') || is_nested_cell_empty(data.F_blue_by_plane)

            [data, fields] = process_blue_cells( ...
                gcamp_output_folders, include_blue_cells, ...
                date_group_paths, current_blue_TSeries_path, ...
                current_gcamp_folders_group, current_red_folders_group, ...
                current_blue_folders_group, current_green_folders_group, ...
                meanImgs_gcamp, ...
                data, fields);

            selected_groups(k).data = data;
        end

        %===================%
        %   Combined GCaMP + blue
        %===================%
        if ~isfield(data,'F_combined_by_plane') || is_nested_cell_empty(data.F_combined_by_plane)
            [data, fields] = combined_gcamp_blue_cells( ...
                gcamp_output_folders, data, fields);        
            
            selected_groups(k).data = data;
        end

        %===================%
        %   Peak detection
        %===================%
        if ~isfield(data,'DF_gcamp_by_plane') || is_nested_cell_empty(data.DF_gcamp_by_plane)
            [data, fields] = run_gcamp_peak_detection( ...
                gcamp_output_folders, ...
                meta_tbl, ...
                sampling_rate_group, synchronous_frames_group, ...
                current_animal_group, current_ages_group, ...
                data, fields, meanImgs_gcamp, ...
                current_gcamp_TSeries_path, speed_active_group);

            selected_groups(k).data = data;
        end

        %===================%
        %   Optional checking
        %===================%
        if ~isempty(checking_choice2)
            [~, selected_gcamp_neurons_original, selected_blue_neurons_original, suite2p] = ...
                data_checking( ...
                    data, gcamp_output_folders, current_gcamp_TSeries_path, ...
                    current_animal_group, current_dates_group, ...
                    current_ages_group, meanImgs_gcamp, checking_choice2);

            checked_indices = find( ...
                ~cellfun(@isempty, selected_gcamp_neurons_original) | ...
                ~cellfun(@isempty, selected_blue_neurons_original)); %#ok<NASGU>

            build_rasterplot_checking( ...
                data, gcamp_output_folders, current_animal_group, ...
                current_ages_group, motion_energy_smooth_group);
        end

        %===================%
        %   Rasterplot
        %===================%
        if ~isempty(data.DF_gcamp_by_plane)
            build_rasterplot( ...
                data, gcamp_output_folders, current_animal_group, ...
                current_ages_group, sampling_rate_group, ...
                motion_energy_smooth_group, speed_active_group);
    
            %===================%
            %   Pairwise correlation
            %===================%
            data = load_or_process_corr_data( ...
                gcamp_root_folders, data, ...
                current_ages_group, current_animal_group);
    
            %===================%
            %   SCEs
            %===================%
            data = load_or_process_sce_data( ...
                current_animal_group, current_dates_group, ...
                gcamp_root_folders, synchronous_frames_group, data);
    
            % Stockage dans selected_groups
            selected_groups(k).data = data;
        end
    end
end


function tf = is_nested_cell_empty(C)
% IS_NESTED_CELL_EMPTY
% Retourne true si une cell imbriquée (niveau 1 ou 2) ne contient
% aucune donnée non vide.
%
% Supporte :
%   - {}
%   - {m}
%   - {m}{p}
%
% Usage :
%   tf = is_nested_cell_empty(data.F_gcamp_by_plane)

    tf = true;

    % Cas trivial
    if isempty(C)
        return;
    end

    % Si ce n'est pas une cell → on teste directement
    if ~iscell(C)
        tf = isempty(C);
        return;
    end

    % Parcours niveau 1
    for i = 1:numel(C)

        level1 = C{i};

        if isempty(level1)
            continue;
        end

        % Si niveau 2 (cell dans cell)
        if iscell(level1)

            for j = 1:numel(level1)
                if ~isempty(level1{j})
                    tf = false;
                    return;
                end
            end

        else
            % Donnée directe non vide
            tf = false;
            return;
        end
    end
end