function process_data(PathSave, animal_date_list, truedataFolders, canceledIndices)
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
    ani_paths = cell(length(unique_animal_group), 1);
    date_paths = cell(length(unique_animal_group), 1);
    fig_save_paths = {};
    
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
    end
        
    % User choice for analysis type
    choice = input('Analysis options: by animal (1) or by date (2)? ');
    analysis_choice = input('Choose analysis type: raster plot (1), mean images (2), or SCE analysis (3)? ');

    % Handle saving by animal
    if choice == 1
        % Raster Plot Analysis
        if analysis_choice == 1
            raster_paths = create_base_folders(ani_paths, 'Raster plots');
            [date_group_paths, inds_group, date_group] = create_date_folders(raster_paths, unique_animal_group, animal_group, date_part, canceledIndices);
            
            [synchronous_frames, all_DF, all_isort1, all_isort2, all_Sm, all_Raster, all_MAct, all_Acttmp2] = load_or_process_raster_data(truedataFolders, date_group_paths);
       
            build_rasterplots(all_DF, all_isort1, all_MAct, animal_date_list, raster_paths, unique_animal_group, inds_group);


        % SCE Analysis
        elseif analysis_choice == 3
            sce_paths = create_analysis_folders(save_paths, 'SCEs');
            [date_group_paths, inds_group, date_group] = create_date_folders(raster_paths, unique_animal_group, animal_group, date_part, canceledIndices);
            
            raster_paths = create_analysis_folders(ani_paths, 'Raster plots');
            [synchronous_frames, all_DF, ~, ~, ~, all_Raster, all_MAct, ~] = load_or_process_raster_data(truedataFolders, raster_paths);

            [~, all_Race, ~, ~] = load_or_process_sce_data(date_paths, all_DF, all_MAct, all_Raster, synchronous_frames, animal_group, date_group);



            % % Generate SCE analysis figures
            %  for k = 1:length(unique_animal_group)
            %     current_animal = unique_animal_group{k};
            %     fig_save_path = fullfile(raster_paths{k}, sprintf('%s_synchrony_peaks.png', strrep(current_animal, ' ', '_')));
            % 
            %     if ~exist(fig_save_path, 'file')
            %         fig_save_paths{end+1} = fig_save_path;
            %     else
            %         disp(['Figures already exist: ' fig_save_path]);
            %     end
            % end
            % 
            % if ~isempty(fig_save_paths)
            %     SCEs_analysis(unique_animal_group, all_DF, all_Race, all_Raster, sampling_rate, animal_date_list);
            end    
    % 
    %      % Save by date
    %      elseif choice == 2
    %         for k = 1:size(animal_date_list, 1)
    %             % If mTor_part exists, include it in the save path
    %             if ~isempty(mTor_part{k})
    %                 save_path = fullfile(PathSave, type_part{k}, mTor_part{k}, animal_part{k}, date_part{k});
    %             else
    %                 save_path = fullfile(PathSave, type_part{k}, animal_part{k}, date_part{k});
    %             end
    % 
    %             if ~exist(save_path, 'dir')
    %                 mkdir(save_path);
    %                 disp(['Created folder: ' save_path]);
    %             end
    % 
    %             save_paths{end+1} = save_path;
    %         end
    % 
    %         % Raster plot analysis
    %         if analysis_choice == 1
    %             for k = 1:length(save_paths)
    %                 fig_save_path = fullfile(save_paths{k}, sprintf('raster_plots_%s_%s_%s.png', mTor_part{k}, animal_part{k}, age_part{k}));  
    % 
    %                 if ~exist(fig_save_path, 'file')
    %                     fig_save_paths{end+1} = fig_save_path;
    %                 else
    %                     disp(['Raster plot already exists: ' fig_save_path]);
    %                 end
    %             end
    % 
    %             if ~isempty(fig_save_paths)
    %                 build_rasterplots(results.raster, fig_save_paths);
    %             end
    % 
    %         % Mean image analysis
    %         elseif analysis_choice == 2
    %             for k = 1:length(save_paths)
    %                 fig_save_path = fullfile(save_paths{k}, sprintf('mean_image_%s_%s_%s.png', mTor_part{k}, animal_part{k}, age_part{k}));
    % 
    %                 if ~exist(fig_save_path, 'file')
    %                     fig_save_paths{end+1} = fig_save_path;
    %                 else
    %                     disp(['Mean image already exists: ' fig_save_path]);
    %                 end    
    %             end
    % 
    %             if ~isempty(fig_save_paths)
    %                 save_mean_images(results.ops, fig_save_paths);
    %             end 
    % 
    %         % SCE analysis
    %         elseif analysis_choice == 3
    %             for k = 1:length(save_paths)
    %                 fig_save_path = fullfile(save_paths{k}, sprintf('synchrony_peaks_%s_%s_%s.png', mTor_part{k}, animal_part{k}, age_part{k}));
    % 
    %                 if ~exist(fig_save_path, 'file')
    %                     fig_save_paths{end+1} = fig_save_path;
    %                 else
    %                     disp(['Synchrony peaks already exist: ' fig_save_path]);
    %                 end
    %             end
    % 
    %             if ~isempty(fig_save_paths)
    %                 save_SCE_analysis(results.SCEs, fig_save_paths);
    %             end
    %         else    
    %             error('Invalid choice. Please enter 1, 2, or 3.');
    %         end
    %     else
    %         error('Invalid choice. Please enter 1 or 2.');
    %     end
