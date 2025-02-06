function pipeline_for_data_processing(selected_groups)
    % process_data generates and saves figures for raster plots, mean images, or SCE analysis
    % Inputs:
    % - PathSave: Path where results will be saved
    % - animal_date_list: Cell array containing animal information (type, group, animal, date, etc.)
    % - truedataFolders: List of paths to the true data folders
    
    PathSave = 'D:\after_processing\Presentations\';
    currentDatetime = datetime('now');
    daytime = datestr(currentDatetime, 'yy_mm_dd_HH_MM');

    % Ask for analysis types, multiple choices separated by spaces
    analysis_choices_str = input('Choose analysis types (separated by spaces): mean images (1), raster plot (2), global analysis of activity (3), SCEs (4), sub-population (5) or clusters analysis (6)? ', 's');
  
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

    % Perform analyses
    for k = 1:length(selected_groups)
        current_animal_group = selected_groups(k).animal_group;
        current_animal_type = selected_groups(k).animal_type;
        current_dates_group = selected_groups(k).dates;

        current_gcamp_folders_group = cellfun(@string, selected_groups(k).folders(:, 1), 'UniformOutput', false);
        current_red_folders_group = cellfun(@string, selected_groups(k).folders(:, 2), 'UniformOutput', false);
        current_blue_folders_group = cellfun(@string, selected_groups(k).folders(:, 3), 'UniformOutput', false);
        current_green_folders_group = cellfun(@string, selected_groups(k).folders(:, 4), 'UniformOutput', false);
        folders_groups = {
            current_gcamp_folders_group,  % Group gCamp
            current_red_folders_group,    % Group Red
            current_blue_folders_group,   % Group Blue
            current_green_folders_group   % Group Green
        };

        current_ani_path_group = selected_groups(k).path;
        current_ages_group = selected_groups(k).ages;
        current_env_group = selected_groups(k).env;
        
        [date_group_paths, tseries_folders, tseries_results_paths, chosen_folder_processing] = create_base_folders(current_ani_path_group, current_dates_group, current_env_group, daytime, processing_choice1, processing_choice2, current_animal_group);
        assignin('base', 'chosen_folder_processing', chosen_folder_processing);

        % Assuming current_env_group{k} is defined and contains the folder path
        [~, chosen_folder, ~] = fileparts(chosen_folder_processing{1});
        
        % Create the new path for the Excel file with the modified title
        pathexcel = [PathSave 'analysis_' chosen_folder '.xlsx'];
        %disp(pathexcel)

        % Loop through each selected analysis choice
        for i = 1:length(analysis_choices)
            analysis_choice = analysis_choices(i);  % Get the current analysis choice
            
            switch analysis_choice
                case 1
                    disp(['Performing mean images for ', current_animal_group]);                
                    all_ops = load_ops(current_gcamp_folders_group);
                    save_mean_images(current_animal_group, all_ops, current_dates_group, tseries_results_paths)

                case 2
                    disp(['Performing raster plot analysis for ', current_animal_group]);
                    [all_DF, ~, ~, all_isort1, ~, ~, ~, all_MAct, ~] = load_or_process_raster_data(chosen_folder_processing, current_gcamp_folders_group, current_env_group);
                    build_rasterplot(all_DF, all_isort1, all_MAct, chosen_folder_processing, current_animal_group, current_ages_group)
                    build_rasterplots(all_DF, all_isort1, all_MAct, current_ani_path_group, current_animal_group, current_dates_group, current_ages_group);

                case 3
                    disp(['Performing Global analysis of activity for ', current_animal_group]);
                    [all_recording_time, all_optical_zoom, all_position, all_time_minutes] = find_recording_infos(chosen_folder_processing, current_env_group);
                    [all_DF, all_sampling_rate, all_synchronous_frames, ~, ~, ~, all_Raster, all_MAct, ~] = load_or_process_raster_data(chosen_folder_processing, current_gcamp_folders_group, current_env_group);
                    [~, ~, ~, ~, all_imageHeight, all_imageWidth] = load_or_process_image_data(chosen_folder_processing, current_gcamp_folders_group);
                    [NCell_all, mean_frequency_per_minute_all, std_frequency_per_minute_all, cell_density_per_microm2_all, mean_max_corr_all] = basic_metrics(all_DF, all_Raster, all_MAct, chosen_folder_processing, all_sampling_rate, all_imageHeight, all_imageWidth);
                    export_data(current_animal_group, tseries_folders, current_ages_group, analysis_choice, pathexcel, current_animal_type, ...
                         all_recording_time, all_optical_zoom, all_position, all_time_minutes, ...
                         all_sampling_rate, all_synchronous_frames, NCell_all, mean_frequency_per_minute_all, std_frequency_per_minute_all, cell_density_per_microm2_all, mean_max_corr_all);

                case 4
                    disp(['Performing SCEs analysis for ', current_animal_group]);
                    [all_DF, all_Raster, all_sampling_rate, ~, all_sce_n_cells_threshold, all_Race, all_TRace, all_sces_distances, all_RasterRace] = load_or_process_sce_data(current_animal_group, current_gcamp_folders_group, current_env_group, current_dates_group, chosen_folder_processing);
                    [all_num_sces, all_sce_frequency_seconds, all_avg_active_cell_SCEs, all_prop_active_cell_SCEs, all_avg_duration_ms] = SCEs_analysis(all_TRace, all_sampling_rate, all_Race, all_Raster, all_sces_distances, chosen_folder_processing);
                    export_data(current_animal_group, tseries_folders, current_ages_group, analysis_choice, pathexcel, current_animal_type, ...
                        all_sce_n_cells_threshold, all_num_sces, all_sce_frequency_seconds, all_avg_active_cell_SCEs, all_prop_active_cell_SCEs, all_avg_duration_ms);

                    % Initialiser les cellules pour ce groupe
                    all_DF_groups{k} = all_DF;
                    all_sampling_rate_groups{k} = all_sampling_rate;
                    all_Raster_groups{k} = all_Raster;
                    all_Race_groups{k} = all_Race;
                    all_TRace_groups{k} = all_TRace;
                    all_sces_distances_groups{k} = all_sces_distances;
                    all_RasterRace_groups{k} = all_RasterRace;

                case 5
                    disp(['Performing sub-population analysis for ', current_animal_group]);
                    
                    all_ops_colors = {[], [], [], []};
                    labels = {'Gcamp', 'Red', 'Blue', 'Green'};
                    
                    % Charger les opérations pour chaque groupe
                    for j = 1:length(folders_groups)
                        current_group_folders = folders_groups{j};
                        
                        if ~isempty(current_group_folders)
                            try
                                % Charger les opérations si des dossiers valides sont trouvés
                                all_ops = load_ops(current_group_folders);
                                all_ops_colors{j} = all_ops;
                            catch
                                % Gestion d'erreur si la fonction 'load_ops' échoue
                                warning('Error loading operations for group: %s.', labels{j});
                                all_ops_colors{j} = []; % On s'assure que all_ops{j} reste vide en cas d'erreur
                            end
                            

                        else
                            % Avertissement si aucun dossier valide n'est trouvé
                            warning('No valid folders found for group: %s.', labels{j});
                            
                            % Essayer avec les images Cellpose simples (singles images)
                            disp(['Trying with single images for group: ', labels{j}]);
                            
                            % Appel de la fonction pour charger ou traiter les images Cellpose
                            [npy_file_paths, aligned_image] = load_or_process_cellpose_image(date_group_paths, all_ops);
                        end
                    end

                    end




                    



                    [all_mask_cellpose, all_props_cellpose, all_outlines_x_cellpose, all_outlines_y_cellpose] = load_or_process_cellpose_data(npy_file_paths);
                    [all_outline_gcampx, all_outline_gcampy, all_gcamp_mask, all_gcamp_props, all_imageHeight, all_imageWidth] = load_or_process_image_data(chosen_folder_processing, current_gcamp_folders_group);
                    
                    compute_iou_between_centroids(all_gcamp_props, all_props_cellpose, all_outlines_x_cellpose, all_outlines_y_cellpose, all_outline_gcampx, all_outline_gcampy, date_group_paths, all_ops, aligned_image);

                case 6
                    disp(['Performing clusters analysis for ', current_animal_group]);
                    [all_Raster, all_sce_n_cells_threshold, all_synchronous_frames, ~, all_IDX2, all_RaceOK, all_clusterMatrix, all_NClOK, all_assemblystat, all_outline_gcampx, all_outline_gcampy, all_meandistance_assembly] = load_or_process_clusters_data(current_animal_group, current_dates_group, chosen_folder_processing, current_gcamp_folders_group, current_env_group);
                    plot_assemblies(all_assemblystat, all_outline_gcampx, all_outline_gcampy, all_meandistance_assembly, current_gcamp_folders_group);
                    plot_clusters_metrics(chosen_folder_processing, all_NClOK, all_RaceOK, all_IDX2, all_clusterMatrix, all_Raster, all_sce_n_cells_threshold, all_synchronous_frames, current_animal_group, current_dates_group);
               
                otherwise
                    disp('Invalid analysis choice. Skipping...');
            end
            current_group_paths{k} = chosen_folder_processing;
        end
    end

    % % Analyses globales après la boucle (une meme mesure pour plusieurs animaux)
    % if analysis_choice == 3
    %     SCEs_groups_analysis2(selected_groups, all_DF_groups, all_Race_groups, all_TRace_groups, all_sampling_rate_groups, all_Raster_groups, all_sces_distances_groups);
    % end

    % Demander à l'utilisateur s'il souhaite créer un fichier PowerPoint
    % create_ppt = input('Do you want to generate a PowerPoint presentation with the generated figure(s)? (y/n): ', 's');
    % if strcmpi(create_ppt, 'y')
    %     create_ppt_from_figs(current_group_paths)
    % end
