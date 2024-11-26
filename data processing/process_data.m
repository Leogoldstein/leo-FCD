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
    %age_part = animal_date_list(:, 5); % Optional

    % Determine unique groups for analysis
    if strcmp(type_part{1}, 'jm')
        % Group by animal only
        unique_animal_group = unique(animal_part);
    else
        % Group by animal and mTor
        animal_group = strcat(animal_part, ' (', mTor_part, ')');
        unique_animal_group = unique(animal_group);
    end

    % Initialize save paths and figure paths
    save_paths = cell(length(unique_animal_group), 1);
    fig_save_paths = {};
    
    % User choice for analysis type
    choice = input('Analysis options: by animal (1) or by date (2)? ');
    analysis_choice = input('Choose analysis type: raster plot (1), mean images (2), or SCE analysis (3)? ');

    %% Handle saving by animal
    if choice == 1
        % Create directories for each unique animal group
        for k = 1:length(unique_animal_group)
            current_animal = unique_animal_group{k};
            save_path = fullfile(PathSave, type_part{1}, current_animal);

            % Create directory if it does not exist
            if ~exist(save_path, 'dir')
                mkdir(save_path);
                disp(['Created folder: ', save_path]);
            end

            % Save the path
            save_paths{k} = save_path;
        end
        %% Raster Plot Analysis
        if analysis_choice == 1
            raster_paths = create_analysis_folders(save_paths, 'Raster plots');
            [~, all_DF, all_isort1, ~, ~, ~, all_MAct, ~] = load_or_process_raster_data(truedataFolders, raster_paths);

            % Generate raster plots
             for k = 1:length(unique_animal_group)
                current_animal = unique_animal_group{k};
                fig_save_path = fullfile(raster_paths{k}, sprintf('%s_Raster plots.png', strrep(current_animal, ' ', '_')));

                if ~exist(fig_save_path, 'file')
                    fig_save_paths{end+1} = fig_save_path;
                else
                    disp(['Raster plots already exist: ' fig_save_path]);
                end
            end

            if ~isempty(fig_save_paths)
                build_rasterplots(all_DF, all_isort1, all_MAct, animal_date_list, fig_save_paths, animal_group, unique_animal_group)
            end
     

        %% SCE Analysis
        elseif analysis_choice == 3
            raster_paths = create_analysis_folders(save_paths, 'Raster plots');
            sce_paths = create_analysis_folders(save_paths, 'SCEs');

            [synchronous_frames, all_DF, ~, ~, ~, all_Raster, all_MAct, ~] = load_or_process_raster_data(truedataFolders, raster_paths);


            [~, all_Race, ~, ~] = load_or_process_sce_data(sce_paths, DF, all_MAct, all_Raster, synchronous_frames);

            % Generate SCE analysis figures
             for k = 1:length(unique_animal_group)
                current_animal = unique_animal_group{k};
                fig_save_path = fullfile(raster_paths{k}, sprintf('%s_synchrony_peaks.png', strrep(current_animal, ' ', '_')));

                if ~exist(fig_save_path, 'file')
                    fig_save_paths{end+1} = fig_save_path;
                else
                    disp(['Figures already exist: ' fig_save_path]);
                end
            end

            if ~isempty(fig_save_paths)
                SCEs_analysis(unique_animal_group, all_DF, all_Race, all_Raster, sampling_rate, animal_date_list);
            end    
        end
    end
end
   

%% Helper Functions

% Create subfolders for analysis
function analysis_paths = create_analysis_folders(base_paths, folder_name)
    analysis_paths = cell(length(base_paths), 1);
    for i = 1:length(base_paths)
        analysis_path = fullfile(base_paths{i}, folder_name);
        if ~exist(analysis_path, 'dir')
            mkdir(analysis_path);
            disp(['Created folder: ', analysis_path]);
        end
        analysis_paths{i} = analysis_path;
    end
end

