function [selected_groups, daytime] = process_selected_group(selected_groups, check_data)
    
    last_animal_type = '';

    % Perform analyses for each group
    for k = 1:length(selected_groups)
        current_animal_group = selected_groups(k).animal_group;
        current_animal_type = selected_groups(k).animal_type;
        
        % Vérifier s’il y a un changement d’animal_type
        if ~strcmp(current_animal_type, last_animal_type)
                
            disp(['Changement de type détecté : ' last_animal_type ' -> ' current_animal_type]);
               
            % Prompt for the first choice
            processing_choice1 = input('Do you want to process the most recent folder for processing (1/2)? ', 's');
            
            % Check if processing_choice1 is 'no'
            if strcmp(processing_choice1, '2')
                % If the answer is 'no', prompt for the second choice
                processing_choice2 = input('Do you want to select an existing folder or create a new one? (1/2): ', 's');
            else
                processing_choice2 = [];
            end
        end
    
        % Mettre à jour la valeur pour la prochaine itération
        last_animal_type = current_animal_type;
        
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
            current_gcamp_folders_group = selected_groups(k).folders(:, 1);
            current_red_folders_group = selected_groups(k).folders(:, 2);
            current_blue_folders_group = selected_groups(k).folders(:, 3);
            current_green_folders_group = selected_groups(k).folders(:, 4);
            
            current_gcamp_folders_names_group = selected_groups(k).folders_names(:, 1);
            current_red_folders_names_group = selected_groups(k).folders_names(:, 2);
            current_blue_folders_names_group = selected_groups(k).folders_names(:, 3);
            current_green_folders_names_group = selected_groups(k).folders_names(:, 4);
            
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
        data = load_or_process_raster_data(gcamp_output_folders, current_gcamp_folders_group, current_env_group, folders_groups, blue_output_folders, date_group_paths, current_gcamp_TSeries_path);                    
        
        % Performing mean images
        meanImgs = save_mean_images(current_animal_group, current_dates_group, current_ages_group, gcamp_output_folders, current_gcamp_folders_group);

        % Performing motion_energy
        avg_block = 5; % Moyenne toutes les 5 frames
        [motion_energy_group, avg_motion_energy_group]  = load_or_process_movie(date_group_paths, gcamp_output_folders, avg_block);      
            
        if strcmpi(check_data, '1')

            % Perform data checking
            [selected_neurons_all, selected_in_original] = data_checking(data, gcamp_output_folders, current_gcamp_folders_group, current_animal_group, current_dates_group, current_ages_group, meanImgs);
            
            waitfor(selected_neurons_all);
            
            checked_indices = find(~cellfun(@isempty, selected_neurons_all));  % Indices des dossiers avec des neurones sélectionnés
            
            if ~isempty(checked_indices)
                % Filtrer les variables d'input en fonction de checked_indices
                filtered_date_group_paths = date_group_paths(checked_indices);
                filtered_gcamp_folders = current_gcamp_folders_names_group(checked_indices);
                filtered_blue_folders = current_blue_folders_names_group(checked_indices);
                
                % Créer des nouveaux dossiers de sortie avec ces dossiers filtrés
                processing_choice1 = '2';
                processing_choice2 = '2';
                daytime = datestr(currentDatetime, 'yy_mm_dd_HH_MM');
                [gcamp_output_folders_filtered, blue_output_folders_filtered] = create_base_folders(...
                    filtered_date_group_paths, filtered_gcamp_folders, filtered_blue_folders, ...
                    daytime, processing_choice1, processing_choice2, current_animal_group);
                
                % Mettre à jour uniquement les éléments aux indices checked_indices
                gcamp_output_folders(checked_indices) = gcamp_output_folders_filtered;
                blue_output_folders(checked_indices) = blue_output_folders_filtered;
               
                % Preprocess and process data
                data = load_or_process_raster_data(gcamp_output_folders, current_gcamp_folders_group, current_env_group, folders_groups, blue_output_folders, date_group_paths, current_gcamp_TSeries_path);                    
                meanImgs = save_mean_images(current_animal_group, current_dates_group, current_ages_group, gcamp_output_folders, current_gcamp_folders_group);     
                
            end

            %build_rasterplot_checking(data, gcamp_output_folders, current_animal_group, current_ages_group, avg_motion_energy_group);
        end
        
        build_rasterplot(data, gcamp_output_folders, current_animal_group, current_ages_group, avg_motion_energy_group)
       
        % Store processed data in selected_groups for this group
        selected_groups(k).gcamp_output_folders = gcamp_output_folders;
        selected_groups(k).blue_output_folders = blue_output_folders;
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