end

%% Helper Functions (loading and processing)

function [all_recording_time, all_optical_zoom, all_position, all_time_minutes] = find_recording_infos(chosen_folder_processing,current_env_group)
    numFolders = length(chosen_folder_processing);
    all_recording_time = cell(numFolders, 1);
    all_optical_zoom = cell(numFolders, 1);
    all_position = cell(numFolders, 1);
    all_time_minutes = cell(numFolders, 1);

        for m = 1:length(chosen_folder_processing)
            [recording_time, sampling_rate, optical_zoom, position, time_minutes] = find_key_value(current_env_group{m});
            all_recording_time{m} = recording_time;
            all_optical_zoom{m} = optical_zoom;
            all_position{m} = position;
            all_time_minutes{m} = time_minutes; 
        end
    end


function [all_DF, all_sampling_rate, all_synchronous_frames, all_isort1, all_isort2, all_Sm, all_Raster, all_MAct, all_Acttmp2] = load_or_process_raster_data(chosen_folder_processing, current_gcamp_folders_group, current_env_group)    
    % Initialize cell arrays for outputs
    numFolders = length(chosen_folder_processing);
    all_DF = cell(numFolders, 1);
    all_sampling_rate = cell(numFolders, 1);
    all_isort1 = cell(numFolders, 1);
    all_isort2 = cell(numFolders, 1);
    all_Sm = cell(numFolders, 1);
    all_Raster = cell(numFolders, 1);
    all_MAct = cell(numFolders, 1);
    all_Acttmp2 = cell(numFolders, 1);
    all_synchronous_frames = cell(numFolders, 1);
   
    % Loop through each save path
    for m = 1:numFolders
        % Create the full file path for results_raster.mat
        filePath = fullfile(chosen_folder_processing{m}, 'results_raster.mat');
        
        if exist(filePath, 'file') == 2
            disp(['Loading file: ', filePath]);
            % Try to load the pre-existing results from the file
            data = load(filePath);
            
            % Assign the relevant fields to the output variables
            if isfield(data, 'DF')
                all_DF{m} = data.DF;
            end
            if isfield(data, 'isort1')
                all_isort1{m} = data.isort1;
            end
            if isfield(data, 'isort2')
                all_isort2{m} = data.isort2;
            end
            if isfield(data, 'Sm')
                all_Sm{m} = data.Sm;
            end
            if isfield(data, 'Raster')
                all_Raster{m} = data.Raster;
            end
            if isfield(data, 'MAct')
                all_MAct{m} = data.MAct;
            end
            if isfield(data, 'Acttmp2')
                all_Acttmp2{m} = data.Acttmp2;
            end
            if isfield(data, 'sampling_rate')
                all_sampling_rate{m} = data.sampling_rate;
            end
            if isfield(data, 'synchronous_frames')
                all_synchronous_frames{m} = data.synchronous_frames;
            end
            
        else
            [F, ops, ~, iscell] = load_data(current_gcamp_folders_group{m});
            DF = DF_processing(F, iscell);

            MinPeakDistance = 5;
            [~, sampling_rate, ~] = find_key_value(current_env_group{m});  % Find actual framerate
            synchronous_frames = round(0.2 * sampling_rate);  % Example: 0.2s of data
            
            % Call raster_processing function to process the data and get the results
            [isort1, isort2, Sm, Raster, MAct, Acttmp2] = raster_processing(DF, ops, MinPeakDistance, sampling_rate, synchronous_frames, chosen_folder_processing{m});

            % Store the results in the respective cell arrays
            all_DF{m} = DF;
            all_sampling_rate{m} = sampling_rate;
            all_synchronous_frames{m} = synchronous_frames;
            all_isort1{m} = isort1;
            all_isort2{m} = isort2;
            all_Sm{m} = Sm;
            all_Raster{m} = Raster;
            all_MAct{m} = MAct;
            all_Acttmp2{m} = Acttmp2;
        end
    end

    %Assign all_DF to the workspace
    % assignin('base', 'all_Raster', all_Raster);
    % assignin('base', 'all_MAct', all_MAct);
    
