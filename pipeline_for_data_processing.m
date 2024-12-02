function pipeline_for_data_processing(PathSave, truedataFolders, animal_date_list)
    % process_data generates and saves figures for raster plots, mean images, or SCE analysis
    % Inputs:
    % - PathSave: Path where results will be saved
    % - animal_date_list: Cell array containing animal information (type, group, animal, date, etc.)
    % - truedataFolders: List of paths to the true data folders
    
    % Extract parts from the animal_date_list
    type_part = animal_date_list(:, 1);
    mTor_part = animal_date_list(:, 2);
    animal_part = animal_date_list(:, 3);
    date_part = animal_date_list(:, 4);
    age_part = animal_date_list(:, 5); 
    
    % Determine unique groups for analysis
    if isempty(mTor_part) || all(cellfun(@isempty, mTor_part))
        % Grouper par animal seulement
        animal_group = animal_part; 
        unique_animal_group = unique(animal_part);
    else
        % Group by animal and mTor
        animal_group = strcat(animal_part, ' (', mTor_part, ')');
        unique_animal_group = unique(animal_group);
    end
    disp(unique_animal_group)

    % Initialize save paths and selection storage
    ani_paths = cell(length(unique_animal_group), 1);
    selected_groups = struct();
    
    for k = 1:length(unique_animal_group)
        current_animal_group = unique_animal_group{k};
        ani_path = fullfile(PathSave, type_part{1}, current_animal_group);
       
        % Create directory if it does not exist
        if ~exist(ani_path, 'dir')
            mkdir(ani_path);
            disp(['Created folder: ', ani_path]);
        end

        % Save the path
        ani_paths{k} = ani_path;
        
        % Get indices of dates for the current animal group
        date_indices = find(strcmp(animal_group, current_animal_group));
   
        % Display all dates for the current animal group
        disp(['Available dates for ', current_animal_group, ':']);
        for idx = 1:length(date_indices)
            disp(['[', num2str(idx), '] ', date_part{date_indices(idx)}]);
        end

        % Prompt user to select dates
        use_all_dates = input('Select all dates for this group? Yes (1) / No (0): ');
        if use_all_dates == 1
            selected_indices = date_indices; % Use all dates
        else
            selected_indices = input('Enter the indices of the dates to select (e.g., [1, 3, 5]): ');
            selected_indices = date_indices(selected_indices); % Map to actual indices
        end

        % Save the selected dates and folders for this group
        selected_groups(k).animal_group = current_animal_group;
        selected_groups(k).dates = date_part(selected_indices);
        selected_groups(k).ages = age_part(selected_indices);
        selected_groups(k).folders = truedataFolders(selected_indices);
        selected_groups(k).path = ani_path;

    end
    assignin('base', 'selected_groups', selected_groups);

    % Ask for analysis type after gathering all inputs
    analysis_choice = input('Choose analysis type: raster plot (1), mean images (2), SCEs (3) or clusters analysis (4)? ');
    
    % Pre-allocate variables for global analysis
    num_groups = length(selected_groups);  % Nombre de groupes sélectionnés
    all_DF_groups = cell(num_groups, 1);
    all_Raster_groups = cell(num_groups, 1);
    %all_sampling_rate_groups = cell(num_groups, 1);
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

        switch analysis_choice
            case 1
                disp(['Performing raster plot analysis for ', current_animal_group]);
                date_group_paths = create_base_folders(current_ani_path_group, current_dates_group);

                [sampling_rate, synchronous_frames, all_DF, all_ops, all_isort1, all_isort2, all_Sm, all_Raster, all_MAct, all_Acttmp2] = load_or_process_raster_data(date_group_paths, current_folders_group);
                
               
                build_rasterplots(all_DF, all_isort1, all_MAct, current_ani_path_group, current_animal_group, current_dates_group, current_ages_group);
           
            case 2
                disp(['Performing mean images for ', current_animal_group]);
                date_group_paths = create_base_folders(current_ani_path_group, current_dates_group);
                
                [sampling_rate, ~, ~, all_ops, ~, ~, ~, ~, ~, ~] = load_or_process_raster_data(date_group_paths, current_folders_group);

                save_mean_images(current_animal_group, all_ops, current_dates_group, date_group_paths)
  
            case 3
                disp(['Performing SCEs analysis for ', current_animal_group]);
                date_group_paths = create_base_folders(current_ani_path_group, current_dates_group);
    
                [all_DF, all_Raster, sampling_rate, all_sce_n_cells_threshold, all_Race, all_TRace, all_sces_distances, all_RasterRace] = load_or_process_sce_data(current_animal_group, current_folders_group, current_dates_group, date_group_paths);
                
                % Initialiser les cellules pour ce groupe
                all_DF_groups{k} = all_DF;
                all_Raster_groups{k} = all_Raster;
                all_Race_groups{k} = all_Race;
                all_TRace_groups{k} = all_TRace;
                all_sces_distances_groups{k} = all_sces_distances;
                all_RasterRace_groups{k} = all_RasterRace;
                current_group_paths{k} = date_group_paths;

            case 4
                disp(['Performing clusters analysis for ', current_animal_group]);
                date_group_paths = create_base_folders(current_ani_path_group, current_dates_group);
    
                [validDirectories, all_clusterMatrix, all_NClOK] = load_or_process_clusters_data(current_folders_group, current_animal_group, current_dates_group, date_group_paths);

            otherwise
                disp('Invalid analysis choice. Skipping...');
        end
    end
    
    % % Analyses globales après la boucle
    if analysis_choice == 3
        SCEs_groups_analysis(selected_groups, current_group_paths, all_DF_groups, all_Race_groups, all_TRace_groups, sampling_rate, all_Raster_groups, all_sces_distances_groups);
    end
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


