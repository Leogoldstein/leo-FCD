function process_data(PathSave, animal_date_list, truedataFolders)
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
    if strcmp(type_part{1}, 'jm')
        % Group by animal only
        unique_animal_group = unique(animal_part);
    else
        % Group by animal and mTor
        animal_group = strcat(animal_part, ' (', mTor_part, ')');
        unique_animal_group = unique(animal_group);
    end

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
        if strcmp(type_part{1}, 'jm')
            date_indices = find(strcmp(animal_part, current_animal_group));
        else
            date_indices = find(strcmp(animal_group, current_animal_group));
        end

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
    
    % Ask for analysis type after gathering all inputs
    analysis_choice = input('Choose analysis type: raster plot (1), mean images (2), SCEs (3) or clusters analysis (4)? ');

    % Perform analyses
    for k = 1:length(selected_groups)
        current_animal_group = selected_groups(k).animal_group;
        current_dates_group = selected_groups(k).dates;
        current_folders_group = selected_groups(k).folders;
        current_ani_path_group = selected_groups(k).path;
        current_age_group = selected_groups(k).ages;

        switch analysis_choice
            case 1
                disp(['Performing raster plot analysis for ', current_animal_group]);
                [raster_path, raster_group_paths] = create_base_folders(current_ani_path_group, 'Raster plots', current_dates_group);

                [synchronous_frames, all_DF, all_isort1, all_isort2, all_Sm, all_Raster, all_MAct, all_Acttmp2] = load_or_process_raster_data(current_folders_group, raster_group_paths);
    
                build_rasterplots(all_DF, all_isort1, all_MAct, raster_path, current_animal_group, current_dates_group, current_age_group);
           
            case 2
                disp(['Performing mean images for ', current_animal_group]);
                [mean_path, mean_group_paths] = create_base_folders(current_ani_path_group, 'Mean images', current_dates_group);
               
                load_or_process_mean_images(mean_group_paths, current_folders_group, current_animal_group, current_dates_group)
                    
            case 3
                disp(['Performing SCEs analysis for ', current_animal_group]);
                [sce_path, sce_group_paths] = create_base_folders(current_ani_path_group, 'SCEs', current_dates_group);
    
                [all_sce_n_cells_threshold, all_Race, all_TRace, all_RasterRace] = load_or_process_sce_data(current_ani_path_group, current_folders_group, current_animal_group, current_dates_group, sce_group_paths);

            case 4
                disp(['Performing clusters analysis for ', current_animal_group]);
                [clusters_path, clusters_group_paths] = create_base_folders(current_ani_path_group, 'Clusters of SCEs', current_dates_group);
    
                [validDirectories, all_clusterMatrix, all_NClOK] = load_or_process_clusters_data(current_ani_path_group, current_folders_group, current_animal_group, current_dates_group, clusters_group_paths);

            otherwise
                disp('Invalid analysis choice. Skipping...');
        end
    end
end


