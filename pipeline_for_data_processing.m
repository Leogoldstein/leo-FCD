 function pipeline_for_data_processing(selected_groups)
    % process_data generates and saves figures for raster plots, mean images, or SCE analysis
    % Inputs:
    % - PathSave: Path where results will be saved
    % - animal_date_list: Cell array containing animal information (type, group, animal, date, etc.)
    % - truedataFolders: List of paths to the true data folders
    
    PathSave = 'D:\after_processing\Presentations\';
    
    % Ask if the user wants to include blue cells in the analysis
    include_blue_cells = input('Do you want to include blue cells in your analysis? (1/2): ', 's');

    % Ask for analysis types, multiple choices separated by spaces
    analysis_choices_str = input('Choose analysis types (separated by spaces): mean images (1), raster plot (2), global analysis of activity (3), SCEs (4), clusters analysis (5), or code development (6)? ', 's');
    
    % Prompt for the first choice
    processing_choice1 = input('Do you want to process the most recent folder for processing (1/2)? ', 's');
    
    % Check if processing_choice1 is 'no'
    if strcmp(processing_choice1, '2')
        % If the answer is 'no', prompt for the second choice
        processing_choice2 = input('Do you want to select an existing folder or create a new one? (1/2): ', 's');
    else
        processing_choice2 = [];
    end
      
    % Convert the string of choices into an array of numbers
    analysis_choices = str2num(analysis_choices_str); %#ok<ST2NM>

    % Pre-allocate variables for global analysis (btw animals for all dates)
    num_groups = length(selected_groups);  % Nombre de groupes sélectionnés
    all_DF_groups = cell(num_groups, 1);
    all_Raster_groups = cell(num_groups, 1);
    all_sampling_rate_groups = cell(num_groups, 1);
    all_Race_groups = cell(num_groups, 1);
    all_TRace_groups = cell(num_groups, 1);
    all_sces_distances_groups = cell(num_groups, 1);
    all_RasterRace_groups = cell(num_groups, 1);
    current_group_paths = cell(num_groups, 1);
    all_max_corr_gcamp_gcamp_groups = cell(num_groups, 1);
    all_max_corr_gcamp_mtor_groups = cell(num_groups, 1);
    all_max_corr_mtor_mtor_groups = cell(num_groups, 1);

    % Perform analyses
    for k = 1:length(selected_groups)
        current_animal_group = selected_groups(k).animal_group;
        current_animal_type = selected_groups(k).animal_type;
        current_ani_path_group = selected_groups(k).path;
        current_dates_group = selected_groups(k).dates;
        date_group_paths = cell(length(current_dates_group), 1);  % Store paths for each date
        for l = 1:length(current_dates_group)
            date_path = fullfile(current_ani_path_group, current_dates_group{l});
            date_group_paths{l} = date_path;
        end
        
        % Convertir les dossiers et les noms de dossiers en cellules de chaînes
        current_gcamp_TSeries_path = cellfun(@string, selected_groups(k).pathTSeries(:, 1), 'UniformOutput', false);

        current_gcamp_folders_group = cellfun(@string, selected_groups(k).folders(:, 1), 'UniformOutput', false);
        current_red_folders_group = cellfun(@string, selected_groups(k).folders(:, 2), 'UniformOutput', false);
        current_blue_folders_group = cellfun(@string, selected_groups(k).folders(:, 3), 'UniformOutput', false);
        current_green_folders_group = cellfun(@string, selected_groups(k).folders(:, 4), 'UniformOutput', false);
        
        current_gcamp_folders_names_group = cellfun(@string, selected_groups(k).folders_names(:, 1), 'UniformOutput', false);
        current_red_folders_names_group = cellfun(@string, selected_groups(k).folders_names(:, 2), 'UniformOutput', false);
        current_blue_folders_names_group = cellfun(@string, selected_groups(k).folders_names(:, 3), 'UniformOutput', false);
        current_green_folders_names_group = cellfun(@string, selected_groups(k).folders_names(:, 4), 'UniformOutput', false);
        
        folders_groups = {
            [current_gcamp_folders_group, current_gcamp_folders_names_group],  % Group gCamp
            [current_red_folders_group, current_red_folders_names_group],      % Group Red
            [current_blue_folders_group, current_blue_folders_names_group],    % Group Blue
            [current_green_folders_group, current_green_folders_names_group]   % Group Green
        };
        assignin('base', 'folders_groups', folders_groups);
   
        current_ages_group = selected_groups(k).ages;
        current_env_group = selected_groups(k).env;
        
        currentDatetime = datetime('now');
        daytime = datestr(currentDatetime, 'yy_mm_dd_HH_MM');
        [gcamp_output_folders, blue_output_folders] = create_base_folders(date_group_paths, current_gcamp_folders_names_group, current_blue_folders_names_group, daytime, processing_choice1, processing_choice2, current_animal_group);     
        assignin('base', 'gcamp_output_folders', gcamp_output_folders);
        assignin('base', 'blue_output_folders', blue_output_folders);

        % Create the new path for the Excel file with the modified title
        pathexcel = [PathSave 'analysis.xlsx'];

        % Loop through each selected analysis choice
        for i = 1:length(analysis_choices)
            analysis_choice = analysis_choices(i);  % Get the current analysis choice
            
            switch analysis_choice
                case 1
                    disp(['Performing mean images for ', current_animal_group]);                
                    all_ops = load_ops(current_gcamp_folders_group);
                    save_mean_images(current_animal_group, all_ops, current_dates_group, gcamp_output_folders, current_ages_group);
                    
                    case 2
                        disp(['Performing raster plot analysis for ', current_animal_group]);
                        [gcamp_data, mtor_data, all_data] = load_or_process_raster_data(gcamp_output_folders, current_gcamp_folders_group, current_env_group, include_blue_cells, folders_groups, blue_output_folders, date_group_paths, current_gcamp_TSeries_path, analysis_choice);                    
                        assignin('base', 'gcamp_data', gcamp_data);

                        if strcmpi(include_blue_cells, '1')
                            build_rasterplot(gcamp_data.DF, gcamp_data.isort1, gcamp_data.MAct, gcamp_output_folders, current_animal_group, current_ages_group, all_data.DF, all_data.isort1, all_data.blue_indices, mtor_data.MAct);
                            plot_DF(gcamp_data.DF, current_animal_group, current_ages_group, gcamp_output_folders, all_data.DF, all_data.blue_indices);
                        else
                            build_rasterplot(gcamp_data.DF, gcamp_data.isort1, gcamp_data.MAct, gcamp_output_folders, current_animal_group, current_ages_group); %all_data.DF, all_data.isort1, all_data.blue_indices, mtor_data.MAct
                            plot_DF(gcamp_data.DF, current_animal_group, current_ages_group, gcamp_output_folders) % all_data.DF, all_data.blue_indices
                            build_rasterplots(gcamp_data.DF, gcamp_data.isort1, gcamp_data.MAct, current_ani_path_group, current_animal_group, current_dates_group, current_ages_group);
                        end
    
                    case 3
                        disp(['Performing Global analysis of activity for ', current_animal_group]);
                        [all_recording_time, all_optical_zoom, all_position, all_time_minutes] = find_recording_infos(gcamp_output_folders, current_env_group);
                        [gcamp_data, mtor_data, ~] = load_or_process_raster_data(gcamp_output_folders, current_gcamp_folders_group, current_env_group, include_blue_cells, folders_groups, blue_output_folders, date_group_paths, current_gcamp_TSeries_path, analysis_choice);                                          
                        [~, ~, ~, ~, ~, all_imageHeight, all_imageWidth] = load_or_process_image_data(gcamp_output_folders, current_gcamp_folders_group);
                        [NCell_all, mean_frequency_per_minute_all, std_frequency_per_minute_all, cell_density_per_microm2_all, mean_max_corr_all] = basic_metrics(gcamp_data.DF, gcamp_data.Raster, gcamp_data.MAct, gcamp_output_folders, gcamp_data.sampling_rate, all_imageHeight, all_imageWidth);
                    
                        if strcmpi(include_blue_cells, '1')
                            [NCell_all_blue, mean_frequency_per_minute_all_blue, std_frequency_per_minute_all_blue, cell_density_per_microm2_all_blue, mean_max_corr_all_blue] = basic_metrics(mtor_data.DF, mtor_data.Raster, mtor_data.MAct, gcamp_output_folders, gcamp_data.sampling_rate, all_imageHeight, all_imageWidth);
                        end
                    
                        export_data(current_animal_group, current_gcamp_folders_names_group, current_ages_group, analysis_choice, pathexcel, current_animal_type, ...
                            all_recording_time, all_optical_zoom, all_position, all_time_minutes, ...
                            gcamp_data.sampling_rate, gcamp_data.synchronous_frames, NCell_all, NCell_all_blue, mean_frequency_per_minute_all, mean_frequency_per_minute_all_blue, std_frequency_per_minute_all, std_frequency_per_minute_all_blue, cell_density_per_microm2_all, cell_density_per_microm2_all_blue, mean_max_corr_all, mean_max_corr_all_blue);
                    
                    case 4
                        disp(['Performing SCEs analysis for ', current_animal_group]);
                        [gcamp_data.DF, gcamp_data.Raster, all_sampling_rate, ~, all_sce_n_cells_threshold, all_Race, all_TRace, all_sces_distances, all_RasterRace] = load_or_process_sce_data(current_animal_group, current_gcamp_folders_group, current_env_group, current_dates_group, gcamp_output_folders);
                        [all_num_sces, all_sce_frequency_seconds, all_avg_active_cell_SCEs, all_prop_active_cell_SCEs, all_avg_duration_ms] = SCEs_analysis(all_TRace, all_sampling_rate, all_Race, gcamp_data.Raster, all_sces_distances, gcamp_output_folders);
                    
                        export_data(current_animal_group, current_gcamp_folders_names_group, current_ages_group, analysis_choice, pathexcel, current_animal_type, ...
                            all_sce_n_cells_threshold, all_num_sces, all_sce_frequency_seconds, all_avg_active_cell_SCEs, all_prop_active_cell_SCEs, all_avg_duration_ms);
                    
                        % Initialiser les cellules pour ce groupe
                        all_DF_groups{k} = gcamp_data.DF;
                        all_sampling_rate_groups{k} = all_sampling_rate;
                        all_Raster_groups{k} = gcamp_data.Raster;
                        all_Race_groups{k} = all_Race;
                        all_TRace_groups{k} = all_TRace;
                        all_sces_distances_groups{k} = all_sces_distances;
                        all_RasterRace_groups{k} = all_RasterRace;
                    
                    case 5
                        disp(['Performing clusters analysis for ', current_animal_group]);
                        [gcamp_data.Raster, all_sce_n_cells_threshold, all_synchronous_frames, ~, all_IDX2, all_RaceOK, all_clusterMatrix, all_NClOK, all_assemblystat, all_outlines_gcampx, all_outlines_gcampy, all_meandistance_assembly] = load_or_process_clusters_data(current_animal_group, current_dates_group, gcamp_output_folders, current_gcamp_folders_group, current_env_group);
                        
                        plot_assemblies(all_assemblystat, all_outlines_gcampx, all_outlines_gcampy, all_meandistance_assembly, current_gcamp_folders_group);
                        plot_clusters_metrics(gcamp_output_folders, all_NClOK, all_RaceOK, all_IDX2, all_clusterMatrix, gcamp_data.Raster, all_sce_n_cells_threshold, all_synchronous_frames, current_animal_group, current_dates_group);
                    
                    case 6
                        [gcamp_data, mtor_data, all_data] = load_or_process_raster_data(gcamp_output_folders, current_gcamp_folders_group, current_env_group, include_blue_cells, folders_groups, blue_output_folders, date_group_paths, current_gcamp_TSeries_path, analysis_choice);  
                        if strcmpi(include_blue_cells, '1')
                           [all_max_corr_gcamp_gcamp, all_max_corr_gcamp_mtor, all_max_corr_mtor_mtor] = plot_pairwise_corr(gcamp_data.DF, gcamp_output_folders, gcamp_data.sampling_rate, all_data.DF, all_data.blue_indices); 
                        else
                            [all_max_corr_gcamp_gcamp, all_max_corr_gcamp_mtor, all_max_corr_mtor_mtor] = plot_pairwise_corr(gcamp_data.DF, gcamp_output_folders, gcamp_data.sampling_rate);
                        end
                        
                        all_max_corr_gcamp_gcamp_groups{k} = all_max_corr_gcamp_gcamp;
                        all_max_corr_gcamp_mtor_groups{k} = all_max_corr_gcamp_mtor;
                        all_max_corr_mtor_mtor_groups{k} = all_max_corr_mtor_mtor;

                otherwise
                    disp('Invalid analysis choice. Skipping...');
            end
            current_group_paths{k} = gcamp_output_folders;
        end
    end

    % % Analyses globales après la boucle (une meme mesure pour plusieurs animaux)
    % if analysis_choice == 3
    %     SCEs_groups_analysis2(selected_groups, all_DF_groups, all_Race_groups, all_TRace_groups, all_sampling_rate_groups, all_Raster_groups, all_sces_distances_groups);
    % end
     
    corr_groups_analysis(selected_groups, daytime, all_max_corr_gcamp_gcamp_groups, all_max_corr_gcamp_mtor_groups, all_max_corr_mtor_mtor_groups)


    % Demander à l'utilisateur s'il souhaite créer un fichier PowerPoint
    create_ppt = input('Do you want to generate a PowerPoint presentation with the generated figure(s)? (1/2): ', 's');
    if strcmpi(create_ppt, '1')
        create_ppt_from_figs(current_group_paths, daytime)
    end