function [sampling_rate, synchronous_frames, all_DF, all_ops, all_isort1, all_isort2, all_Sm, all_Raster, all_MAct, all_Acttmp2] = load_or_process_raster_data(date_group_paths, current_folders_group)    
    % Initialize cell arrays for outputs
    numFolders = length(date_group_paths);
    all_DF = cell(numFolders, 1);
    all_ops = cell(numFolders, 1);
    all_isort1 = cell(numFolders, 1);
    all_isort2 = cell(numFolders, 1);
    all_Sm = cell(numFolders, 1);
    all_Raster = cell(numFolders, 1);
    all_MAct = cell(numFolders, 1);
    all_Acttmp2 = cell(numFolders, 1);
    synchronous_frames = [];
   
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
            if isfield(data, 'ops')
                all_ops{m} = data.ops;
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
                sampling_rate = data.sampling_rate;
            end
            if isfield(data, 'synchronous_frames')
                synchronous_frames = data.synchronous_frames;
            end
            
        else
            [~, DF, ops, ~, ~] = load_and_preprocess_data(current_folders_group{m});

            MinPeakDistance = 5;
            sampling_rate = 29.87373388;  % Example value, replace with actual if needed
            synchronous_frames = round(0.2 * sampling_rate);  % Example: 0.2s of data
            
            % Call raster_processing function to process the data and get the results
            [isort1, isort2, Sm, Raster, MAct, Acttmp2] = raster_processing(DF, ops, MinPeakDistance, sampling_rate, synchronous_frames, date_group_paths{m});

            % Store the results in the respective cell arrays
            all_DF{m} = DF;
            all_ops{m} = ops;
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
    % assignin('base', 'all_isort1', all_isort1);
    
end


function [all_DF, all_Raster, sampling_rate, all_sce_n_cells_threshold, all_Race, all_TRace, all_sces_distances, all_RasterRace] = load_or_process_sce_data(current_animal_group, current_folders_group, current_dates_group, date_group_paths)
    % Initialize output cell arrays to store results for each directory
    numFolders = length(date_group_paths);  % Number of groups
    all_sce_n_cells_threshold = cell(numFolders, 1);
    all_Race = cell(numFolders, 1);
    all_TRace = cell(numFolders, 1);
    all_sces_distances = cell(numFolders, 1);
    all_RasterRace = cell(numFolders, 1);

    % Load or process raster data
    [sampling_rate, synchronous_frames, all_DF, ~, ~, ~, ~, all_Raster, all_MAct, ~] = ...
        load_or_process_raster_data(date_group_paths, current_folders_group); 

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