end


function [all_DF, all_Raster, all_sampling_rate, all_synchronous_frames, all_sce_n_cells_threshold, all_Race, all_TRace, all_sces_distances, all_RasterRace] = load_or_process_sce_data(current_animal_group, current_gcamp_folders_group, current_env_group, current_dates_group, chosen_folder_processing)
    % Initialize output cell arrays to store results for each directory
    numFolders = length(chosen_folder_processing);  % Number of groups
    all_sce_n_cells_threshold = cell(numFolders, 1);
    all_Race = cell(numFolders, 1);
    all_TRace = cell(numFolders, 1);
    all_sces_distances = cell(numFolders, 1);
    all_RasterRace = cell(numFolders, 1);

    % Load or process raster data
    [all_DF, all_sampling_rate, all_synchronous_frames, ~, ~, ~, all_Raster, all_MAct, ~] = ...
        load_or_process_raster_data(chosen_folder_processing, current_gcamp_folders_group, current_env_group); 

    % Initialize a flag to track if processing is needed
    process_needed = false;

    % First loop: Check if results exist and load them
    for m = 1:numFolders
        % Create the full file path for results_SCEs.mat
        filePath = fullfile(chosen_folder_processing{m}, 'results_SCEs.mat');

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
            filePath = fullfile(chosen_folder_processing{m}, 'results_SCEs.mat');

            % Skip already loaded files
            if exist(filePath, 'file') == 2
                continue;
            end

            % Process and save the missing results
            disp(['Processing folder: ', chosen_folder_processing{m}]);

            % Extract relevant data for the current folder
            Raster = all_Raster{m};
            MAct = all_MAct{m};
            synchronous_frames = all_synchronous_frames{m};

            MinPeakDistancesce=3;
            WinActive=[];%find(speed>1);

            % Call the processing function
            [sce_n_cells_threshold, TRace, Race, sces_distances, RasterRace] = ...
                select_synchronies(chosen_folder_processing{m}, synchronous_frames, WinActive, all_DF{m}, MAct, MinPeakDistancesce, Raster, current_animal_group, current_dates_group{m});

            % Store results in output variables
            all_sce_n_cells_threshold{m} = sce_n_cells_threshold;
            all_Race{m} = Race;
            all_TRace{m} = TRace;
            all_sces_distances{m} = sces_distances;
            all_RasterRace{m} = RasterRace;
        end
    end
