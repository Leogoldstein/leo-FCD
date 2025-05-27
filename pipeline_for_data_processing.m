function [analysis_choices, selected_groups] = pipeline_for_data_processing(selected_groups, include_blue_cells)
    % process_data generates and saves figures for raster plots, mean images, or SCE analysis
    % Inputs:
    % - PathSave: Path where results will be saved
    % - animal_date_list: Cell array containing animal information (type, group, animal, date, etc.)
    % - truedataFolders: List of paths to the true data folders
    
    PathSave = 'D:\Imaging\Outputs\';
    
    % Ask for analysis types, multiple choices separated by spaces
    analysis_choices_str = input('Choose analysis types (separated by spaces): Global measures of activity (1), SCEs (2), clusters analysis (3), pairwise correlations (4), or mouse motion analysis (5) ? ', 's');
     
    % Convert the string of choices into an array of numbers
    analysis_choices = str2num(analysis_choices_str); %#ok<ST2NM>

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
        current_gcamp_TSeries_path = cellfun(@string, selected_groups(k).pathTSeries(:, 1), 'UniformOutput', false);
        current_ages_group = selected_groups(k).ages;
        current_env_group = selected_groups(k).env;
       
        % Create the new path for the Excel file with the modified title
        pathexcel = [PathSave 'analysis.xlsx'];

        gcamp_output_folders = selected_groups(k).gcamp_output_folders;
        blue_output_folders = selected_groups(k).blue_output_folders;

        gcamp_data = selected_groups(k).gcamp_data;
        mtor_data = selected_groups(k).mtor_data;
        all_data = selected_groups(k).all_data;
        
        % Loop through each selected analysis choice
        for i = 1:length(analysis_choices)
            analysis_choice = analysis_choices(i);  % Get the current analysis choice
            
            switch analysis_choice  
                    case 1
                        disp(['Performing Global analysis of activity for ', current_animal_group]);
                        [all_recording_time, all_optical_zoom, all_position, all_time_minutes] = find_recording_infos(gcamp_output_folders, current_env_group);
                        gcamp_data = load_or_process_calcium_masks(gcamp_output_folders, current_gcamp_folders_group, gcamp_data);
                        [NCell_all, mean_frequency_per_minute_all, std_frequency_per_minute_all, cell_density_per_microm2_all] = basic_metrics(gcamp_data.DF, gcamp_data.Raster, gcamp_data.MAct, gcamp_output_folders, gcamp_data.sampling_rate, all_imageHeight, all_imageWidth);
                    
                        if strcmpi(include_blue_cells, '1')
                            [NCell_all_blue, mean_frequency_per_minute_all_blue, std_frequency_per_minute_all_blue, cell_density_per_microm2_all_blue] = basic_metrics(mtor_data.DF, mtor_data.Raster, mtor_data.MAct, gcamp_output_folders, gcamp_data.sampling_rate, all_imageHeight, all_imageWidth);
                        end
                    
                        export_data(current_animal_group, current_gcamp_folders_names_group, current_ages_group, analysis_choice, pathexcel, current_animal_type, ...
                            all_recording_time, all_optical_zoom, all_position, all_time_minutes, ...
                            gcamp_data.sampling_rate, gcamp_data.synchronous_frames, NCell_all, NCell_all_blue, mean_frequency_per_minute_all, mean_frequency_per_minute_all_blue, std_frequency_per_minute_all, std_frequency_per_minute_all_blue, cell_density_per_microm2_all, cell_density_per_microm2_all_blue);
                    
                    case 2
                        disp(['Performing SCEs analysis for ', current_animal_group]);
                        gcamp_data = load_or_process_sce_data(current_animal_group, current_dates_group, gcamp_output_folders, gcamp_data);
                        selected_groups(k).gcamp_data = gcamp_data;

                        %[all_num_sces, all_sce_frequency_seconds, all_avg_active_cell_SCEs, all_prop_active_cell_SCEs, all_avg_duration_ms] = SCEs_analysis(all_TRace, all_sampling_rate, all_Race, gcamp_data.Raster, all_sces_distances, gcamp_output_folders);
                        % 
                        % export_data(current_animal_group, current_gcamp_folders_names_group, current_ages_group, analysis_choice, pathexcel, current_animal_type, ...
                        %     all_sce_n_cells_threshold, all_num_sces, all_sce_frequency_seconds, all_avg_active_cell_SCEs, all_prop_active_cell_SCEs, all_avg_duration_ms);
                        % 
                    
                    case 3
                        disp(['Performing clusters analysis for ', current_animal_group]);
                        [gcamp_data.Raster, all_sce_n_cells_threshold, all_synchronous_frames, ~, all_IDX2, all_RaceOK, all_clusterMatrix, all_NClOK, all_assemblystat, all_outlines_gcampx, all_outlines_gcampy, all_meandistance_assembly] = load_or_process_clusters_data(current_animal_group, current_dates_group, gcamp_output_folders, current_gcamp_folders_group, current_env_group);
                        
                        plot_assemblies(all_assemblystat, all_outlines_gcampx, all_outlines_gcampy, all_meandistance_assembly, current_gcamp_folders_group);
                        plot_clusters_metrics(gcamp_output_folders, all_NClOK, all_RaceOK, all_IDX2, all_clusterMatrix, gcamp_data.Raster, all_sce_n_cells_threshold, all_synchronous_frames, current_animal_group, current_dates_group);
                    
                    case 4
                        gcamp_data = load_or_process_corr_data(gcamp_output_folders, gcamp_data, mtor_data, all_data);
                        selected_groups(k).gcamp_data = gcamp_data;
                        plot_pairwise_corr(current_ages_group, gcamp_data.max_corr_gcamp_gcamp, current_ani_path_group, current_animal_group)

                case 5
                    [motion_energy_group, avg_block] = load_or_process_movie(current_gcamp_TSeries_path, gcamp_output_folders);
                    %plot_motion_energy(motion_energy_group, gcamp_data.sampling_rate, avg_block)

                    build_rasterplot(gcamp_data.DF, gcamp_data.isort1, gcamp_data.MAct, gcamp_output_folders, current_animal_group, current_ages_group, gcamp_data.sampling_rate, all_data.DF, all_data.isort1, all_data.blue_indices, all_data.MAct, motion_energy_group, avg_block)
            
                otherwise
                    disp('Invalid analysis choice. Skipping...');
            end
        end
    end
    
    % if analysis_choice == 3
    %     figs = RasterChange_around_SCEs(selected_groups);
    %     figs = FiringRateChange_around_SCEs(selected_groups);
    % end

