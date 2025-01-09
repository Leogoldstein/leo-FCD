function pipeline_for_data_processing(selected_groups)
    % process_data generates and saves figures for raster plots, mean images, or SCE analysis
    % Inputs:
    % - PathSave: Path where results will be saved
    % - animal_date_list: Cell array containing animal information (type, group, animal, date, etc.)
    % - truedataFolders: List of paths to the true data folders
    
    PathSave = 'D:\after_processing\Presentations\';
    pathexcel=[PathSave 'analysis.xlsx'];

    
    % Ask for analysis type after gathering all inputs
    analysis_choice = input('Choose analysis type: mean images (1), raster plot (2), global analysis of activity (3), SCEs (4) or clusters analysis (5)? ');
    
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
        current_dates_group = selected_groups(k).dates;
        current_folders_group = selected_groups(k).folders;
        current_ani_path_group = selected_groups(k).path;
        current_ages_group = selected_groups(k).ages;
        current_env_group = selected_groups(k).env;

        switch analysis_choice
            case 1
                disp(['Performing mean images for ', current_animal_group]);
                date_group_paths = create_base_folders(current_ani_path_group, current_dates_group);
                
                all_ops = load_ops(current_folders_group);
                save_mean_images(current_animal_group, all_ops, current_dates_group, date_group_paths)

            case 2
                disp(['Performing raster plot analysis for ', current_animal_group]);
                date_group_paths = create_base_folders(current_ani_path_group, current_dates_group);

                [all_DF, all_sampling_rate, all_synchronous_frames, all_isort1, all_isort2, all_Sm, all_Raster, all_MAct, all_Acttmp2] = load_or_process_raster_data(date_group_paths, current_folders_group, current_env_group);
                
                build_rasterplot(all_DF, all_isort1, all_MAct, date_group_paths, current_animal_group, current_ages_group)
                build_rasterplots(all_DF, all_isort1, all_MAct, current_ani_path_group, current_animal_group, current_dates_group, current_ages_group);

            case 3
                disp(['Performing Global analysis of activity for ', current_animal_group]);
                date_group_paths = create_base_folders(current_ani_path_group, current_dates_group);

                [all_DF, all_sampling_rate, all_synchronous_frames, all_isort1, all_isort2, all_Sm, all_Raster, all_MAct, all_Acttmp2] = load_or_process_raster_data(date_group_paths, current_folders_group, current_env_group);

                [mean_frequency_per_minute_all, std_frequency_per_minute_all] = basic_metrics(all_DF, all_Raster, all_MAct, date_group_paths, all_sampling_rate);

                export_data(current_animal_group, current_dates_group, analysis_choice, pathexcel, ...
                    all_sampling_rate, all_synchronous_frames, mean_frequency_per_minute_all, std_frequency_per_minute_all);

            case 4
                disp(['Performing SCEs analysis for ', current_animal_group]);
                date_group_paths = create_base_folders(current_ani_path_group, current_dates_group);
    
                [all_DF, all_Raster, all_sampling_rate, all_synchronous_frames, all_sce_n_cells_threshold, all_Race, all_TRace, all_sces_distances, all_RasterRace] = load_or_process_sce_data(current_animal_group, current_folders_group, current_env_group, current_dates_group, date_group_paths);
                
                all_num_sces = plot_threshold_sce_evolution(current_ani_path_group, current_animal_group, date_group_paths, current_ages_group, all_sce_n_cells_threshold, all_TRace);
               
                export_data(current_animal_group, current_dates_group, analysis_choice, pathexcel, ...
                   all_sce_n_cells_threshold);

                % Initialiser les cellules pour ce groupe
                all_DF_groups{k} = all_DF;
                all_sampling_rate_groups{k} = all_sampling_rate;
                all_Raster_groups{k} = all_Raster;
                all_Race_groups{k} = all_Race;
                all_TRace_groups{k} = all_TRace;
                all_sces_distances_groups{k} = all_sces_distances;
                all_RasterRace_groups{k} = all_RasterRace;

            case 5
                disp(['Performing clusters analysis for ', current_animal_group]);
                date_group_paths = create_base_folders(current_ani_path_group, current_dates_group);
    
                [all_Raster, all_sce_n_cells_threshold, all_synchronous_frames, validDirectories, all_IDX2, all_RaceOK, all_clusterMatrix, all_NClOK, all_assemblystat, all_outline_gcampx, all_outline_gcampy, all_meandistance_assembly] = load_or_process_clusters_data(current_animal_group, current_dates_group, date_group_paths, current_folders_group, current_env_group);
            
                plot_assemblies(all_assemblystat, all_outline_gcampx, all_outline_gcampy, all_meandistance_assembly, current_folders_group);

                plot_clusters_metrics(date_group_paths, all_NClOK, all_RaceOK, all_IDX2, all_clusterMatrix, all_Raster, all_sce_n_cells_threshold, all_synchronous_frames, current_animal_group, current_dates_group)
               
            otherwise
                disp('Invalid analysis choice. Skipping...');
        end
        current_group_paths{k} = date_group_paths;

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