end

%% Helper Functions (loading and processing)

function [all_recording_time, all_optical_zoom, all_position, all_time_minutes] = find_recording_infos(gcamp_output_folders,current_env_group)
    numFolders = length(gcamp_output_folders);
    all_recording_time = cell(numFolders, 1);
    all_optical_zoom = cell(numFolders, 1);
    all_position = cell(numFolders, 1);
    all_time_minutes = cell(numFolders, 1);

    for m = 1:length(gcamp_output_folders)
        [recording_time, sampling_rate, optical_zoom, position, time_minutes] = find_key_value(current_env_group{m});
        all_recording_time{m} = recording_time;
        all_optical_zoom{m} = optical_zoom;
        all_position{m} = position;
        all_time_minutes{m} = time_minutes; 
    end
end


function [gcamp_data, mtor_data, all_data] = load_or_process_raster_data(gcamp_output_folders, current_gcamp_folders_group, current_env_group, include_blue_cells, folders_groups, blue_output_folders, date_group_paths, current_gcamp_TSeries_path, analysis_choice)

    % Initialisation des structures
    numFolders = length(gcamp_output_folders);
    
    % Définir les champs pour chaque structure
    gcamp_fields = {'DF', 'sampling_rate', 'isort1', 'isort2', 'Sm', 'Raster', 'MAct', 'synchronous_frames'};
    blue_fields = {'DF', 'DF_not_blue', 'Raster', 'MAct', 'isort1'};
    all_fields = {'DF', 'isort1', 'blue_indices', 'isort2', 'Raster', 'MAct', 'Sm'};
    
    % Initialiser les structures avec les champs spécifiés
    gcamp_data = init_data_struct(numFolders, gcamp_fields);
    mtor_data = init_data_struct(numFolders, blue_fields);
    all_data = init_data_struct(numFolders, all_fields);
    
    MinPeakDistance = 5;
    numChannels = length(folders_groups);
    R = 5; % Rayon d'influence pour la correspondance des centroids

    for m = 1:numFolders
        filePath = fullfile(gcamp_output_folders{m}, 'results_raster.mat');

        % Ensure the directory exists
        if ~isfolder(gcamp_output_folders{m})
            mkdir(gcamp_output_folders{m}); % Create directory if it doesn’t exist
        end
        
        if exist(filePath, 'file') == 2
            disp(['Loading file: ', filePath]);
            data = load(filePath);
            
            % Chargement des données GCaMP
            gcamp_data.DF{m} = getFieldOrDefault(data, 'DF_gcamp', []);
            gcamp_data.sampling_rate{m} = getFieldOrDefault(data, 'sampling_rate', []);
            gcamp_data.synchronous_frames{m} = getFieldOrDefault(data, 'synchronous_frames', []);
            gcamp_data.isort1{m} = getFieldOrDefault(data, 'isort1_gcamp', []);
            gcamp_data.isort2{m} = getFieldOrDefault(data, 'isort2_gcamp', []);
            gcamp_data.Sm{m} = getFieldOrDefault(data, 'Sm_gcamp', []);
            gcamp_data.Raster{m} = getFieldOrDefault(data, 'Raster_gcamp', []);
            gcamp_data.MAct{m} = getFieldOrDefault(data, 'MAct_gcamp', []);
            
            if strcmpi(include_blue_cells, '1')
                mtor_data.DF{m} = getFieldOrDefault(data, 'DF_blue', []);
                mtor_data.DF_not_blue{m} = getFieldOrDefault(data, 'DF_gcamp_not_blue', []);
                mtor_data.Raster{m} = getFieldOrDefault(data, 'Raster_blue', []);
                mtor_data.MAct{m} = getFieldOrDefault(data, 'MAct_blue', []);
                
                all_data.DF{m} = getFieldOrDefault(data, 'DF_all', []);
                all_data.isort1{m} = getFieldOrDefault(data, 'isort1_all', []);
                all_data.blue_indices{m} = getFieldOrDefault(data, 'blue_indices', []);
                all_data.isort2{m} = getFieldOrDefault(data, 'isort2_all', []);
                all_data.Sm{m} = getFieldOrDefault(data, 'Sm_all', []);
                all_data.Raster{m} = getFieldOrDefault(data, 'Raster_all', []);
                all_data.MAct{m} = getFieldOrDefault(data, 'MAct_all', []);
            end
        end
        
        % Si sampling_rate ou synchronous_frames sont vides, les générer
        if isempty(gcamp_data.sampling_rate{m})
            [~, sampling_rate, ~] = find_key_value(current_env_group{m});
            gcamp_data.sampling_rate{m} = sampling_rate;
        end
        if isempty(gcamp_data.synchronous_frames{m})
            gcamp_data.synchronous_frames{m} = round(0.2 * gcamp_data.sampling_rate{m});
        end
        
        % Si DF_gcamp est vide, traiter les données
        if isempty(gcamp_data.DF{m})
            [~, DF_gcamp, ops, ~, ~] = load_data(current_gcamp_folders_group{m});
            DF_gcamp = DF_processing(DF_gcamp);
            [isort1_gcamp, isort2_gcamp, Sm_gcamp] = raster_processing(DF_gcamp, current_gcamp_folders_group{m}, ops);
            [Raster_gcamp, MAct_gcamp, ~] = Sumactivity(DF_gcamp, MinPeakDistance, gcamp_data.synchronous_frames{m});
            
            % Sauvegarde des résultats
            save(filePath, 'MinPeakDistance', 'DF_gcamp', 'isort1_gcamp', ...
                'isort2_gcamp', 'Sm_gcamp', 'Raster_gcamp', 'MAct_gcamp');

            gcamp_data.DF{m} = DF_gcamp;
            gcamp_data.isort1{m} = isort1_gcamp;
            gcamp_data.isort2{m} = isort2_gcamp;
            gcamp_data.Sm{m} = Sm_gcamp;
            gcamp_data.Raster{m} = Raster_gcamp;
            gcamp_data.MAct{m} = MAct_gcamp;
        end

        % Traitement des cellules bleues
        if strcmpi(include_blue_cells, '1') && isempty(mtor_data.DF{m})
            disp('Processing blue cells...');
            [~, aligned_image, npy_file_path, meanImg] = load_or_process_cellpose_TSeries(folders_groups, blue_output_folders{m}, date_group_paths{m}, numChannels, m);
            
            assignin('base', 'npy_file_path', npy_file_path);
            if ~isempty(npy_file_path)
     
                [num_cells_mask, mask_cellpose, props_cellpose, outlines_x_cellpose, outlines_y_cellpose] = load_or_process_cellpose_data(npy_file_path);
                
                % Définir le chemin du fichier à charger ou sauvegarder
                filePath2 = fullfile(gcamp_output_folders{m}, 'results_image.mat'); 
                
                if exist(filePath2, 'file') == 2 
                    disp(['Loading file: ', filePath2]);
                    % Charger les données existantes
                    data = load(filePath2); 
                
                    if isfield(data, 'outlines_gcampx') || isfield(data, 'outline_gcampx')
                        % Vérifier et affecter 'outlines_gcampx' ou 'outline_gcampx'
                        if isfield(data, 'outlines_gcampx')
                            outlines_gcampx = data.outlines_gcampx;
                        elseif isfield(data, 'outline_gcampx')
                            outlines_gcampx = data.outline_gcampx;
                        end
                    end                   
                    if isfield(data, 'outlines_gcampy') || isfield(data, 'outline_gcampy')
                        % Vérifier et affecter 'outlines_gcampy' ou 'outline_gcampy'
                        if isfield(data, 'outlines_gcampy')
                            outlines_gcampy = data.outlines_gcampy;
                        elseif isfield(data, 'outline_gcampy')
                            outlines_gcampy = data.outline_gcampy;
                        end
                    end
                    if isfield(data, 'gcamp_mask') 
                        gcamp_mask = data.gcamp_mask;
                    end
                    if isfield(data, 'gcamp_props') 
                        gcamp_props = data.gcamp_props;
                    end
                    if isfield(data, 'imageHeight') 
                        imageHeight = data.imageHeight;
                    end
                    if isfield(data, 'imageWidth') 
                        imageWidth = data.imageWidth;
                    end
                else
                    [stat, iscell] = load_data_mat_npy(current_gcamp_folders_group{m});
                    [NCell, outlines_gcampx, outlines_gcampy, ~, ~, ~] = load_calcium_mask(iscell, stat);
                
                    % Créer poly2mask et obtenir les propriétés gcamp
                    [gcamp_mask, gcamp_props, imageHeight, imageWidth] = process_poly2mask(stat, NCell, outlines_gcampx, outlines_gcampy); 
                
                    % Sauvegarder les résultats dans le fichier results_distance.mat
                    save(filePath2, 'NCell', 'outlines_gcampx', 'outlines_gcampy', 'gcamp_mask', 'gcamp_props', 'imageHeight', 'imageWidth');
                end
                
                % Vérifier que gcamp_props et props_cellpose existent
                if isempty(gcamp_props) || isempty(props_cellpose)
                    fprintf('Skipping group %d: No centroids found.\n', m);
                    continue;
                end
                  
                % Vérifier si meanImg est vide
                if isempty(meanImg)
                    fprintf('Skipping group %d: meanImg is empty.\n', m);
                    continue;
                end
                
                % Assurer une conversion en uint16 si besoin
                if isa(meanImg, 'single')
                    meanImg = uint16(meanImg);
                end
                   
                [matched_gcamp_idx, matched_cellpose_idx] = show_masks_and_overlaps(gcamp_props, props_cellpose, meanImg, aligned_image, outlines_gcampx, outlines_gcampy, outlines_x_cellpose, outlines_y_cellpose, R, m, blue_output_folders);
                currentTSeriesPath = current_gcamp_TSeries_path{m};
                [DF_blue, DF_gcamp_not_blue] = get_blue_cells_rois(gcamp_data.DF{m}, matched_gcamp_idx, matched_cellpose_idx, num_cells_mask, mask_cellpose, currentTSeriesPath); 
                
                DF_blue = DF_processing(DF_blue);
                [Raster_blue, MAct_blue, ~] = Sumactivity(DF_blue, MinPeakDistance, gcamp_data.synchronous_frames{m});

                save(filePath, "DF_blue", "DF_gcamp_not_blue", "Raster_blue", "MAct_blue", '-append');

                mtor_data.DF{m} = DF_blue;
                mtor_data.DF_not_blue{m} = DF_gcamp_not_blue;
                mtor_data.Raster{m} = Raster_blue;
                mtor_data.MAct{m} = MAct_blue;
            end
        end
        
        %all_data.DF{m} = [];

        % Traitement des données combinées si analysis_choice == 2
        if strcmpi(include_blue_cells, '1') && isempty(all_data.DF{m}) && ~isempty(mtor_data.DF{m})
            all_data.DF{m} = [mtor_data.DF_not_blue{m}; mtor_data.DF{m}];
            DF_all = all_data.DF{m};
            NCells = size(mtor_data.DF_not_blue{m}, 1);
            blue_indices = (NCells + 1):size(DF_all, 1);
            %disp(blue_indices)

            [isort1_all, isort2_all, Sm_all] = raster_processing(DF_all, current_gcamp_folders_group{m});
            
            [Raster_all, MAct_all, ~] = Sumactivity(DF_all, MinPeakDistance, gcamp_data.synchronous_frames{m});

            save(filePath, "DF_all", "Raster_all", "MAct_all", 'isort1_all', 'blue_indices', '-append');

            all_data.isort1{m} = isort1_all;
            all_data.isort2{m} = isort2_all;
            all_data.blue_indices{m} = blue_indices;
            all_data.Sm{m} = Sm_all;
            all_data.Raster{m} = Raster_all;
            all_data.MAct{m} = MAct_all;
        end
    end