end

%% Helper Functions (loading and processing)

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


function gcamp_data = load_or_process_sce_data(current_animal_group, current_dates_group, gcamp_output_folders, gcamp_data)
    % Initialize output cell arrays to store results for each directory
    numFolders = length(gcamp_output_folders);  % Number of groups

    % Ajouter dynamiquement les nouveaux champs à gcamp_fields
    new_fields = {'Race', 'TRace', 'sces_distances', 'RasterRace', 'sce_n_cells_threshold'};

    % Vérifier et ajouter les nouveaux champs dans gcamp_data
    for i = 1:length(new_fields)
        if ~isfield(gcamp_data, new_fields{i})
            gcamp_data.(new_fields{i}) = cell(numFolders, 1);  % Créer les nouveaux champs s'ils n'existent pas
            [gcamp_data.(new_fields{i}){:}] = deal([]);  % Initialiser chaque cellule à []
        end
    end

    % First loop: Check if results exist and load them
    for m = 1:numFolders
        % Create the full file path for results_SCEs.mat
        filePath = fullfile(gcamp_output_folders{m}, 'results_SCEs.mat');

        if exist(filePath, 'file') == 2
            disp(['Loading file: ', filePath]);
            % Try to load the pre-existing results from the file
            data = load(filePath);
            
            gcamp_data.Race{m} = getFieldOrDefault(data, 'Race', []);
            gcamp_data.TRace{m} = getFieldOrDefault(data, 'TRace', []);
            gcamp_data.sces_distances{m} = getFieldOrDefault(data, 'sces_distances', []);
            gcamp_data.RasterRace{m} = getFieldOrDefault(data, 'RasterRace', []);
            gcamp_data.sce_n_cells_threshold{m} = getFieldOrDefault(data, 'sce_n_cells_threshold', []);

        end

        % If processing is needed, handle it outside the loop
        if isempty(gcamp_data.Race{m})
            disp('Processing SCEs...');
    
            MinPeakDistancesce=3;
            WinActive=[];%find(speed>1);

            [sce_n_cells_threshold, TRace, Race, sces_distances, RasterRace] = ...
                select_synchronies(gcamp_output_folders{m}, gcamp_data.synchronous_frames{m}, WinActive, gcamp_data.DF{m}, gcamp_data.MAct{m}, MinPeakDistancesce, gcamp_data.Raster{m}, current_animal_group, current_dates_group{m});
            
            gcamp_data.Race{m} = Race;
            gcamp_data.TRace{m} = TRace;
            gcamp_data.sces_distances{m} = sces_distances;
            gcamp_data.RasterRace{m} = RasterRace;
            gcamp_data.sce_n_cells_threshold{m} = sce_n_cells_threshold;

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
    gcamp_data = load_or_process_sce_data(current_animal_group, current_dates_group, gcamp_output_folders, gcamp_data);

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
       gcamp_data = load_or_process_calcium_masks(gcamp_output_folders, current_gcamp_folders_group, gcamp_data);

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


 function gcamp_data = load_or_process_calcium_masks(gcamp_output_folders, current_gcamp_folders_group, gcamp_data)

    numFolders = length(gcamp_output_folders);  % Number of groups
    
    % Ajouter dynamiquement les nouveaux champs à gcamp_fields
    new_fields = {'outlines_gcampx', 'outlines_gcampy', 'gcamp_mask', ...
                  'gcamp_props', 'imageHeight', 'imageWidth'};
    
    % Vérifier et ajouter les nouveaux champs dans gcamp_data
    for i = 1:length(new_fields)
        if ~isfield(gcamp_data, new_fields{i})
            gcamp_data.(new_fields{i}) = cell(numFolders, 1);  % Créer les nouveaux champs s'ils n'existent pas
            [gcamp_data.(new_fields{i}){:}] = deal([]);  % Initialiser chaque cellule à []
        end
    end
    
    % First loop: Check if results exist and load them
    for m = 1:numFolders
        % Create the full file path for results_SCEs.mat
        filePath = fullfile(gcamp_output_folders{m}, 'results_image.mat');

        %delete(filePath)
    
        if exist(filePath, 'file') == 2
            disp(['Loading file: ', filePath]);
            % Try to load the pre-existing results from the file
            data = load(filePath);
            
            % Assign the data to the appropriate fields in gcamp_data
            gcamp_data.outlines_gcampx{m} = getFieldOrDefault(data, 'outlines_gcampx', []);
            gcamp_data.outlines_gcampy{m} = getFieldOrDefault(data, 'outlines_gcampy', []);
            gcamp_data.gcamp_mask{m} = getFieldOrDefault(data, 'gcamp_mask', []);
            gcamp_data.gcamp_props{m} = getFieldOrDefault(data, 'gcamp_props', []);
            gcamp_data.imageHeight{m} = getFieldOrDefault(data, 'imageHeight', []);
            gcamp_data.imageWidth{m} = getFieldOrDefault(data, 'imageWidth', []);

        else
            % Traiter les données si le fichier n'existe pas
            [stat, iscell] = load_data_mat_npy(current_gcamp_folders_group{m});
            [NCell, outlines_gcampx, outlines_gcampy, ~, ~, ~] = load_calcium_mask(iscell, stat);
    
            % Créer poly2mask et obtenir les propriétés
            [gcamp_mask, gcamp_props, imageHeight, imageWidth] = process_poly2mask(stat, NCell, outlines_gcampx, outlines_gcampy);
    
            % Sauvegarder les résultats
            save(filePath, 'outlines_gcampx', 'outlines_gcampy', 'gcamp_mask', ...
                 'gcamp_props', 'imageHeight', 'imageWidth');


            gcamp_data.outlines_gcampx{m} = outlines_gcampx;
            gcamp_data.outlines_gcampy{m} = outlines_gcampy;
            gcamp_data.gcamp_mask{m} = gcamp_mask;
            gcamp_data.gcamp_props{m} = gcamp_props;
            gcamp_data.imageHeight{m} = imageHeight;
            gcamp_data.imageHeight{m} = imageWidth;

        end
    end