% 
%         % SCE Analysis
%         elseif analysis_choice == 3
%             sce_paths = create_base_folders(ani_paths, 'SCEs');
%             [sce_group_paths, inds_group, dates_group, truedataFolders_group] = create_date_folders(sce_paths, unique_animal_group, animal_group, date_part, truedataFolders);
% 
%             raster_paths = create_base_folders(ani_paths, 'Raster plots');
%             [raster_group_paths, inds_group, dates_group, truedataFolders_group] = create_date_folders(raster_paths, unique_animal_group, animal_group, date_part, truedataFolders);
%             [synchronous_frames, all_DF, ~, ~, ~, all_Raster, all_MAct, ~] = load_or_process_raster_data(truedataFolders_group, raster_group_paths);
% 
%             [~, all_Race, ~, ~] = load_or_process_sce_data(sce_group_paths, all_DF, all_MAct, all_Raster, synchronous_frames, animal_group, dates_group);
% 
% 
% 
%             % % Generate SCE analysis figures
%             %  for k = 1:length(unique_animal_group)
%             %     current_animal = unique_animal_group{k};
%             %     fig_save_path = fullfile(raster_paths{k}, sprintf('%s_synchrony_peaks.png', strrep(current_animal, ' ', '_')));
%             % 
%             %     if ~exist(fig_save_path, 'file')
%             %         fig_save_paths{end+1} = fig_save_path;
%             %     else
%             %         disp(['Figures already exist: ' fig_save_path]);
%             %     end
%             % end
%             % 
%             % if ~isempty(fig_save_paths)
%             %     SCEs_analysis(unique_animal_group, all_DF, all_Race, all_Raster, sampling_rate, animal_date_list);
%             end    
%     % 
%     %      % Save by date
%     %      elseif choice == 2
%     %         for k = 1:size(animal_date_list, 1)
%     %             % If mTor_part exists, include it in the save path
%     %             if ~isempty(mTor_part{k})
%     %                 save_path = fullfile(PathSave, type_part{k}, mTor_part{k}, animal_part{k}, date_part{k});
%     %             else
%     %                 save_path = fullfile(PathSave, type_part{k}, animal_part{k}, date_part{k});
%     %             end
%     % 
%     %             if ~exist(save_path, 'dir')
%     %                 mkdir(save_path);
%     %                 disp(['Created folder: ' save_path]);
%     %             end
%     % 
%     %             save_paths{end+1} = save_path;
%     %         end
%     % 
%     %         % Raster plot analysis
%     %         if analysis_choice == 1
%     %             for k = 1:length(save_paths)
%     %                 fig_save_path = fullfile(save_paths{k}, sprintf('raster_plots_%s_%s_%s.png', mTor_part{k}, animal_part{k}, age_part{k}));  
%     % 
%     %                 if ~exist(fig_save_path, 'file')
%     %                     fig_save_paths{end+1} = fig_save_path;
%     %                 else
%     %                     disp(['Raster plot already exists: ' fig_save_path]);
%     %                 end
%     %             end
%     % 
%     %             if ~isempty(fig_save_paths)
%     %                 build_rasterplots(results.raster, fig_save_paths);
%     %             end
%     % 
%     %         % Mean image analysis
%     %         elseif analysis_choice == 2
%     %             for k = 1:length(save_paths)
%     %                 fig_save_path = fullfile(save_paths{k}, sprintf('mean_image_%s_%s_%s.png', mTor_part{k}, animal_part{k}, age_part{k}));
%     % 
%     %                 if ~exist(fig_save_path, 'file')
%     %                     fig_save_paths{end+1} = fig_save_path;
%     %                 else
%     %                     disp(['Mean image already exists: ' fig_save_path]);
%     %                 end    
%     %             end
%     % 
%     %             if ~isempty(fig_save_paths)
%     %                 save_mean_images(results.ops, fig_save_paths);
%     %             end 
%     % 
%     %         % SCE analysis
%     %         elseif analysis_choice == 3
%     %             for k = 1:length(save_paths)
%     %                 fig_save_path = fullfile(save_paths{k}, sprintf('synchrony_peaks_%s_%s_%s.png', mTor_part{k}, animal_part{k}, age_part{k}));
%     % 
%     %                 if ~exist(fig_save_path, 'file')
%     %                     fig_save_paths{end+1} = fig_save_path;
%     %                 else
%     %                     disp(['Synchrony peaks already exist: ' fig_save_path]);
%     %                 end
%     %             end
%     % 
%     %             if ~isempty(fig_save_paths)
%     %                 save_SCE_analysis(results.SCEs, fig_save_paths);
%     %             end
%     %         else    
%     %             error('Invalid choice. Please enter 1, 2, or 3.');
%     %         end
%     %     else
%     %         error('Invalid choice. Please enter 1 or 2.');
%     %     end
% %     end
%     end
% end


%% Helper Functions

% Create subfolders for analysis
function [save_path, date_group_paths] = create_base_folders(base_path, folder_name, current_dates_group)
    save_path = fullfile(base_path, folder_name);
    if ~exist(save_path, 'dir')
        mkdir(save_path);
        disp(['Created folder: ', save_path]);
    end

    date_group_paths = cell(length(current_dates_group), 1);  % Chemins regroupés par date
    
    for k = 1:length(current_dates_group)
        % Crée le chemin complet pour chaque date
        date_path = fullfile(save_path, current_dates_group{k});
        
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


function [synchronous_frames, all_DF, all_isort1, all_isort2, all_Sm, all_Raster, all_MAct, all_Acttmp2] = load_or_process_raster_data(current_folders_group, raster_group_paths)    
    % Initialize cell arrays for outputs
    numFolders = length(raster_group_paths);
    all_DF = cell(numFolders, 1);
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
        filePath = fullfile(raster_group_paths{m}, 'results_raster.mat');
        
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
            
            % Assign 'synchronous_frames' if it exists in the file
            if isfield(data, 'synchronous_frames')
                synchronous_frames = data.synchronous_frames;
            end
            
        else
            current_folder_group = current_folders_group{m};
            [~, DF, ops, ~, ~] = load_and_preprocess_data(current_folder_group);

            MinPeakDistance = 5;
            sampling_rate = 29.87373388;  % Example value, replace with actual if needed
            synchronous_frames = round(0.2 * sampling_rate);  % Example: 0.2s of data

            % Call raster_processing function to process the data and get the results
            [isort1, isort2, Sm, Raster, MAct, Acttmp2] = raster_processing(DF, ops, MinPeakDistance, synchronous_frames, raster_group_paths{m});

            % Store the results in the respective cell arrays
            all_DF{m} = DF;
            all_isort1{m} = isort1;
            all_isort2{m} = isort2;
            all_Sm{m} = Sm;
            all_Raster{m} = Raster;
            all_MAct{m} = MAct;
            all_Acttmp2{m} = Acttmp2;
        end
    end

    %Assign all_DF to the workspace
    assignin('base', 'all_DF', all_DF);
    assignin('base', 'all_Raster', all_Raster);
    assignin('base', 'all_MAct', all_MAct);
    assignin('base', 'all_isort1', all_isort1);
    
