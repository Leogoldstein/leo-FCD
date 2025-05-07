function [selected_groups, include_blue_cells] = process_selected_group(selected_groups)

    % Prompt for the first choice
    processing_choice1 = input('Do you want to process the most recent folder for processing (1/2)? ', 's');
    
    % Check if processing_choice1 is 'no'
    if strcmp(processing_choice1, '2')
        % If the answer is 'no', prompt for the second choice
        processing_choice2 = input('Do you want to select an existing folder or create a new one? (1/2): ', 's');
    else
        processing_choice2 = [];
    end
    
    % Extraire et aplatir directement les valeurs en un cell array de strings
    animal_type = string([selected_groups.animal_type]);
    
    % Vérifier si 'FCD' est présent
    if any(animal_type == "FCD")
        include_blue_cells = input('Do you want to include blue cells in your analysis? (1 for Yes / 2 for No): ', 's');
        
        % Vérification de l'entrée
        if ~ismember(include_blue_cells, {'1', '2'})
            disp('Invalid input, defaulting to 2 (No).');
            include_blue_cells = '2';
        end
    else
        include_blue_cells = '2'; % Valeur par défaut
    end
     
    % Define new fields to be added to selected_groups
    new_fields = {'gcamp_data', 'mtor_data', 'all_data'};
    
    % Check and add the new fields to each selected group
    for k = 1:length(selected_groups)
        for i = 1:length(new_fields)
            if ~isfield(selected_groups(k), new_fields{i})
                selected_groups(k).(new_fields{i}) = [];  % Create new fields if they don't exist
            end
        end
    end    

    % Perform analyses for each group
    for k = 1:length(selected_groups)
        current_animal_group = selected_groups(k).animal_group;
        current_animal_type = selected_groups(k).animal_type;
        current_ani_path_group = selected_groups(k).path;
        current_dates_group = selected_groups(k).dates;
        
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
            current_red_folders_group = cellfun(@string, selected_groups(k).folders(:, 2), 'UniformOutput', false);
            current_blue_folders_group = cellfun(@string, selected_groups(k).folders(:, 3), 'UniformOutput', false);
            current_green_folders_group = cellfun(@string, selected_groups(k).folders(:, 4), 'UniformOutput', false);
            
            current_gcamp_folders_names_group = cellfun(@string, selected_groups(k).folders_names(:, 1), 'UniformOutput', false);
            current_red_folders_names_group = cellfun(@string, selected_groups(k).folders_names(:, 2), 'UniformOutput', false);
            current_blue_folders_names_group = cellfun(@string, selected_groups(k).folders_names(:, 3), 'UniformOutput', false);
            current_green_folders_names_group = cellfun(@string, selected_groups(k).folders_names(:, 4), 'UniformOutput', false);
            
            % Create folders_groups as a cell array
            folders_groups = {
                [current_gcamp_folders_group, current_gcamp_folders_names_group],  % Group gCamp
                [current_red_folders_group, current_red_folders_names_group],      % Group Red
                [current_blue_folders_group, current_blue_folders_names_group],    % Group Blue
                [current_green_folders_group, current_green_folders_names_group]   % Group Green
            };
            assignin('base', 'folders_groups', folders_groups);
        else    
            current_gcamp_folders_group = selected_groups(k).folders;
            current_gcamp_folders_names_group = cell(1, length(current_gcamp_TSeries_path)); % Preallocate the cell array
            current_blue_folders_names_group = cell(1, length(current_gcamp_TSeries_path));
            for l = 1:length(current_gcamp_TSeries_path)
                [~, lastFolderName] = fileparts(current_gcamp_TSeries_path{l}); % Extract last folder name               
                current_gcamp_folders_names_group{l} = lastFolderName; % Store the folder name at index l
                current_blue_folders_names_group{l} = [];
                current_blue_folders_group{l} = [];
            end
            folders_groups = [];
        end
    
        current_env_group = selected_groups(k).env;
        
        currentDatetime = datetime('now');
        daytime = datestr(currentDatetime, 'yy_mm_dd_HH_MM');
        [gcamp_output_folders, blue_output_folders] = create_base_folders(date_group_paths, current_gcamp_folders_names_group, current_blue_folders_names_group, daytime, processing_choice1, processing_choice2, current_animal_group);     
        assignin('base', 'gcamp_output_folders', gcamp_output_folders);
        assignin('base', 'blue_output_folders', blue_output_folders);
    
        % Preprocess and process data
        [gcamp_data, mtor_data, all_data] = load_or_process_raster_data(gcamp_output_folders, current_gcamp_folders_group, current_env_group, include_blue_cells, folders_groups, blue_output_folders, date_group_paths, current_gcamp_TSeries_path);                    

        % Store processed data directly in selected_groups for this group
        selected_groups(k).gcamp_data = gcamp_data;
        selected_groups(k).mtor_data = mtor_data;
        selected_groups(k).all_data = all_data;
        
        % You can also store the output folders if needed
        selected_groups(k).gcamp_output_folders = gcamp_output_folders;
        selected_groups(k).blue_output_folders = blue_output_folders;
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


function [gcamp_data, mtor_data, all_data] = load_or_process_raster_data(gcamp_output_folders, current_gcamp_folders_group, current_env_group, include_blue_cells, folders_groups, blue_output_folders, date_group_paths, current_gcamp_TSeries_path)

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

        %delete(filePath);

        % Si DF_gcamp est vide, traiter les données
        if isempty(gcamp_data.DF{m})
            [F, DF_gcamp, ops, ~, iscell] = load_data(current_gcamp_folders_group{m});
            DF_gcamp = DF_processing(DF_gcamp);
            assignin('base', 'DF_gcamp', DF_gcamp);
            [isort1_gcamp, isort2_gcamp, Sm_gcamp] = raster_processing(DF_gcamp, current_gcamp_folders_group{m}, ops);
            [Raster_gcamp, MAct_gcamp, ~] = Sumactivity(DF_gcamp, MinPeakDistance, gcamp_data.synchronous_frames{m});
            
            % Sauvegarde des résultats
            save(filePath, 'MinPeakDistance', 'F', 'iscell', 'DF_gcamp', 'isort1_gcamp', ...
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