end


 function gcamp_data = load_or_process_corr_data(gcamp_output_folders, gcamp_data, mtor_data, all_data)
    % Nombre de dossiers à traiter
    numFolders = length(gcamp_output_folders);

    % Champs à créer dynamiquement
    new_fields = {'max_corr_gcamp_gcamp', 'max_corr_gcamp_mtor', 'max_corr_mtor_mtor'};

    % Initialisation des champs manquants
    for i = 1:length(new_fields)
        if ~isfield(gcamp_data, new_fields{i})
            gcamp_data.(new_fields{i}) = cell(numFolders, 1);
            [gcamp_data.(new_fields{i}){:}] = deal([]);
        end
    end

    % Parcours des dossiers
    for m = 1:numFolders
        % Chemin vers le fichier de sauvegarde
        filePath = fullfile(gcamp_output_folders{m}, 'results_corrs.mat');

        delete(filePath)

        % Si le fichier existe, charger les données
        if exist(filePath, 'file') == 2
            disp(['Loading file: ', filePath]);
            data = load(filePath);

            gcamp_data.max_corr_gcamp_gcamp{m} = getFieldOrDefault(data, 'max_corr_gcamp_gcamp', []);
            gcamp_data.max_corr_gcamp_mtor{m}  = getFieldOrDefault(data, 'max_corr_gcamp_mtor', []);
            gcamp_data.max_corr_mtor_mtor{m}   = getFieldOrDefault(data, 'max_corr_mtor_mtor', []);
        end

        % Si les données sont manquantes, les recalculer
        if isempty(gcamp_data.max_corr_gcamp_gcamp{m})

            disp(['Computing and saving pairwise correlations for folder ', num2str(m)]);

            [max_corr_gcamp_gcamp, max_corr_gcamp_mtor, max_corr_mtor_mtor] = ...
                compute_pairwise_corr(gcamp_data.DF{m}, gcamp_output_folders{m}, all_data.DF{m}, all_data.blue_indices{m});

            % Mise à jour
            gcamp_data.max_corr_gcamp_gcamp{m} = max_corr_gcamp_gcamp;
            gcamp_data.max_corr_gcamp_mtor{m} = max_corr_gcamp_mtor;
            gcamp_data.max_corr_mtor_mtor{m}  = max_corr_mtor_mtor;

            if ~isempty(max_corr_gcamp_mtor) & ~isempty(max_corr_mtor_mtor)
                % Sauvegarde complète
                save(filePath, 'max_corr_gcamp_gcamp', 'max_corr_gcamp_mtor', 'max_corr_mtor_mtor');
            else
                % Sauvegarde partielle
                save(filePath, 'max_corr_gcamp_gcamp');
            end
        end
    end
 end

