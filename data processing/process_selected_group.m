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

        % Convert folders and folder names to string arrays
        current_gcamp_TSeries_path = cellfun(@string, selected_groups(k).pathTSeries(:, 1), 'UniformOutput', false);
    
        if ~strcmp(current_animal_type, 'jm')
            current_gcamp_folders_group = cellfun(@string, selected_groups(k).folders(:, 1), 'UniformOutput', false);
            current_red_folders_group   = cellfun(@string, selected_groups(k).folders(:, 2), 'UniformOutput', false);
            current_blue_folders_group  = cellfun(@string, selected_groups(k).folders(:, 3), 'UniformOutput', false);
            current_green_folders_group = cellfun(@string, selected_groups(k).folders(:, 4), 'UniformOutput', false);
        
            current_gcamp_folders_names_group  = selected_groups(k).folders_names(:, 1);
            current_red_folders_names_group    = selected_groups(k).folders_names(:, 2);
            current_blue_folders_names_group   = selected_groups(k).folders_names(:, 3);
            current_green_folders_names_group  = selected_groups(k).folders_names(:, 4);
        else    
            % JM case : on reconstitue la même structure
            current_gcamp_folders_group = selected_groups(k).folders;
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
                % Red/Blue/Green non utilisés → vides
                current_red_folders_group{l}   = [];
                current_blue_folders_group{l}  = [];
                current_green_folders_group{l} = [];
                current_red_folders_names_group{l}   = [];
                current_blue_folders_names_group{l}  = [];
                current_green_folders_names_group{l} = [];
            end
        end
        
        % --- Création uniforme de folders_groups ---
        folders_groups = {
            [current_gcamp_folders_group, current_gcamp_folders_names_group], ...
            [current_red_folders_group,   current_red_folders_names_group], ...
            [current_blue_folders_group,  current_blue_folders_names_group], ...
            [current_green_folders_group, current_green_folders_names_group]
        };
        assignin('base', 'folders_groups', folders_groups);
        current_env_group = selected_groups(k).env;
        
        currentDatetime = datetime('now');
        daytime = datestr(currentDatetime, 'yy_mm_dd_HH_MM');
        gcamp_output_folders = create_base_folders(date_group_paths, current_gcamp_folders_names_group, daytime, processing_choice1, processing_choice2, current_animal_group);     
        
        % for m = 1:length(gcamp_output_folders)
        %     folder_path = gcamp_output_folders{m};
        %     parent_fig = fileparts(folder_path);  % dossier parent
        % 
        %     %Lister tous les fichiers et dossiers à l'intérieur de parent_fig
        %     contents = dir(parent_fig);
        %     contents = contents(~ismember({contents.name}, {'.','..'})); % exclure . et ..
        % 
        %     %Supprimer chaque élément sauf folder_path lui-même
        %     for i = 1:length(contents)
        %         item_path = fullfile(parent_fig, contents(i).name);
        %         if strcmp(item_path, folder_path)
        %             continue; % ne rien faire pour folder_path
        %         end
        %         if contents(i).isdir
        %             %Supprimer le sous-dossier et son contenu
        %             rmdir(item_path, 's');
        %         else
        %             %Supprimer le fichier
        %             delete(item_path);
        %         end
        %     end
        % 
        %     fprintf('Contenu de %s supprimé (sauf %s).\n', parent_fig, folder_path);
        % end

        % Preprocess and process data
        data = load_or_process_raster_data(gcamp_output_folders, current_gcamp_folders_group, current_env_group, folders_groups, current_blue_folders_group, date_group_paths, current_gcamp_TSeries_path, include_blue_cells);                    
        
        % Performing mean images
        meanImgs_gcamp = save_mean_images(current_animal_group, current_dates_group, current_ages_group, gcamp_output_folders, current_gcamp_folders_group);

        % Performing motion_energy
        avg_block = 5; % Moyenne toutes les 5 frames
        [motion_energy_group, avg_motion_energy_group]  = load_or_process_movie(date_group_paths, gcamp_output_folders, avg_block);      
            
        if ~isempty(checking_choice2)
            
            %plot_random_F_and_DF(data, current_animal_group, current_ages_group);
            [~, selected_gcamp_neurons_original, selected_blue_neurons_original] = data_checking(data, gcamp_output_folders, current_gcamp_folders_group, current_animal_group, current_dates_group, current_ages_group, meanImgs_gcamp, checking_choice2);

            checked_indices = find(~cellfun(@isempty, selected_gcamp_neurons_original) | ~cellfun(@isempty, selected_blue_neurons_original)); % Indices des dossiers avec des neurones sélectionnés
                                                   
            if ~isempty(checked_indices)            
                % Filtrer les variables d'input en fonction de checked_indices
                folders_groups = {
                    [current_gcamp_folders_group(checked_indices), current_gcamp_folders_names_group(checked_indices)],  % Group gCamp
                    [current_red_folders_group(checked_indices),   current_red_folders_names_group(checked_indices)],    % Group Red
                    [current_blue_folders_group(checked_indices),  current_blue_folders_names_group(checked_indices)],   % Group Blue
                    [current_green_folders_group(checked_indices), current_green_folders_names_group(checked_indices)]   % Group Green
                };
                
                bad_gcamp_ind_list = selected_gcamp_neurons_original(checked_indices);
                bad_blue_ind_list = selected_blue_neurons_original(checked_indices);
                data = load_or_process_raster_data(gcamp_output_folders(checked_indices), current_gcamp_folders_group(checked_indices), current_env_group(checked_indices), folders_groups, current_blue_folders_group(checked_indices), date_group_paths(checked_indices), current_gcamp_TSeries_path(checked_indices), include_blue_cells, bad_gcamp_ind_list, bad_blue_ind_list, suite2p);                    
            end

            build_rasterplot_checking(data, gcamp_output_folders, current_animal_group, current_ages_group, avg_motion_energy_group);
        end
        
        build_rasterplot(data, gcamp_output_folders, current_animal_group, current_ages_group, avg_motion_energy_group)
       
        % Store processed data in selected_groups for this group
        selected_groups(k).gcamp_output_folders = gcamp_output_folders;
        selected_groups(k).current_blue_folders_group = current_blue_folders_group;
        selected_groups(k).data = data;        
    end