end


function load_or_process_mean_images(mean_group_paths, current_folders_group, current_animal_group, current_dates_group)
    % Loop through each file path in directories
    numFolders = length(mean_group_paths);

    % Loop through each save path
    for m = 1:numFolders
        [~, ~, ops, ~, ~] = load_and_preprocess_data(current_folders_group{m});

       save_mean_images(current_animal_group, current_dates_group{m}, ops, mean_group_paths{m})
    end
end


function [all_sce_n_cells_threshold, all_Race, all_TRace, all_RasterRace] = load_or_process_sce_data(current_ani_path_group, current_folders_group, current_animal_group, current_dates_group, sce_group_paths)
    % Initialize output cell arrays to store results for each directory
    numFolders = length(sce_group_paths);  % Number of groups
    all_sce_n_cells_threshold = cell(numFolders, 1);
    all_Race = cell(numFolders, 1);
    all_TRace = cell(numFolders, 1);
    all_RasterRace = cell(numFolders, 1);

    % Initialize a flag to track if processing is needed
    process_needed = false;

    % First loop: Check if results exist and load them
    for m = 1:numFolders
        % Create the full file path for results_SCEs.mat
        filePath = fullfile(sce_group_paths{m}, 'results_SCEs.mat');

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
        % Generate the raster path and group paths
        [raster_path, raster_group_paths] = create_base_folders(current_ani_path_group, 'Raster plots', current_dates_group);

        % Load or process raster data
        [synchronous_frames, all_DF, ~, ~, ~, all_Raster, all_MAct, ~] = ...
            load_or_process_raster_data(current_folders_group, raster_group_paths);

        % Process data for missing files and save results
        for m = 1:numFolders
            % Create the full file path for results_SCEs.mat
            filePath = fullfile(sce_group_paths{m}, 'results_SCEs.mat');

            % Skip already loaded files
            if exist(filePath, 'file') == 2
                continue;
            end

            % Process and save the missing results
            disp(['Processing folder: ', sce_group_paths{m}]);

            % Extract relevant data for the current folder
            DF = all_DF{m};
            Raster = all_Raster{m};
            MAct = all_MAct{m};

            MinPeakDistancesce=3;
            WinActive=[];%find(speed>1);

            % Call the processing function
            [sce_n_cells_threshold, TRace, Race, RasterRace] = ...
                select_synchronies(sce_group_paths{m}, synchronous_frames, WinActive, DF, MAct, MinPeakDistancesce, Raster, current_animal_group, current_dates_group{m});

            % Store results in output variables
            all_sce_n_cells_threshold{m} = sce_n_cells_threshold;
            all_Race{m} = Race;
            all_TRace{m} = TRace;
            all_RasterRace{m} = RasterRace;
        end
    end
end


function [validDirectories, all_clusterMatrix, all_NClOK] = load_or_process_clusters_data(current_ani_path_group, current_folders_group, current_animal_group, current_dates_group, clusters_group_paths)
    
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

        % Generate the raster path and sce paths
        [raster_path, raster_group_paths] = create_base_folders(current_ani_path_group, 'Raster plots', current_dates_group);
        [sce_path, sce_group_paths] = create_base_folders(current_ani_path_group, 'SCEs', current_dates_group);

        % Load or process raster and sce data
        [synchronous_frames, all_DF, ~, ~, ~, all_Raster, all_MAct, ~] = ...
            load_or_process_raster_data(current_folders_group, raster_group_paths);
        
        [all_sce_n_cells_threshold, all_Race, all_TRace, all_RasterRace] = ...
            load_or_process_sce_data(current_ani_path_group, current_folders_group, current_animal_group, current_dates_group, sce_group_paths);

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
            DF = all_DF{m};
            Raster = all_Raster{m};
            MAct = all_MAct{m};
            Race = all_Race{m};

            kmean_iter = 100;
            kmeans_surrogate = 100;

            % Call the processing function
            [validDirectory, clusterMatrix, NClOK] = ...
                cluster_synchronies(clusters_group_paths{m}, DF, MAct, Raster, Race, kmean_iter, kmeans_surrogate);

            % Store results in output variables
            validDirectories{m} = validDirectory;
            all_clusterMatrix{m} = clusterMatrix;
            all_NClOK{m} = NClOK;
        end
    end
end