function [motion_energy_group, avg_block] = load_or_process_movie(current_gcamp_TSeries_path, gcamp_output_folders)

    numFolders = length(current_gcamp_TSeries_path);
    motion_energy_group = cell(numFolders, 1);
    idx = 1;

    for m = 1:numFolders
        filePath = fullfile(gcamp_output_folders{m}, 'results_movie.mat'); 

        if exist(filePath, 'file') == 2 
            disp(['Loading file: ', filePath]);
            data = load(filePath);
            motion_energy = data.motion_energy;

        else
            currentTSeriesPath = current_gcamp_TSeries_path{m};

            % Liste des .tif valides
            tiffFilesStruct = dir(fullfile(currentTSeriesPath, '*.tif'));
            fileNames = {tiffFilesStruct.name};
            excludeMask = contains(fileNames, 'companion.ome') | contains(fileNames, 'Concatenated');
            tiffFiles = fileNames(~excludeMask);
            [~, idxOrder] = sort(tiffFiles);  
            tiffFiles = tiffFiles(idxOrder);

            motion_energy_all = [];  % contiendra toutes les motion_energy concaténées

            for tIdx = 1:numel(tiffFiles)
                filename = fullfile(currentTSeriesPath, tiffFiles{tIdx});
                disp(['Processing: ', filename]);     

                energy = compute_motion_energy(filename);
                motion_energy_all = [motion_energy_all; energy];  % concatène verticalement
                idx = idx + 1;
            end

            motion_energy = motion_energy_all;  % résultat final à sauvegarder
            save(filePath, 'motion_energy');
        end

        % Moyenne les données
        avg_block = 5; % Moyenne toutes les 5 frames
        motion_energy = average_frames(motion_energy, avg_block);  % ou 'trim'       
    end
    motion_energy_group{m} = motion_energy;
end

function avg_data = average_frames(data, avg_block)
    % Vérifie que la première dimension est divisible par avg_block
    if mod(size(data, 1), avg_block) ~= 0
        error('Data length %d is not divisible by avg_block %d', size(data,1), avg_block);
    end

    % Si data est un vecteur colonne ou ligne (1D)
    if isvector(data)
        data = data(:); % s'assurer que c'est une colonne
        reshaped = reshape(data, avg_block, []);
        avg_data = mean(reshaped, 1)';  % moyenne ligne par ligne, puis transposer en colonne
    else
        % Cas 2D : reshape en (avg_block, new_time, nb_features)
        [T, D] = size(data);
        reshaped = reshape(data, avg_block, [], D);  % taille: (avg_block, new_time, D)
        avg_data = squeeze(mean(reshaped, 1));       % moyenne le long de la 1re dim
    end

    fprintf('Congrats! New shape is %d\n', size(avg_data, 1));
end