function removeFieldsByIndex(filePath, fields, indicesToRemove)
    % Vérifie si le fichier existe
    if exist(filePath, 'file') ~= 2
        error('Le fichier %s n''existe pas.', filePath);
    end

    % Charger les données
    loaded = load(filePath);

    % Vérifier que les indices sont valides
    if any(indicesToRemove < 1) || any(indicesToRemove > numel(fields))
        error('Indices invalides. Ils doivent être compris entre 1 et %d.', numel(fields));
    end

    % Boucle sur les indices
    for i = 1:numel(indicesToRemove)
        fieldName = fields{indicesToRemove(i)};
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



function data = load_or_process_raster_data(gcamp_output_folders, current_gcamp_folders_group, current_env_group, folders_groups, blue_output_folders, date_group_paths, current_gcamp_TSeries_path)

    numFolders = length(gcamp_output_folders);

    % Définir tous les champs dans une seule structure
    fields = {'F_gcamp', 'DF_gcamp', 'iscell', 'sampling_rate', 'synchronous_frames', ...
              'isort1_gcamp', 'isort2_gcamp', 'Sm_gcamp', ...
              'thresholds_gcamp', 'Acttmp2_gcamp', 'Raster_gcamp', 'MAct_gcamp', ...
              'outlines_gcampx', 'outlines_gcampy', 'gcamp_mask', 'gcamp_props', 'imageHeight', 'imageWidth', ...
              'F_blue', 'F_gcamp_not_blue', 'DF_blue', 'DF_gcamp_not_blue', ...
              'thresholds_blue', 'Raster_blue', 'MAct_blue', 'MAct_gcamp_not_blue', ...
              'num_cells_mask', 'mask_cellpose', 'props_cellpose', 'outlines_x_cellpose', 'outlines_y_cellpose', ...
              'F_combined', 'DF_combined', 'isort1_combined', 'blue_indices', 'isort2_combined', 'thresholds_combined', 'Raster_combined', 'MAct_combined', 'Sm_combined'};

    % Initialisation
    data = init_data_struct(numFolders, fields);

    MinPeakDistance = 5;
    numChannels = length(folders_groups);
    R = 5;

    for m = 1:numFolders
        filePath = fullfile(gcamp_output_folders{m}, 'results.mat');        

        if ~isfolder(gcamp_output_folders{m})
            mkdir(gcamp_output_folders{m});
        end

        % Charger les données existantes si elles existent
        if exist(filePath, 'file') == 2
            loaded = load(filePath);
            for f = 1:length(fields)
                data.(fields{f}){m} = getFieldOrDefault(loaded, fields{f}, []);
            end
        end
        
        % Option : supprimer un champs pour le recharger
        % Supprimer les 3 premiers champs
        %removeFieldsByIndex(filePath, fields, 1:11);
        
        % Sampling rate et synchronous_frames
        if isempty(data.sampling_rate{m})
            [~, sampling_rate, ~] = find_key_value(current_env_group{m});
            data.sampling_rate{m} = sampling_rate;
        end
        if isempty(data.synchronous_frames{m})
            data.synchronous_frames{m} = round(0.2 * data.sampling_rate{m});
        end
        
        % Traitement GCaMP
        if isempty(data.DF_gcamp{m})
            [~, F_gcamp, ops, ~, iscell] = load_data(current_gcamp_folders_group{m});
            DF_gcamp = DF_processing(F_gcamp);
            
            save(filePath, 'F_gcamp', 'iscell', 'DF_gcamp');
            
            data.F_gcamp{m} = F_gcamp;
            data.DF_gcamp{m} = DF_gcamp;
            data.iscell{m} = iscell;
        end

        if isempty(data.isort1_gcamp{m})
            [~, ~, ops, ~, ~] = load_data(current_gcamp_folders_group{m});
            [isort1_gcamp, isort2_gcamp, Sm_gcamp] = raster_processing(data.DF_gcamp{m}, current_gcamp_folders_group{m}, ops);
         
            save(filePath, 'isort1_gcamp','isort2_gcamp', 'Sm_gcamp', '-append');

            data.isort1_gcamp{m} = isort1_gcamp;
            data.isort2_gcamp{m} = isort2_gcamp;
            data.Sm_gcamp{m} = Sm_gcamp;

        end
        
        if isempty(data.thresholds_gcamp{m})
            [Raster_gcamp, MAct_gcamp, Acttmp2_gcamp, thresholds_gcamp] = Sumactivity(data.DF_gcamp{m}, MinPeakDistance, data.synchronous_frames{m});

            save(filePath, 'MinPeakDistance', 'thresholds_gcamp', 'Acttmp2_gcamp', 'Raster_gcamp', 'MAct_gcamp', '-append');
            
            data.thresholds_gcamp{m} = thresholds_gcamp;
            data.Acttmp2_gcamp{m} = Acttmp2_gcamp;
            data.Raster_gcamp{m} = Raster_gcamp;
            data.MAct_gcamp{m} = MAct_gcamp;
        end

        % Traitement outlines GCaMP
        if isempty(data.outlines_gcampx{m})
            [stat, iscell] = load_data_mat_npy(current_gcamp_folders_group{m});
            [NCell, outlines_gcampx, outlines_gcampy, ~, ~, ~] = load_calcium_mask(iscell, stat);
            [gcamp_mask, gcamp_props, imageHeight, imageWidth] = process_poly2mask(stat, NCell, outlines_gcampx, outlines_gcampy);

            save(filePath, 'outlines_gcampx', 'outlines_gcampy', 'gcamp_mask', ...
                 'gcamp_props', 'imageHeight', 'imageWidth', '-append');

            data.outlines_gcampx{m} = outlines_gcampx;
            data.outlines_gcampy{m} = outlines_gcampy;
            data.gcamp_mask{m} = gcamp_mask;
            data.gcamp_props{m} = gcamp_props;
            data.imageHeight{m} = imageHeight;
            data.imageWidth{m} = imageWidth;
        end

        % Traitement cellules bleues
        if ~isempty(blue_output_folders{m}) && isempty(data.DF_blue{m})
            disp(['Processing blue cells folder ', num2str(m), '...']);
            
            % Charger ou traiter les données Cellpose
            [~, aligned_image, npy_file_path, meanImg] = load_or_process_cellpose_TSeries(folders_groups, date_group_paths{m}, numChannels, m);
        
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
        
            if isempty(meanImg)
                fprintf('Skipping group %d: meanImg is empty.\n', m);
                continue;
            end
        
            if isa(meanImg, 'single')
                meanImg = uint16(meanImg);
            end
        
            % Affichage et correspondance des masques
            [matched_gcamp_idx, matched_cellpose_idx] = show_masks_and_overlaps(...
                data.gcamp_props{m}, props_cellpose, meanImg, aligned_image, ...
                data.outlines_gcampx{m}, data.outlines_gcampy{m}, ...
                outlines_x_cellpose, outlines_y_cellpose, R, m, blue_output_folders);
        
            % Extraire les traces fluorescence
            currentTSeriesPath = current_gcamp_TSeries_path{m};
            [F_blue, F_gcamp_not_blue] = get_blue_cells_rois(...
                data.F_gcamp{m}, matched_gcamp_idx, matched_cellpose_idx, ...
                num_cells_mask, mask_cellpose, currentTSeriesPath);
        
            % Traitement DF/F
            DF_blue = DF_processing(F_blue);
            [Raster_blue, MAct_blue, ~, thresholds_blue] = Sumactivity(DF_blue, MinPeakDistance, data.synchronous_frames{m});
        
            DF_gcamp_not_blue = DF_processing(F_gcamp_not_blue);
            [~, MAct_gcamp_not_blue, ~] = Sumactivity(DF_gcamp_not_blue, MinPeakDistance, data.synchronous_frames{m});
        
            % Ajuster la longueur pour cohérence
            min_cols = min(size(DF_gcamp_not_blue, 2), size(DF_blue, 2));
            DF_gcamp_not_blue = DF_gcamp_not_blue(:, 1:min_cols);
            DF_blue = DF_blue(:, 1:min_cols);
        
            % Sauvegarde
            save(filePath, 'F_blue', 'F_gcamp_not_blue', 'DF_blue', 'DF_gcamp_not_blue', ...
                'thresholds_blue', 'Raster_blue', 'MAct_blue', 'MAct_gcamp_not_blue', '-append');
        
            % Mise à jour de la structure data
            data.F_blue{m} = F_blue;
            data.F_gcamp_not_blue{m} = F_gcamp_not_blue;
            data.DF_blue{m} = DF_blue;
            data.DF_gcamp_not_blue{m} = DF_gcamp_not_blue;
            data.thresholds_blue{m} = thresholds_blue;
            data.Raster_blue{m} = Raster_blue;
            data.MAct_blue{m} = MAct_blue;
            data.MAct_gcamp_not_blue{m} = MAct_gcamp_not_blue;
            data.blue_indices{m} = matched_cellpose_idx;
        end

        % Traitement des données combinées
        if ~isempty(blue_output_folders{m}) && isempty(data.F_combined{m}) && ~isempty(data.DF_blue{m})
        
            % Combinaison des traces fluorescence
            F_combined = [data.F_gcamp_not_blue{m}; data.F_blue{m}];
            DF_combined = [data.DF_gcamp_not_blue{m}; data.DF_blue{m}];

            % Indices des cellules bleues
            NCells = size(data.DF_gcamp_not_blue{m}, 1);
            blue_indices = (NCells + 1):size(DF_combined, 1);
        
            % Traitement raster et tri
            [isort1_combined, isort2_combined, Sm_combined] = raster_processing(DF_combined, current_gcamp_folders_group{m});
            [Raster_combined, MAct_combined, ~, thresholds_combined] = Sumactivity(DF_combined, MinPeakDistance, data.synchronous_frames{m});
        
            % Sauvegarde
            save(filePath, 'F_combined', 'DF_combined', 'thresholds_combined', 'Raster_combined', 'MAct_combined', 'isort1_combined', 'blue_indices', '-append');
        
            % Mise à jour de la structure data
            data.F_combined{m} = F_combined;
            data.DF_combined{m} = DF_combined;
            data.isort1_combined{m} = isort1_combined;
            data.isort2_combined{m} = isort2_combined;
            data.blue_indices{m} = blue_indices;  
            data.Sm_combined{m} = Sm_combined;
            data.thresholds_combined{m} = thresholds_combined;
            data.Raster_combined{m} = Raster_combined;
            data.MAct_combined{m} = MAct_combined;
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
                choice = input('Voulez-vous ouvrir le film dans Fiji pour cropper ? (1/2) ', 's');
                if strcmpi(choice, '1')
                    fprintf('Ouverture de %s dans Fiji...\n', filepath);
    
                    % ouvrir Fiji avec le .tif
                    system(sprintf('"%s" "%s"', fijiPath, filepath));
                end

                motion_energy = compute_motion_energy(filepath);
                save(savePath, 'motion_energy');
                    
            end
            
            motion_energy_group{m} = motion_energy; 
            avg_motion_energy = average_frames(motion_energy, avg_block);  % ou 'trim'  
            avg_motion_energy_group{m} = avg_motion_energy;
    
        else
            fprintf('No movie found in %s.\n', camFolders{m});
            motion_energy_group{m} = [];
        end
    end
end