end

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


function [all_DF_gcamp, all_Raster_gcamp,all_sampling_rate, all_synchronous_frames, all_sce_n_cells_threshold, all_Race, all_TRace, all_sces_distances, all_RasterRace] = load_or_process_sce_data(current_animal_group, current_gcamp_folders_group, current_env_group, current_dates_group, gcamp_output_folders)
    % Initialize output cell arrays to store results for each directory
    numFolders = length(gcamp_output_folders);  % Number of groups
    all_sce_n_cells_threshold = cell(numFolders, 1);
    all_Race = cell(numFolders, 1);
    all_TRace = cell(numFolders, 1);
    all_sces_distances = cell(numFolders, 1);
    all_RasterRace = cell(numFolders, 1);

    % Load or process raster data
    [gcamp_data, mtor_data, all_data] = load_or_process_raster_data(gcamp_output_folders, current_gcamp_folders_group, current_env_group, include_blue_cells, folders_groups, blue_output_folders, date_group_paths, current_gcamp_TSeries_path, analysis_choice); 

    % Initialize a flag to track if processing is needed
    process_needed = false;

    % First loop: Check if results exist and load them
    for m = 1:numFolders
        % Create the full file path for results_SCEs.mat
        filePath = fullfile(gcamp_output_folders{m}, 'results_SCEs.mat');

        if exist(filePath, 'file') == 2
            disp(['Loading file: ', filePath]);
            % Try to load the pre-existing results from the file
            data = load(filePath);
            
            % Assign the relevant fields to the output variables
            if isfield(data, 'Race')
                all_Race{m} = data.Race;
            end
            if isfield(data, 'TRace')
                all_TRace{m} = data.TRace;
            end
            if isfield(data, 'sces_distances')
                all_sces_distances{m} = data.sces_distances;
            end
            if isfield(data, 'RasterRace')
                all_RasterRace{m} = data.RasterRace;
            end
            if isfield(data, 'sce_n_cells_threshold')
                all_sce_n_cells_threshold{m} = data.sce_n_cells_threshold;
            end
        else
            % If at least one file is missing, mark that processing is needed
            process_needed = true;
        end
    end

    % If processing is needed, handle it outside the loop
    if process_needed
        disp('Processing missing files...');

        % Process data for missing files and save results
        for m = 1:numFolders
            % Create the full file path for results_SCEs.mat
            filePath = fullfile(gcamp_output_folders{m}, 'results_SCEs.mat');

            % Skip already loaded files
            if exist(filePath, 'file') == 2
                continue;
            end

            % Process and save the missing results
            disp(['Processing folder: ', gcamp_output_folders{m}]);

            % Extract relevant data for the current folder
            Raster = all_Raster{m};
            MAct = all_MAct{m};
            synchronous_frames = all_synchronous_frames{m};

            MinPeakDistancesce=3;
            WinActive=[];%find(speed>1);

            % Call the processing function
            [sce_n_cells_threshold, TRace, Race, sces_distances, RasterRace] = ...
                select_synchronies(gcamp_output_folders{m}, synchronous_frames, WinActive, all_DF{m}, MAct, MinPeakDistancesce, Raster, current_animal_group, current_dates_group{m});

            % Store results in output variables
            all_sce_n_cells_threshold{m} = sce_n_cells_threshold;
            all_Race{m} = Race;
            all_TRace{m} = TRace;
            all_sces_distances{m} = sces_distances;
            all_RasterRace{m} = RasterRace;
        end
    end