function [synchronous_frames, all_DF, all_isort1, all_isort2, all_Sm, all_Raster, all_MAct, all_Acttmp2] = load_or_process_raster_data(truedataFolders, raster_paths)
    % Initialize output cell arrays to store results for each directory
    numFolders = length(raster_paths);
    all_DF = cell(numFolders, 1);
    all_isort1 = cell(numFolders, 1);
    all_isort2 = cell(numFolders, 1);
    all_Sm = cell(numFolders, 1);
    all_Raster = cell(numFolders, 1);
    all_MAct = cell(numFolders, 1);
    all_Acttmp2 = cell(numFolders, 1);
    
    % Loop through each raster directory path
    for j = 1:numFolders
        % Create the full file path for results_raster.mat
        filePath = fullfile(raster_paths{j}, 'results_raster.mat');
        
        % Check if the results file exists
        if exist(filePath, 'file') == 2
            try
                % Try to load the pre-existing results from the file
                data = load(filePath);
                
                % Assign the relevant fields to the output variables
                if isfield(data, 'DF')
                    all_DF{j} = data.DF;
                end
                if isfield(data, 'isort1')
                    all_isort1{j} = data.isort1;
                end
                if isfield(data, 'isort2')
                    all_isort2{j} = data.isort2;
                end
                if isfield(data, 'Sm')
                    all_Sm{j} = data.Sm;
                end
                if isfield(data, 'Raster')
                    all_Raster{j} = data.Raster;
                end
                if isfield(data, 'MAct')
                    all_MAct{j} = data.MAct;
                end
                if isfield(data, 'Acttmp2')
                    all_Acttmp2{j} = data.Acttmp2;
                end
            catch ME
                % If loading the data fails, display an error message but continue
                disp(['Error loading file: ' filePath]);
                disp(['Error message: ' ME.message]);
            end
        else
            % If file does not exist, process the data for the current folder
            truedataFolder = truedataFolders{j};
            [F, DF, ops, stat, iscell] = load_and_preprocess_data(truedataFolder);

            MinPeakDistance = 5;
            sampling_rate = 29.87373388; % Example value, replace with actual if needed
            synchronous_frames = round(0.2 * sampling_rate);  % Example: synchronous_frames corresponds to 0.2s of data
            
            % Call raster_processing function to process the data and get the results
            [isort1, isort2, Sm, Raster, MAct, Acttmp2] = raster_processing(DF, ops, MinPeakDistance, synchronous_frames, raster_paths{j});
            
            % Store the results in the respective cell arrays
            all_DF{j} = DF;
            all_isort1{j} = isort1;
            all_isort2{j} = isort2;
            all_Sm{j} = Sm;
            all_Raster{j} = Raster;
            all_MAct{j} = MAct;
            all_Acttmp2{j} = Acttmp2;
        end
    end
end


function [all_sce_n_cells_threshold, all_Race, all_TRace, all_RasterRace] = load_or_process_sce_data(sce_paths, DF, all_MAct, MinPeakDistancesce, all_Raster, synchronous_frames)
    % Initialize output cell arrays to store results for each directory
    numFolders = length(sce_paths);
    all_sce_n_cells_threshold = cell(numFolders, 1);
    all_Race = cell(numFolders, 1);
    all_TRace = cell(numFolders, 1);
    all_RasterRace = cell(numFolders, 1);
    
    % Loop through each SCE directory path
    for j = 1:numFolders
        % Create the full file path for results_SCEs.mat
        filePath = fullfile(sce_paths{j}, 'results_SCEs.mat');       
         
        % Check if the results file exists
        if exist(filePath, 'file') == 2
            try
                % Try to load the pre-existing results from the file
                data = load(filePath);
                
                % Assign the relevant fields to the output variables
                if isfield(data, 'Race')
                    all_Race{j} = data.Race;
                end
                if isfield(data, 'TRace')
                    all_TRace{j} = data.TRace;
                end
                if isfield(data, 'RasterRace')
                    all_RasterRace{j} = data.RasterRace;
                end
                if isfield(data, 'sce_n_cells_threshold')
                    all_sce_n_cells_threshold{j} = data.sce_n_cells_threshold;
                end
            catch ME
                % If loading the data fails, display an error message but continue
                disp(['Error loading file: ' filePath]);
                disp(['Error message: ' ME.message]);
            end
        
        else
           
            [sce_n_cells_threshold, Race, RasterRace] = select_synchronies(sce_paths, DF, all_MAct, MinPeakDistancesce, all_Raster, synchronous_frames, WinActive);
            
            % Store the results in the respective cell arrays
            all_sce_n_cells_threshold{j} = sce_n_cells_threshold;
            all_Race{j} = Race;
            all_TRace{j} = TRace;
            all_RasterRace{j} = RasterRace;
        end
    end
end