end


function [all_Raster, all_sce_n_cells_threshold, all_synchronous_frames, validDirectories, all_IDX2, all_RaceOK, all_clusterMatrix, all_NClOK, all_assemblystat, all_outline_gcampx, all_outline_gcampy, all_meandistance_assembly] = load_or_process_clusters_data(current_animal_group, current_dates_group, chosen_folder_processing, current_gcamp_folders_group, current_env_group)
    
    % Initialize output cell arrays to store results for each directory
    numFolders = length(chosen_folder_processing);  % Number of groups
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
    [~, all_Raster, ~, all_synchronous_frames, all_sce_n_cells_threshold, all_Race, ~, ~, ~] = ...
        load_or_process_sce_data(current_animal_group, current_gcamp_folders_group, current_env_group, current_dates_group, chosen_folder_processing);

    % First loop: Check if results exist and load them
    for m = 1:numFolders
        % Chemin complet pour le fichier results_clustering.mat
        filePath = fullfile(chosen_folder_processing{m}, 'results_clustering.mat');
    
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
                disp(['Processing folder: ', chosen_folder_processing{m}]);
    
                % Extract relevant data for the current folder
                Race = all_Race{m};
    
                kmean_iter = 100;
                kmeans_surrogate = 100;
    
                % Call the processing function
                [validDirectory, clusterMatrix, NClOK, assemblystat] = ...
                    cluster_synchronies(chosen_folder_processing{m}, Race, kmean_iter, kmeans_surrogate);
    
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
        [all_outline_gcampx, all_outline_gcampy, all_gcamp_mask, all_gcamp_props, all_imageHeight, all_imageWidth] = load_or_process_image_data(chosen_folder_processing, current_gcamp_folders_group);

        for m = 1:numFolders
            % Create the full file path for results_SCEs.mat
            filePath = fullfile(chosen_folder_processing{m}, 'results_clustering.mat');

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