end


function [all_Raster_gcamp,all_sce_n_cells_threshold, all_synchronous_frames, validDirectories, all_IDX2, all_RaceOK, all_clusterMatrix, all_NClOK, all_assemblystat, all_outlines_gcampx, all_outlines_gcampy, all_meandistance_assembly] = load_or_process_clusters_data(current_animal_group, current_dates_group, gcamp_output_folders, current_gcamp_folders_group, current_env_group)
    
    % Initialize output cell arrays to store results for each directory
    numFolders = length(gcamp_output_folders);  % Number of groups
    % Initialize all output variables
    % all_IDX2 = cell(numFolders, 1);
    % all_sCl = cell(numFolders, 1);
    % all_M = cell(numFolders, 1);
    % all_S = cell(numFolders, 1);
    % all_R = cell(numFolders, 1);
    % all_CellScore = cell(numFolders, 1);
    % all_CellScoreN = cell(numFolders, 1);
    % all_CellCl = cell(numFolders, 1);
    all_IDX2 = cell(numFolders, 1);
    all_NClOK = cell(numFolders, 1);
    validDirectories = cell(numFolders, 1);
    all_assemblystat = cell(numFolders, 1);
    all_RaceOK = cell(numFolders, 1);
    all_clusterMatrix = cell(numFolders, 1);

    all_meandistance_assembly = cell(numFolders, 1);
    
    % Initialize a flag to track if processing is needed
    further_process_needed = false;
    
    % Load Race in prevision of clustering
    [~, all_Raster_gcamp,~, all_synchronous_frames, all_sce_n_cells_threshold, all_Race, ~, ~, ~] = ...
        load_or_process_sce_data(current_animal_group, current_gcamp_folders_group, current_env_group, current_dates_group, gcamp_output_folders);

    % First loop: Check if results exist and load them
    for m = 1:numFolders
        % Chemin complet pour le fichier results_clustering.mat
        filePath = fullfile(gcamp_output_folders{m}, 'results_clustering.mat');
    
        if exist(filePath, 'file') == 2
            disp(['Loading file: ', filePath]);
            % Charger les données existantes
            data = load(filePath);
    
            % Vérifier si les données nécessaires pour "Distances between assemblies" existent
            requiredFields = {'IDX2', 'sCl', 'M', 'S', 'R', 'CellScore', 'CellScoreN', 'CellCl', ...
                              'NClOK', 'validDirectory','assemblystat', 'RaceOK', 'clusterMatrix'};
            hasAllRequiredFields = all(cellfun(@(field) isfield(data, field), requiredFields));
    
            if hasAllRequiredFields
                % Charger les données nécessaires
                all_IDX2{m} = data.IDX2;
                all_NClOK{m} = data.NClOK;
                validDirectories{m} = data.validDirectory;
                all_assemblystat{m} = data.assemblystat;
                all_RaceOK{m} = data.RaceOK;
                all_clusterMatrix{m} = data.clusterMatrix;
    
                % Charger les informations supplémentaires pour les distances
                if isfield(data, 'meandistance_assembly')
                    all_meandistance_assembly{m} = data.meandistance_assembly;
                end
            else
                % Si les fichiers sont absents, marquer pour traitement
                further_process_needed = true;
            end

          else
                % Process and save the missing results
                disp(['Processing folder: ', gcamp_output_folders{m}]);
    
                % Extract relevant data for the current folder
                Race = all_Race{m};
    
                kmean_iter = 100;
                kmeans_surrogate = 100;
    
                % Call the processing function
                [validDirectory, clusterMatrix, NClOK, assemblystat] = ...
                    cluster_synchronies(gcamp_output_folders{m}, Race, kmean_iter, kmeans_surrogate);
    
                validDirectories{m} = validDirectory;
                all_clusterMatrix{m} = clusterMatrix;
                all_NClOK{m} = NClOK;
                all_assemblystat{m} = assemblystat;
                
                further_process_needed = true;
        end    
    end
    
    % Si des traitements sont nécessaires pour des fichiers manquants
    if further_process_needed
        % Charger les fichiers nécessaires pour les distances
        [all_NCell, all_outlines_gcampx, all_outlines_gcampy, all_gcamp_mask, all_gcamp_props, all_imageHeight, all_imageWidth] = load_or_process_image_data(gcamp_output_folders, current_gcamp_folders_group);

        for m = 1:numFolders
            % Create the full file path for results_SCEs.mat
            filePath = fullfile(gcamp_output_folders{m}, 'results_clustering.mat');

            assemblystat = all_assemblystat{m};

            % Créer poly2mask et obtenir les propriétés gcamp
            gcamp_props = all_gcamp_props{m};
            % Taille du pixel
            size_pixel = 705 / 512;
    
            % Calculer les distances
            [~, meandistance_assembly, ~] = ...
                distance_btw_centroid(size_pixel, gcamp_props, assemblystat);
    
            % Sauvegarder les résultats dans le fichier results_clustering.mat
            save(filePath, 'meandistance_assembly', '-append');
    
            all_meandistance_assembly{m} = meandistance_assembly;

        end
    end