%     end
    end
end


%% Helper Functions

% Create subfolders for analysis
function analysis_paths = create_base_folders(base_paths, folder_name)
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

function [date_group_paths, inds_group, date_group] = create_date_folders(raster_paths, unique_animal_group, animal_group, date_part, canceledIndices)
    % Initialise les sorties
    date_group_paths = cell(length(unique_animal_group), 1);  % Chemins regroupés par animal
    inds = cell(length(unique_animal_group), 1);  % Indices par animal
    inds_group = cell(length(unique_animal_group), 1);  % Indices regroupés par animal et date
    
    % Nouvelle structure pour stocker les dates associées à chaque groupe d'animaux
    date_group = cell(length(unique_animal_group), 1);  % Structure pour stocker les dates
    
    for k = 1:length(unique_animal_group)
        current_animal_group = unique_animal_group{k};
        
        % Trouver les indices correspondant au groupe d'animaux
        index = find(strcmp(animal_group, current_animal_group));
        
        % Retirer les canceledIndices des indices trouvés
        index = setdiff(index, canceledIndices);
        
        % Sauvegarder les indices pour ce groupe dans inds
        inds{k} = index;  % Affecte directement à l'indice k
        
        % Obtenir les parties de date associées à ce groupe
        dates = date_part(index);
        
        % Initialiser les chemins et indices pour ce groupe
        group_paths = cell(1, length(dates));
        group_inds = cell(1, length(dates));
        
        % Créer des dossiers pour chaque date de ce groupe
        for l = 1:length(dates)
            date_path = fullfile(raster_paths{k}, dates{l});
            
            if ~exist(date_path, 'dir')
                mkdir(date_path);
                disp(['Created folder: ', date_path]);
            end
            
            % Ajouter le chemin et les indices au tableau spécifique au groupe
            group_paths{l} = date_path;
            group_inds{l} = index(l);  % L'indice correspondant à cette date
        end
        
        % Ajouter les chemins et indices du groupe à date_group_paths et inds_group
        date_group_paths{k} = group_paths;
        inds_group{k} = group_inds;
        
        % Ajouter la structure des dates pour chaque groupe d'animaux
        date_group{k} = dates;  % Stocke les dates pour ce groupe
    end
    
    % Optionnel: Assignation à l'espace de travail pour le débogage ou une utilisation ultérieure
    assignin('base', 'date_group_paths', date_group_paths);
    assignin('base', 'date_group', date_group);