%% Helper Functions

% Create subfolders for analysis
function date_group_paths = create_base_folders(base_path, current_dates_group)

    date_group_paths = cell(length(current_dates_group), 1);  % Chemins regroupés par date
    
    for k = 1:length(current_dates_group)
        % Crée le chemin complet pour chaque date
        date_path = fullfile(base_path, current_dates_group{k});
        
        % Vérifie si le dossier existe déjà
        if ~exist(date_path, 'dir')
            % Crée le dossier s'il n'existe pas
            mkdir(date_path);
            disp(['Created folder: ', date_path]);
        end
        
        % Assigner le chemin du dossier créé dans la cellule
        date_group_paths{k} = date_path;
    end
end


function [all_DF, all_sampling_rate, all_synchronous_frames, all_isort1, all_isort2, all_Sm, all_Raster, all_MAct, all_Acttmp2] = load_or_process_raster_data(date_group_paths, current_folders_group, current_env_group)    
    % Initialize cell arrays for outputs
    numFolders = length(date_group_paths);
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
        filePath = fullfile(date_group_paths{m}, 'results_raster.mat');
        
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
            [F, ops, ~, iscell] = load_data(current_folders_group{m});
            DF = DF_processing(F, iscell);

            MinPeakDistance = 5;
            sampling_rate = find_key_value(current_env_group{m}, 'framerate');  % Find actual framerate
            synchronous_frames = round(0.2 * sampling_rate);  % Example: 0.2s of data
            
            % Call raster_processing function to process the data and get the results
            [isort1, isort2, Sm, Raster, MAct, Acttmp2] = raster_processing(DF, ops, MinPeakDistance, sampling_rate, synchronous_frames, date_group_paths{m});

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


function [all_DF, all_Raster, all_sampling_rate, all_synchronous_frames, all_sce_n_cells_threshold, all_Race, all_TRace, all_sces_distances, all_RasterRace] = load_or_process_sce_data(current_animal_group, current_folders_group, current_env_group, current_dates_group, date_group_paths)
    % Initialize output cell arrays to store results for each directory
    numFolders = length(date_group_paths);  % Number of groups
    all_sce_n_cells_threshold = cell(numFolders, 1);
    all_Race = cell(numFolders, 1);
    all_TRace = cell(numFolders, 1);
    all_sces_distances = cell(numFolders, 1);
    all_RasterRace = cell(numFolders, 1);

    % Load or process raster data
    [all_DF, all_sampling_rate, all_synchronous_frames, all_isort1, all_isort2, all_Sm, all_Raster, all_MAct, all_Acttmp2] = ...
        load_or_process_raster_data(date_group_paths, current_folders_group, current_env_group); 

    % Initialize a flag to track if processing is needed
    process_needed = false;

    % First loop: Check if results exist and load them
    for m = 1:numFolders
        % Create the full file path for results_SCEs.mat
        filePath = fullfile(date_group_paths{m}, 'results_SCEs.mat');

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
            filePath = fullfile(date_group_paths{m}, 'results_SCEs.mat');

            % Skip already loaded files
            if exist(filePath, 'file') == 2
                continue;
            end

            % Process and save the missing results
            disp(['Processing folder: ', date_group_paths{m}]);

            % Extract relevant data for the current folder
            Raster = all_Raster{m};
            MAct = all_MAct{m};
            synchronous_frames = all_synchronous_frames{m};

            MinPeakDistancesce=3;
            WinActive=[];%find(speed>1);

            % Call the processing function
            [sce_n_cells_threshold, TRace, Race, sces_distances, RasterRace] = ...
                select_synchronies(date_group_paths{m}, synchronous_frames, WinActive, all_DF{m}, MAct, MinPeakDistancesce, Raster, current_animal_group, current_dates_group{m});

            % Store results in output variables
            all_sce_n_cells_threshold{m} = sce_n_cells_threshold;
            all_Race{m} = Race;
            all_TRace{m} = TRace;
            all_sces_distances{m} = sces_distances;
            all_RasterRace{m} = RasterRace;
        end
    end