end


 function [all_NCell, all_outlines_gcampx, all_outlines_gcampy, all_gcamp_mask, all_gcamp_props, all_imageHeight, all_imageWidth] = load_or_process_image_data(gcamp_output_folders, current_gcamp_folders_group)
    numFolders = length(gcamp_output_folders);
    % Initialiser les cellules pour stocker les données
    all_NCell = cell(numFolders, 1);
    all_outlines_gcampx = cell(numFolders, 1);
    all_outlines_gcampy = cell(numFolders, 1);
    all_gcamp_mask = cell(numFolders, 1);
    all_gcamp_props = cell(numFolders, 1);
    all_imageHeight = cell(numFolders, 1);
    all_imageWidth = cell(numFolders, 1);

    for m = 1:numFolders
        % Définir le chemin du fichier à charger ou sauvegarder
        filePath = fullfile(gcamp_output_folders{m}, 'results_image.mat'); 

        if exist(filePath, 'file') == 2 
            disp(['Loading file: ', filePath]);
            % Charger les données existantes
            data = load(filePath); 

            if isfield(data, 'outline_gcampx') 
                all_outlines_gcampx{m} = data.outline_gcampx;
            end
            if isfield(data, 'outline_gcampy') 
                all_outlines_gcampy{m} = data.outline_gcampy; 
            end
            if isfield(data, 'gcamp_mask') 
                all_gcamp_mask{m} = data.gcamp_mask;
            end
            if isfield(data, 'gcamp_props') 
                all_gcamp_props{m} = data.gcamp_props;
            end
            if isfield(data, 'imageHeight') 
                all_imageHeight{m} = data.imageHeight;
            end
            if isfield(data, 'imageWidth') 
                all_imageWidth{m} = data.imageWidth;
            end
        else
            [stat, iscell] = load_data_mat_npy(current_gcamp_folders_group{m});
            [NCell, outlines_gcampx, outlines_gcampy, ~, ~, ~] = load_calcium_mask(iscell, stat);

            % Créer poly2mask et obtenir les propriétés gcamp
            [gcamp_mask, gcamp_props, imageHeight, imageWidth] = process_poly2mask(stat, NCell, outlines_gcampx, outlines_gcampy); 

            % Sauvegarder les résultats dans le fichier results_distance.mat
            save(filePath, 'NCell', 'outlines_gcampx', 'outlines_gcampy', 'gcamp_mask', 'gcamp_props', 'imageHeight', 'imageWidth');

            % Stocker les résultats dans les variables de sortie
            all_NCell{m} = NCell;
            all_outlines_gcampx{m} = outlines_gcampx;
            all_outlines_gcampy{m} = outlines_gcampy;
            all_gcamp_mask{m} = gcamp_mask;
            all_gcamp_props{m} = gcamp_props;
            all_imageHeight{m} = imageHeight;
            all_imageWidth{m} = imageWidth;
 
        end
    end
 end