end



function [synchronous_frames, all_DF, all_isort1, all_isort2, all_Sm, all_Raster, all_MAct, all_Acttmp2] = load_or_process_raster_data(truedataFolders, date_group_paths)
    % Initialize cell arrays for outputs
    numGroups = length(date_group_paths);  % Nombre de groupes (animaux, par ex.)
    all_DF = cell(numGroups, 1);
    all_isort1 = cell(numGroups, 1);
    all_isort2 = cell(numGroups, 1);
    all_Sm = cell(numGroups, 1);
    all_Raster = cell(numGroups, 1);
    all_MAct = cell(numGroups, 1);
    all_Acttmp2 = cell(numGroups, 1);
    synchronous_frames = [];

    % Loop through each group in date_group_paths
    for groupIdx = 1:numGroups
        currentGroupPaths = date_group_paths{groupIdx};  % Tous les paths pour ce groupe
        
        % Initialiser les cellules pour ce groupe
        all_DF{groupIdx} = cell(length(currentGroupPaths), 1);
        all_isort1{groupIdx} = cell(length(currentGroupPaths), 1);
        all_isort2{groupIdx} = cell(length(currentGroupPaths), 1);
        all_Sm{groupIdx} = cell(length(currentGroupPaths), 1);
        all_Raster{groupIdx} = cell(length(currentGroupPaths), 1);
        all_MAct{groupIdx} = cell(length(currentGroupPaths), 1);
        all_Acttmp2{groupIdx} = cell(length(currentGroupPaths), 1);

        % Process each path within the current group
        for pathIdx = 1:length(currentGroupPaths)
            currentPath = currentGroupPaths{pathIdx};
            filePath = fullfile(currentPath, 'results_raster.mat');

            % Check if the file exists
            if exist(filePath, 'file') == 2
                disp(['Loading file: ', filePath]);
                % Load the pre-existing results from the file
                data = load(filePath);

                % Display the field names loaded from the .mat file
                disp('Loaded variables:');
                disp(fieldnames(data));

                % Assign the relevant fields to the group-level cell arrays
                if isfield(data, 'DF')
                    all_DF{groupIdx}{pathIdx} = data.DF;
                end
                if isfield(data, 'isort1')
                    all_isort1{groupIdx}{pathIdx} = data.isort1;
                end
                if isfield(data, 'isort2')
                    all_isort2{groupIdx}{pathIdx} = data.isort2;
                end
                if isfield(data, 'Sm')
                    all_Sm{groupIdx}{pathIdx} = data.Sm;
                end
                if isfield(data, 'Raster')
                    all_Raster{groupIdx}{pathIdx} = data.Raster;
                end
                if isfield(data, 'MAct')
                    all_MAct{groupIdx}{pathIdx} = data.MAct;
                end
                if isfield(data, 'Acttmp2')
                    all_Acttmp2{groupIdx}{pathIdx} = data.Acttmp2;
                end
                
                % Assign 'synchronous_frames' if it exists in the file
                if isfield(data, 'synchronous_frames')
                    synchronous_frames = data.synchronous_frames;
                end
            else
                % If the file does not exist, process the raw data
                truedataFolder = truedataFolders{groupIdx}{pathIdx};  % Adjust for truedataFolders structure
                [~, DF, ops, ~, ~] = load_and_preprocess_data(truedataFolder);

                MinPeakDistance = 5;
                sampling_rate = 29.87373388;  % Example value, replace with actual if needed
                synchronous_frames = round(0.2 * sampling_rate);  % Example: 0.2s of data

                % Call raster_processing function to process the data and get the results
                [isort1, isort2, Sm, Raster, MAct, Acttmp2] = raster_processing(DF, ops, MinPeakDistance, synchronous_frames, currentPath);

                % Store the results in the respective cell arrays
                all_DF{groupIdx}{pathIdx} = DF;
                all_isort1{groupIdx}{pathIdx} = isort1;
                all_isort2{groupIdx}{pathIdx} = isort2;
                all_Sm{groupIdx}{pathIdx} = Sm;
                all_Raster{groupIdx}{pathIdx} = Raster;
                all_MAct{groupIdx}{pathIdx} = MAct;
                all_Acttmp2{groupIdx}{pathIdx} = Acttmp2;
            end
        end
    end

    % Assign data to the workspace for debugging or further use
    assignin('base', 'all_DF', all_DF);
    assignin('base', 'all_Raster', all_Raster);
    assignin('base', 'all_MAct', all_MAct);
    assignin('base', 'all_isort1', all_isort1);