end

%% HELPER FUNCTIONS

function data = init_data_struct(numFolders, fields)
    % Crée une structure avec les champs spécifiés et initialise chaque cellule à []
    data = struct();
    for f = 1:length(fields)
        data.(fields{f}) = cell(numFolders, 1);
        [data.(fields{f}){:}] = deal([]);
    end
end

function value = getFieldOrDefault(structure, fieldName, defaultValue)
    if isfield(structure, fieldName)
        value = structure.(fieldName);
    else
        value = defaultValue;
    end
end


function data = load_or_process_raster_data(gcamp_output_folders, current_gcamp_folders_group, current_env_group, folders_groups, current_blue_folders_group, date_group_paths, current_gcamp_TSeries_path, include_blue_cells, bad_gcamp_ind_list, bad_blue_ind_list, suite2p)
    
    if nargin < 9
        bad_gcamp_ind_list = cell(size(gcamp_output_folders));  % cellule vide
    end

    if nargin < 10
        bad_blue_ind_list = cell(size(gcamp_output_folders));  % cellule vide
    end

    if nargin < 11
        suite2p = false;
    end

    numFolders = length(gcamp_output_folders);

    % Définir tous les champs dans une seule structure
    fields = {'F_gcamp', 'DF_gcamp', 'iscell', 'sampling_rate', 'synchronous_frames', ...
              'isort1_gcamp', 'isort2_gcamp', 'Sm_gcamp', ...
              'thresholds_gcamp', 'Acttmp2_gcamp', 'Raster_gcamp', 'MAct_gcamp', ...
              'outlines_gcampx', 'outlines_gcampy', 'gcamp_mask', 'gcamp_props', 'imageHeight', 'imageWidth', ...
              'outlines_gcampx_false', 'outlines_gcampy_false', 'gcamp_mask_false', 'gcamp_props_false', ...
              'matched_gcamp_idx', 'matched_cellpose_idx', 'num_cells_mask', 'mask_cellpose', 'props_cellpose', 'outlines_x_cellpose', 'outlines_y_cellpose', ...
              'F_blue', 'F_gcamp_not_blue', 'DF_blue', 'DF_gcamp_not_blue', ...
              'thresholds_blue', 'Acttmp2_blue', 'MAct_blue', 'Raster_blue', ...         
              'F_combined', 'DF_combined', 'blue_indices_combined', ...
              'isort1_combined', ...
              'thresholds_combined', 'Acttmp2_combined', 'MAct_combined', 'Raster_combined'};

    % Initialisation
    data = init_data_struct(numFolders, fields);

    numChannels = length(folders_groups);

    for m = 1:numFolders

        filePath = fullfile(gcamp_output_folders{m}, 'results.mat'); 

        %delete(filePath)

        %Si l'utilisateur a modifié le fichier source lors du data_checking, reprocesser les données
        if suite2p
            removeFieldsByName(filePath, {'F_gcamp:gcamp_props'});
        end

        % Charger les données existantes si elles existent
        if exist(filePath, 'file') == 2
            loaded = load(filePath);
            for f = 1:length(fields)
                data.(fields{f}){m} = getFieldOrDefault(loaded, fields{f}, []);
            end
        end
        
        % Sampling rate et synchronous_frames
        if isempty(data.sampling_rate{m})
            [~, sampling_rate, ~, ~] = find_key_value(current_env_group{m});
            data.sampling_rate{m} = sampling_rate;
        end
        if isempty(data.synchronous_frames{m})
            data.synchronous_frames{m} = round(0.2 * data.sampling_rate{m});
        end
        
        % Traitement GCaMP
        if isempty(data.DF_gcamp{m})
            [~, F_gcamp, F_deconv_gcamp, ~, stat, iscell, stat_false, iscell_false] = load_data(current_gcamp_folders_group{m});
            [~, ~, noise_est_gcamp, SNR_gcamp, DF_gcamp, Raster_gcamp, Acttmp2_gcamp, MAct_gcamp, thresholds_gcamp] = peak_detection_tuner(F_gcamp, data.sampling_rate{m}, data.synchronous_frames{m}, 'nogui', true);

            save(filePath, 'F_gcamp', 'F_deconv_gcamp', 'iscell', 'DF_gcamp', 'thresholds_gcamp', 'Acttmp2_gcamp', 'MAct_gcamp', 'Raster_gcamp');

            data.F_gcamp{m} = F_gcamp;
            data.iscell{m} = iscell;
            data.DF_gcamp{m} = DF_gcamp;
            data.thresholds_gcamp{m} = thresholds_gcamp;
            data.Acttmp2_gcamp{m} = Acttmp2_gcamp;
            data.Raster_gcamp{m} = Raster_gcamp;
            data.MAct_gcamp{m} = MAct_gcamp;

            [NCell, outlines_gcampx, outlines_gcampy, ~, ~, ~] = load_calcium_mask(iscell, stat);
            [gcamp_mask, gcamp_props, imageHeight, imageWidth] = process_poly2mask(stat, NCell, outlines_gcampx, outlines_gcampy);

            save(filePath, 'outlines_gcampx', 'outlines_gcampy', 'gcamp_mask','gcamp_props', 'imageHeight', 'imageWidth', '-append');

            data.outlines_gcampx{m} = outlines_gcampx;
            data.outlines_gcampy{m} = outlines_gcampy;
            data.gcamp_mask{m} = gcamp_mask;
            data.gcamp_props{m} = gcamp_props;

            [NCell, outlines_gcampx_false, outlines_gcampy_false, ~, ~, ~] = load_calcium_mask(iscell_false, stat_false);
            [gcamp_mask_false, gcamp_props_false, ~, ~] = process_poly2mask(stat_false, NCell, outlines_gcampx_false, outlines_gcampy_false);

            save(filePath, 'outlines_gcampx_false', 'outlines_gcampy_false', 'gcamp_mask_false','gcamp_props_false', '-append');

            data.outlines_gcampx_false{m} = outlines_gcampx_false;
            data.outlines_gcampy_false{m} = outlines_gcampy_false;
            data.gcamp_mask_false{m} = gcamp_mask_false;
            data.gcamp_props_false{m} = gcamp_props_false;

      elseif ~isempty(bad_gcamp_ind_list{m})

            bad_gcamp_inds = bad_gcamp_ind_list{m};
            data.F_gcamp{m}(bad_gcamp_inds) = [];
            data.DF_gcamp{m}(bad_gcamp_inds) = [];
            data.iscell{m}(bad_gcamp_inds) = [];
            data.thresholds_gcamp{m}(bad_gcamp_inds) = [];
            data.Acttmp2_gcamp{m}(bad_gcamp_inds) = [];
            data.Raster_gcamp{m}(bad_gcamp_inds) = [];
            data.outlines_gcampx{m}(bad_gcamp_inds) = [];
            data.outlines_gcampy{m}(bad_gcamp_inds) = [];
            data.gcamp_mask{m}(bad_gcamp_inds) = [];
            data.gcamp_props{m}(bad_gcamp_inds) = [];

            F_gcamp = data.F_gcamp{m};
            DF_gcamp = data.DF_gcamp{m};
            iscell = data.iscell{m};
            Raster_gcamp = data.Raster_gcamp{m};
            Acttmp2_gcamp = data.Acttmp2_gcamp{m};
            thresholds_gcamp = data.thresholds_gcamp{m};
            outlines_gcampx = data.outlines_gcampx{m};
            outlines_gcampy = data.outlines_gcampy{m};
            gcamp_mask = data.gcamp_mask{m};
            gcamp_props = data.gcamp_props{m};

            % recalculer MAct car il faut repartir du Raster modifié
            Nz = size(Raster_gcamp,2);
            MAct_gcamp = zeros(1, Nz - synchronous_frames);
            for i = 1:(Nz - synchronous_frames)
                MAct_gcamp(i) = sum(max(Raster_gcamp(:, i:i+synchronous_frames), [], 2));
            end

            removeFieldsByName(filePath, {'F_gcamp:gcamp_props'});

            save(filePath, 'F_gcamp', 'iscell', 'DF_gcamp',  ...
                'Raster_gcamp', 'Acttmp2_gcamp', 'thresholds_gcamp', 'MAct_gcamp', ...
                'outlines_gcampx', 'outlines_gcampy', 'gcamp_mask','gcamp_props', '-append');
        end

        if isempty(data.isort1_gcamp{m})
            [~, ~, ~, ops, ~, ~, ~, ~] = load_data(current_gcamp_folders_group{m});
            [isort1_gcamp, isort2_gcamp, Sm_gcamp] = raster_processing(data.DF_gcamp{m}, current_gcamp_folders_group{m}, ops);

            save(filePath, 'isort1_gcamp','isort2_gcamp', 'Sm_gcamp', '-append');

            if ~isempty(bad_gcamp_ind_list{m})
                badIdx = bad_gcamp_ind_list{m};
                save(filePath, 'badIdx', '-append');
            end

            data.isort1_gcamp{m} = isort1_gcamp;
            data.isort2_gcamp{m} = isort2_gcamp;
            data.Sm_gcamp{m} = Sm_gcamp;
        end      

        % Traitement cellules bleues
        if strcmp(include_blue_cells, '1')
            if isempty(data.num_cells_mask{m})
                disp(['Processing blue cells folder ', num2str(m), '...']);
    
                % Charger ou traiter les données Cellpose
                disp('Upload or process Cellpose data...');
                [~, aligned_image, npy_file_path, meanImg_channels] = load_or_process_cellpose_TSeries(filePath, folders_groups, date_group_paths{m}, numChannels, m);
    
                if ~isempty(npy_file_path)
                    [num_cells_mask, mask_cellpose, props_cellpose, outlines_x_cellpose, outlines_y_cellpose] = load_or_process_cellpose_data(npy_file_path);
                else
                    fprintf('Skipping group %d: no Cellpose output.\n', m);
                    continue;
                end
    
                % Vérifications importantes
                if isempty(data.gcamp_props{m}) || isempty(props_cellpose)
                    fprintf('Skipping group %d: No centroids found.\n', m);
                    continue;
                end
    
                if isempty(meanImg_channels)
                    fprintf('Skipping group %d: meanImg is empty.\n', m);
                    continue;
                end
    
                if isa(meanImg_channels, 'single')
                    meanImg_channels = uint16(meanImg_channels);
                end
    
                disp('Extracting fluorescence from cellpose masks...');
                % Affichage et correspondance des masques
                R = 5;
                [matched_gcamp_idx, matched_cellpose_idx] = show_masks_and_overlaps(...
                    data.gcamp_props{m}, data.gcamp_props_false{m}, props_cellpose, meanImg_channels, aligned_image, ... 
                    data.outlines_gcampx{m}, data.outlines_gcampy{m}, data.outlines_gcampx_false{m}, data.outlines_gcampy_false{m}, ...
                    outlines_x_cellpose, outlines_y_cellpose, R, m, gcamp_output_folders);
    
                % Extraire les traces fluorescence
                F_gcamp_not_blue = data.F_gcamp{m};
                DF_gcamp_not_blue = data.DF_gcamp{m};
    
                % on enlève les lignes dont les indices apparaissent dans matched_gcamp_idx
                used_gcamp_indices = unique(matched_gcamp_idx);
                F_gcamp_not_blue(used_gcamp_indices, :) = [];
                DF_gcamp_not_blue(used_gcamp_indices, :) = [];
    
                currentTSeriesPath = current_gcamp_TSeries_path{m};
                F_blue = get_blue_cells_rois(data.F_gcamp{m}, matched_cellpose_idx, num_cells_mask, mask_cellpose, currentTSeriesPath);            
    
                save(filePath, 'matched_gcamp_idx', 'matched_cellpose_idx', 'num_cells_mask', 'mask_cellpose', 'props_cellpose', 'outlines_x_cellpose', 'outlines_y_cellpose', ...
                                'F_blue', 'F_gcamp_not_blue', 'DF_gcamp_not_blue', '-append');
    
                data.matched_gcamp_idx{m} = matched_gcamp_idx;
                data.matched_cellpose_idx{m} = matched_cellpose_idx;
                data.num_cells_mask{m} = num_cells_mask;
                data.mask_cellpose{m} = mask_cellpose;
                data.props_cellpose{m} = props_cellpose;
                data.outlines_x_cellpose{m} = outlines_x_cellpose;
                data.outlines_y_cellpose{m} = outlines_y_cellpose;
                data.F_blue{m} = F_blue;
                data.F_gcamp_not_blue{m} = F_gcamp_not_blue;
                data.DF_gcamp_not_blue{m} = DF_gcamp_not_blue;
    
            end
    
            %removeFieldsByName(filePath, {'DF_blue'});
    
            if isempty(data.DF_blue{m})
    
                [~, ~, noise_est_blue, SNR_blue, DF_blue, Raster_blue, Acttmp2_blue, MAct_blue, thresholds_blue] = peak_detection_tuner(data.F_blue{m}, data.sampling_rate{m}, data.synchronous_frames{m}, 'nogui', false);
    
                save(filePath, 'DF_blue', 'Raster_blue', 'Acttmp2_blue', 'thresholds_blue', '-append');
    
                data.DF_blue{m} = DF_blue;        
                data.thresholds_blue{m} = thresholds_blue;
                data.Acttmp2_blue{m} = Acttmp2_blue;
                data.Raster_blue{m} = Raster_blue;
                data.MAct_blue{m} = MAct_blue;
    
            elseif ~isempty(bad_blue_ind_list{m})
                    N_gcamp = size(data.DF_gcamp_not_blue{m},1);
                    blue_indices_original = bad_blue_ind_list{m} - N_gcamp; % cf. ligne 411
    
                    % Retirer ces neurones de toutes les structures Cellpose
                    data.num_cells_mask{m}(blue_indices_original) = [];
                    data.mask_cellpose{m}(blue_indices_original) = [];
                    data.props_cellpose{m}(blue_indices_original) = [];
                    data.outlines_x_cellpose{m}(blue_indices_original) = [];
                    data.outlines_y_cellpose{m}(blue_indices_original) = [];
    
                    % Recalculer matched_gcamp_idx et matched_cellpose_idx basé sur les nouvelles matrices (indices ont changé si bad_gcamp_ind_list non vide)
                    R = 5;
                    [matched_gcamp_idx, matched_cellpose_idx] = show_masks_and_overlaps(...
                        data.gcamp_props{m}, data.gcamp_props_false{m}, props_cellpose, meanImg_channels, aligned_image, ...
                        data.outlines_gcampx{m}, data.outlines_gcampy{m}, data.outlines_gcampx_false{m}, data.outlines_gcampy_false{m}, ...
                        outlines_x_cellpose, outlines_y_cellpose, R, m, gcamp_output_folders);
    
                    % Extraire les traces fluorescence
                    F_gcamp_not_blue = data.F_gcamp{m};
                    DF_gcamp_not_blue = data.DF_gcamp{m};
    
                    % on enlève les lignes dont les indices apparaissent dans matched_gcamp_idx
                    used_gcamp_indices = unique(matched_gcamp_idx);
                    F_gcamp_not_blue(used_gcamp_indices, :) = [];
                    DF_gcamp_not_blue(used_gcamp_indices, :) = [];
    
                    data.F_gcamp_not_blue{m} = F_gcamp_not_blue;
                    data.DF_gcamp_not_blue{m} = DF_gcamp_not_blue;
    
                    % Retirer aussi de F_blue
                    data.F_blue{m}(blue_indices_original, :) = []; 
    
                    % Supprimer et remplacer par les nouvelles données
                    removeFieldsByName(filePath, {'matched_gcamp_idx:Raster_combined'});
    
                    num_cells_mask =  data.num_cells_mask{m};
                    mask_cellpose = data.mask_cellpose{m};
                    props_cellpose = data.props_cellpose{m};
                    outlines_x_cellpose = data.outlines_x_cellpose{m};
                    outlines_y_cellpose = data.outlines_y_cellpose{m};
    
                    save(filePath, 'matched_gcamp_idx', 'matched_cellpose_idx', 'num_cells_mask', 'mask_cellpose', 'props_cellpose', 'outlines_x_cellpose', 'outlines_y_cellpose', 'F_blue', 'F_gcamp_not_blue', 'DF_blue', 'DF_gcamp_not_blue', '-append');
    
                    [~, ~, noise_est_blue, SNR_blue, DF_blue, Raster_blue, Acttmp2_blue, MAct_blue, thresholds_blue] = peak_detection_tuner(F_blue, data.sampling_rate{m}, data.synchronous_frames{m}, 'nogui', true);
    
                    % Ajuster la longueur pour cohérence
                    min_cols = min(size(DF_gcamp_not_blue, 2), size(DF_blue, 2));
                    DF_gcamp_not_blue = DF_gcamp_not_blue(:, 1:min_cols);
                    DF_blue = DF_blue(:, 1:min_cols);
    
                    save(filePath, 'F_blue', 'F_gcamp_not_blue', 'DF_blue', 'DF_gcamp_not_blue', ...
                        'Raster_blue', 'Acttmp2_blue', 'thresholds_blue', '-append');
    
                    data.F_blue{m} = F_blue;
                    data.F_gcamp_not_blue{m} = F_gcamp_not_blue;
                    data.DF_blue{m} = DF_blue;
                    data.DF_gcamp_not_blue{m} = DF_gcamp_not_blue;
                    data.thresholds_blue{m} = thresholds_blue;
                    data.Acttmp2_blue{m} = Acttmp2_blue;
                    data.Raster_blue{m} = Raster_blue;
                    data.MAct_blue{m} = MAct_blue;
            end

            if ~isempty(data.DF_blue{m}) && isempty(data.F_combined{m})
    
                % Combinaison des traces fluorescence
                F_combined  = [data.F_gcamp_not_blue{m}; data.F_blue{m}];
                DF_combined = [data.DF_gcamp_not_blue{m}; data.DF_blue{m}];
    
                % Indices des cellules bleues dans la matrice combinée
                blue_indices_combined = (size(data.DF_gcamp_not_blue{m},1) + 1) : size(DF_combined,1);
    
                [isort1_combined, ~, ~] = raster_processing(DF_combined, current_gcamp_folders_group{m});
    
                % === Fusion Raster ===
                Raster_combined = [data.Raster_gcamp{m}; data.Raster_blue{m}];
                thresholds_combined = [data.thresholds_gcamp{m}(:); data.thresholds_blue{m}(:)];
                Acttmp2_combined = [data.Acttmp2_gcamp{m}(:);  data.Acttmp2_blue{m}(:)];
    
                % recalculer car il faut repartir du Raster global
                synchronous_frames = data.synchronous_frames{m};
                Nz = size(Raster_combined,2);
                MAct_combined = zeros(1, Nz - synchronous_frames);
                for i = 1:(Nz - synchronous_frames)
                    MAct_combined(i) = sum(max(Raster_combined(:, i:i+synchronous_frames), [], 2));
                end
    
                save(filePath, 'F_combined', 'DF_combined', 'blue_indices_combined', 'isort1_combined', 'thresholds_combined', 'Acttmp2_combined', 'MAct_combined', 'Raster_combined', '-append');
    
                % Mise à jour de la structure data
                data.F_combined{m} = F_combined;
                data.DF_combined{m} = DF_combined;
                data.blue_indices_combined{m} = blue_indices_combined;
                data.isort1_combined{m} = isort1_combined;
                data.thresholds_combined{m} = thresholds_combined;
                data.Acttmp2_combined{m} = Acttmp2_combined;
                data.Raster_combined{m} = Raster_combined;
                data.MAct_combined{m} = MAct_combined;
            end
        end
     end