function [all_outline_gcampx, all_outline_gcampy, all_gcamp_mask, all_gcamp_props, all_imageHeight, all_imageWidth] = load_or_process_image_data(chosen_folder_processing, current_gcamp_folders_group)
    numFolders = length(chosen_folder_processing);
    % Initialiser les cellules pour stocker les données
    all_outline_gcampx = cell(numFolders, 1);
    all_outline_gcampy = cell(numFolders, 1);
    all_gcamp_mask = cell(numFolders, 1);
    all_gcamp_props = cell(numFolders, 1);
    all_imageHeight = cell(numFolders, 1);
    all_imageWidth = cell(numFolders, 1);

    for m = 1:numFolders
        % Définir le chemin du fichier à charger ou sauvegarder
        filePath = fullfile(chosen_folder_processing{m}, 'results_image.mat'); 

        if exist(filePath, 'file') == 2 
            disp(['Loading file: ', filePath]);
            % Charger les données existantes
            data = load(filePath); 

            if isfield(data, 'outline_gcampx') 
                all_outline_gcampx{m} = data.outline_gcampx;
            end
            if isfield(data, 'outline_gcampy') 
                all_outline_gcampy{m} = data.outline_gcampy; 
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
            [outline_gcampx, outline_gcampy, ~, ~, ~] = load_calcium_mask(iscell, stat);

            % Créer poly2mask et obtenir les propriétés gcamp
            [gcamp_mask, gcamp_props, imageHeight, imageWidth] = process_poly2mask(iscell, stat, outline_gcampx, outline_gcampy); 

            % Sauvegarder les résultats dans le fichier results_distance.mat
            save(filePath, 'outline_gcampx', 'outline_gcampy', 'gcamp_mask', 'gcamp_props', 'imageHeight', 'imageWidth');

            % Stocker les résultats dans les variables de sortie
            all_outline_gcampx{m} = outline_gcampx;
            all_outline_gcampy{m} = outline_gcampy;
            all_gcamp_mask{m} = gcamp_mask;
            all_gcamp_props{m} = gcamp_props;
            all_imageHeight{m} = imageHeight;
            all_imageWidth{m} = imageWidth;
 
        end
    end
end


function [all_mask_cellpose, all_props_cellpose, all_outlines_x_cellpose, all_outlines_y_cellpose] = load_or_process_cellpose_data(npy_file_paths)
    
    numFiles = length(npy_file_paths);
    % Initialiser les cellules pour stocker les données
    all_mask_cellpose = cell(numFiles, 1);
    all_props_cellpose = cell(numFiles, 1);
    all_outlines_x_cellpose = cell(numFiles, 1);
    all_outlines_y_cellpose = cell(numFiles, 1);

    for m = 1:numFiles
        npy_file_path = npy_file_paths{m};
        [mask_cellpose, props_cellpose, outline_x_cellpose, outline_y_cellpose] = load_masks_from_cellpose(npy_file_path);        
        
        % Stocker les résultats dans les variables de sortie
        all_mask_cellpose{m} = mask_cellpose;
        all_props_cellpose{m} = props_cellpose;
        all_outlines_x_cellpose{m} = outline_x_cellpose;      
        all_outlines_y_cellpose{m} = outline_y_cellpose;
        
    end
end