function [validDirectories, all_clusterMatrix, all_NClOK] = load_or_process_clusters_data(current_animal_group, current_dates_group, clusters_group_paths)
    
    % Initialize output cell arrays to store results for each directory
    numFolders = length(clusters_group_paths);  % Number of groups
    % Initialize all output variables
    all_IDX2 = cell(numFolders, 1);
    all_sCl = cell(numFolders, 1);
    all_M = cell(numFolders, 1);
    all_S = cell(numFolders, 1);
    all_R = cell(numFolders, 1);
    all_CellScore = cell(numFolders, 1);
    all_CellScoreN = cell(numFolders, 1);
    all_CellCl = cell(numFolders, 1);
    all_NClOK = cell(numFolders, 1);
    validDirectories = cell(numFolders, 1);
    all_assemblyraw = cell(numFolders, 1);
    all_assemblystat = cell(numFolders, 1);
    all_RaceOK = cell(numFolders, 1);
    all_clusterMatrix = cell(numFolders, 1);

    % Initialize a flag to track if processing is needed
    process_needed = false;

    % First loop: Check if results exist and load them
    for m = 1:numFolders
        % Create the full file path for results_SCEs.mat
        filePath = fullfile(clusters_group_paths{m}, 'results_clustering.mat');

        if exist(filePath, 'file') == 2
            disp(['Loading file: ', filePath]);
            % Try to load the pre-existing results from the file
            data = load(filePath);

            if isfield(data, 'IDX2')
                all_IDX2{k} = data.IDX2;
            end
            if isfield(data, 'sCl')
                all_sCl{k} = data.sCl;
            end
            if isfield(data, 'M')
                all_M{k} = data.M;
            end
            if isfield(data, 'S')
                all_S{k} = data.S;
            end
            if isfield(data, 'R')
                all_R{k} = data.R;
            end
            if isfield(data, 'CellScore')
                all_CellScore{k} = data.CellScore;
            end
            if isfield(data, 'CellScoreN')
                all_CellScoreN{k} = data.CellScoreN;
            end
            if isfield(data, 'CellCl')
                all_CellCl{k} = data.CellCl;
            end
            if isfield(data, 'NClOK')
                all_NClOK{k} = data.NClOK;
            end
            if isfield(data, 'validDirectory')
                validDirectories{k} = data.validDirectory;
            end
            if isfield(data, 'assemblyraw')
                all_assemblyraw{k} = data.assemblyraw;
            end
            if isfield(data, 'assemblystat')
                all_assemblystat{k} = data.assemblystat;
            end
            if isfield(data, 'RaceOK')
                all_RaceOK{k} = data.RaceOK;
            end
            if isfield(data, 'clusterMatrix')
                all_clusterMatrix{k} = data.clusterMatrix;
            end
        else
            % If at least one file is missing, mark that processing is needed
            process_needed = true;
        end
    end

    % If processing is needed, handle it outside the loop
    if process_needed
        disp('Processing missing files...');

        % Load or process raster and sce data
        [sampling_rate, synchronous_frames, all_DF, all_ops, ~, ~, ~, all_Raster, all_MAct, ~] = ...
            load_or_process_raster_data(date_group_paths, current_folders_group);
        
        [all_DF, all_Raster, sampling_rate, all_DF, all_sce_n_cells_threshold, all_Race, all_TRace, all_sces_distances, all_RasterRace] = ...
            load_or_process_sce_data(current_animal_group, current_folders_group, current_dates_group, date_group_paths);

        % Process data for missing files and save results
        for m = 1:numFolders
            % Create the full file path for results_SCEs.mat
            filePath = fullfile(clusters_group_paths{m}, 'results_clustering.mat');

            % Skip already loaded files
            if exist(filePath, 'file') == 2
                continue;
            end

            % Process and save the missing results
            disp(['Processing folder: ', clusters_group_paths{m}]);

            % Extract relevant data for the current folder
            Raster = all_Raster{m};
            MAct = all_MAct{m};
            Race = all_Race{m};

            kmean_iter = 100;
            kmeans_surrogate = 100;

            % Call the processing function
            [validDirectory, clusterMatrix, NClOK] = ...
                cluster_synchronies(clusters_group_paths{m}, all_DF{m}, MAct, Raster, Race, kmean_iter, kmeans_surrogate);

            % Store results in output variables
            validDirectories{m} = validDirectory;
            all_clusterMatrix{m} = clusterMatrix;
            all_NClOK{m} = NClOK;
        end
    end
end