end


function [all_Raster, all_sce_n_cells_threshold, all_synchronous_frames, validDirectories, all_IDX2, all_RaceOK, all_clusterMatrix, all_NClOK, all_assemblystat, all_outline_gcampx, all_outline_gcampy, all_meandistance_assembly] = load_or_process_clusters_data(current_animal_group, current_dates_group, date_group_paths, current_folders_group, current_env_group)
    
    % Initialize output cell arrays to store results for each directory
    numFolders = length(date_group_paths);  % Number of groups
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
    
    all_outline_gcampx = cell(numFolders, 1);
    all_outline_gcampy = cell(numFolders, 1);
    all_meandistance_assembly = cell(numFolders, 1);
    
    % Initialize a flag to track if processing is needed
    further_process_needed = false;
    
    % Load Race in prevision of clustering
    [~, all_Raster, ~, all_synchronous_frames, all_sce_n_cells_threshold, all_Race, ~, ~, ~] = ...
        load_or_process_sce_data(current_animal_group, current_folders_group, current_env_group, current_dates_group, date_group_paths);

    % First loop: Check if results exist and load them
    for m = 1:numFolders
        % Chemin complet pour le fichier results_clustering.mat
        filePath = fullfile(date_group_paths{m}, 'results_clustering.mat');
    
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
                if isfield(data, 'outline_gcampx')
                    all_outline_gcampx{m} = data.outline_gcampx;
                end
                if isfield(data, 'outline_gcampy')
                    all_outline_gcampy{m} = data.outline_gcampy;
                end
                if isfield(data, 'meandistance_assembly')
                    all_meandistance_assembly{m} = data.meandistance_assembly;
                end
            else
                % Si les fichiers sont absents, marquer pour traitement
                further_process_needed = true;
            end

          else
                % Process and save the missing results
                disp(['Processing folder: ', date_group_paths{m}]);
    
                % Extract relevant data for the current folder
                Race = all_Race{m};
    
                kmean_iter = 100;
                kmeans_surrogate = 100;
    
                % Call the processing function
                [validDirectory, clusterMatrix, NClOK, assemblystat] = ...
                    cluster_synchronies(date_group_paths{m}, Race, kmean_iter, kmeans_surrogate);
    
                validDirectories{m} = validDirectory;
                all_clusterMatrix{m} = clusterMatrix;
                all_NClOK{m} = NClOK;
                all_assemblystat{m} = assemblystat;
                
                further_process_needed = true;
        end    
    end
    
    % Si des traitements sont nécessaires pour des fichiers manquants
    if further_process_needed
        % Process data for missing files and save results
        for m = 1:numFolders
            % Create the full file path for results_SCEs.mat
            filePath = fullfile(date_group_paths{m}, 'results_clustering.mat');

            assemblystat = all_assemblystat{m};

            % Charger les fichiers nécessaires pour les distances
            [stat, iscell] = load_data_mat_npy(current_folders_group{m});
            [outline_gcampx, outline_gcampy, neuropil, Coomasqx, Coomasqy] = load_calcium_mask(iscell, stat);
    
            % Créer poly2mask et obtenir les propriétés gcamp
            gcamp_props = process_poly2mask(iscell, stat, outline_gcampx, outline_gcampy);
    
            % Taille du pixel
            size_pixel = 705 / 512;
    
            % Calculer les distances
            [meandistance_gcamp, meandistance_assembly, mean_mean_distance_assembly] = ...
                distance_btw_centroid(size_pixel, gcamp_props, assemblystat);
    
            % Sauvegarder les résultats dans le fichier results_clustering.mat
            save(filePath, 'outline_gcampx', 'outline_gcampy', 'meandistance_assembly', '-append');
    
            all_outline_gcampx{m} = outline_gcampx;
            all_outline_gcampy{m} = outline_gcampy;
            all_meandistance_assembly{m} = meandistance_assembly;

        end
    end
end