end



function [all_sce_n_cells_threshold, all_Race, all_TRace, all_RasterRace] = load_or_process_sce_data(date_group_paths, all_DF, all_MAct, all_Raster, synchronous_frames, animal_part, date_part, inds)
    % Initialize output cell arrays to store results for each directory
    numGroups = length(date_group_paths);  % Number of groups
    all_sce_n_cells_threshold = cell(numGroups, 1);
    all_Race = cell(numGroups, 1);
    all_TRace = cell(numGroups, 1);
    all_RasterRace = cell(numGroups, 1);

    % Loop through each group in date_group_paths
    for groupIdx = 1:numGroups
        currentGroupPaths = date_group_paths{groupIdx};  % Get all paths for this group
        
        % Initialize the cell arrays for the current group
        all_sce_n_cells_threshold{groupIdx} = cell(length(currentGroupPaths), 1);
        all_Race{groupIdx} = cell(length(currentGroupPaths), 1);
        all_TRace{groupIdx} = cell(length(currentGroupPaths), 1);
        all_RasterRace{groupIdx} = cell(length(currentGroupPaths), 1);

        % Process each path within the current group
        for pathIdx = 1:length(currentGroupPaths)
            currentPath = currentGroupPaths{pathIdx};
            filePath = fullfile(currentPath, 'results_SCEs.mat');

            % Check if the file exists
            if exist(filePath, 'file') == 2
                disp(['Loading file: ', filePath]);
                % Load the pre-existing results from the file
                data = load(filePath);

                % Display the field names loaded from the .mat file
                disp('Loaded variables:');
                disp(fieldnames(data));

                % Assign the relevant fields to the group-level cell arrays
                if isfield(data, 'Race')
                    all_Race{groupIdx}{pathIdx} = data.Race;
                end
                if isfield(data, 'TRace')
                    all_TRace{groupIdx}{pathIdx} = data.TRace;
                end
                if isfield(data, 'RasterRace')
                    all_RasterRace{groupIdx}{pathIdx} = data.RasterRace;
                end
                if isfield(data, 'sce_n_cells_threshold')
                    all_sce_n_cells_threshold{groupIdx}{pathIdx} = data.sce_n_cells_threshold;
                end
            else
                % If the file does not exist, process the raw data
                DF = all_DF{groupIdx}{pathIdx};
                Raster = all_Raster{groupIdx}{pathIdx};
                MAct = all_MAct{groupIdx}{pathIdx};

                % Process the raw data and select synchronies
                [sce_n_cells_threshold, Race, RasterRace] = select_synchronies(directory, DF, MAct, MinPeakDistancesce, Raster, animal_date, synchronous_frames, WinActive);


                % Store the results in the respective cell arrays
                all_sce_n_cells_threshold{groupIdx}{pathIdx} = sce_n_cells_threshold;
                all_Race{groupIdx}{pathIdx} = Race;
                all_TRace{groupIdx}{pathIdx} = TRace;
                all_RasterRace{groupIdx}{pathIdx} = RasterRace;
            end
        end
    end
end