end

function [motion_energy_group, avg_motion_energy_group] = load_or_process_movie(date_group_paths, gcamp_output_folders, avg_block)

    numFolders = length(date_group_paths);
    camFolders = cell(numFolders, 1);
    motion_energy_group = cell(numFolders, 1);
    avg_motion_energy_group = cell(numFolders, 1);

    % chemin vers Fiji (à modifier si nécessaire)
    fijiPath = 'C:\Users\goldstein\Fiji.app\fiji-windows-x64.exe';

    for m = 1:length(date_group_paths)

        camPath = fullfile(date_group_paths{m}, 'cam', 'Concatenated');
        cameraPath = fullfile(date_group_paths{m}, 'camera', 'Concatenated');

        if isfolder(camPath)
            camFolders{m} = camPath;
            fprintf('Found cam folder: %s\n', camPath);
        elseif isfolder(cameraPath)
            camFolders{m} = cameraPath;
            fprintf('Found camera folder: %s\n', cameraPath);
        else
            fprintf('No Camera images found in %s.\n', date_group_paths{m});
            continue;
        end
         
        filepath = fullfile(camFolders{m}, 'cam_crop.tif');

        if exist(filepath, 'file') == 2
            
            savePath = fullfile(gcamp_output_folders{m}, 'results_movie.mat'); 
    
            if exist(savePath, 'file') == 2 
                disp(['Loading file: ', savePath]);
                data = load(savePath);
                motion_energy = data.motion_energy;
    
            else
                %choice = input('Voulez-vous ouvrir le film dans Fiji pour cropper ? (1/2) ', 's');
                choice = '2';
                
                if strcmpi(choice, '1')
                    fprintf('Ouverture de %s dans Fiji...\n', filepath);
                    % Ouvrir Fiji avec le .tif
                    system(sprintf('"%s" "%s"', fijiPath, filepath));
                    
                    motion_energy = compute_motion_energy(filepath);
                    save(savePath, 'motion_energy');
                    
                elseif strcmpi(choice, '2')
                    %subchoice = input('Voulez-vous calculer la motion_energy sur le film tel quel ou passer ? (1/2) ', 's');
                    subchoice = 2;
                    if strcmpi(subchoice, '1')
                        motion_energy = compute_motion_energy(filepath);
                        save(savePath, 'motion_energy');
                    else
                        motion_energy = [];  % Ne pas calculer
                    end
                else
                    fprintf('Motion energy non calculée.\n');
                    motion_energy = [];
                end
            
                motion_energy_group{m} = motion_energy; 
            
                if ~isempty(motion_energy)
                    avg_motion_energy = average_frames(motion_energy, avg_block);  % ou 'trim'  
                    avg_motion_energy_group{m} = avg_motion_energy;
                else
                    avg_motion_energy_group{m} = [];
                end
            end

            motion_energy_group{m} = motion_energy; 
            if ~isempty(motion_energy)
                avg_motion_energy = average_frames(motion_energy, avg_block);  % ou 'trim'  
                avg_motion_energy_group{m} = avg_motion_energy;
            else
                avg_motion_energy_group{m} = [];
            end
        else
            fprintf('No movie found in %s.\n', camFolders{m});
            motion_energy_group{m} = [];
        end
    end
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
