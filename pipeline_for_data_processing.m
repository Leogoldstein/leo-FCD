function pipeline_for_data_processing(selected_groups, include_blue_cells)
    % process_data generates and saves figures for raster plots, mean images, or SCE analysis
    % Inputs:
    % - PathSave: Path where results will be saved
    % - animal_date_list: Cell array containing animal information (type, group, animal, date, etc.)
    % - truedataFolders: List of paths to the true data folders
    
    PathSave = 'D:\Imaging\Outputs\';
    
    % Ask for analysis types, multiple choices separated by spaces
    analysis_choices_str = input('Choose analysis types (separated by spaces): Raster plot (1), Global measures of activity (2), SCEs (3), clusters analysis (4), or pairwise correlations (5)? ', 's');
     
    % Convert the string of choices into an array of numbers
    analysis_choices = str2num(analysis_choices_str); %#ok<ST2NM>

    % Pre-allocate variables for inter-groups analysis (btw animals for all dates)
    num_groups = length(selected_groups);  % Nombre de groupes sélectionnés
    gcamp_output_folders_groups = cell(num_groups, 1);
    gcamp_group_fields = {'DF_groups', 'MAct_groups', 'sampling_rate_groups', 'Raster_groups', 'MAct_groups', 'Race_groups', 'TRace_groups', 'sce_n_cells_threshold_groups', 'sces_distances_groups', 'RasterRace_groups', 'sce_n_cells_threshold_groups'};
    gcamp_data_groups = init_data_struct(num_groups, gcamp_group_fields);

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

        current_ages_group = selected_groups(k).ages;
        current_env_group = selected_groups(k).env;
       
        % Create the new path for the Excel file with the modified title
        pathexcel = [PathSave 'analysis.xlsx'];

        % Performing mean images                
        %save_mean_images(current_animal_group, current_dates_group, current_ages_group, gcamp_output_folders, current_gcamp_folders_group);

        gcamp_data = selected_groups(k).gcamp_data;
        mtor_data = selected_groups(k).mtor_data;
        all_data = selected_groups(k).all_data;
        
        gcamp_output_folders = selected_groups(k).gcamp_output_folders;
        blue_output_folders = selected_groups(k).blue_output_folders;

        % Loop through each selected analysis choice
        for i = 1:length(analysis_choices)
            analysis_choice = analysis_choices(i);  % Get the current analysis choice
            
            switch analysis_choice  
                case 1
                    disp(['Performing raster plot analysis for ', current_animal_group]);
                    if strcmpi(include_blue_cells, '1')
                        build_rasterplot(gcamp_data.DF, gcamp_data.isort1, gcamp_data.MAct, gcamp_output_folders, current_animal_group, current_ages_group, gcamp_data.sampling_rate, all_data.DF, all_data.isort1, all_data.blue_indices, mtor_data.MAct);
                        plot_DF(gcamp_data.DF, current_animal_group, current_ages_group, gcamp_output_folders, all_data.DF, all_data.blue_indices);
                    else
                        build_rasterplot(gcamp_data.DF, gcamp_data.isort1, gcamp_data.MAct, gcamp_output_folders, current_animal_group, current_ages_group, gcamp_data.sampling_rate); %all_data.DF, all_data.isort1, all_data.blue_indices, mtor_data.MAct
                        plot_DF(gcamp_data.DF, current_animal_group, current_ages_group, gcamp_output_folders) % all_data.DF, all_data.blue_indices
                        build_rasterplots(gcamp_data.DF, gcamp_data.isort1, gcamp_data.MAct, current_ani_path_group, current_animal_group, current_dates_group, current_ages_group);
                    end

                    case 2
                        disp(['Performing Global analysis of activity for ', current_animal_group]);
                        [all_recording_time, all_optical_zoom, all_position, all_time_minutes] = find_recording_infos(gcamp_output_folders, current_env_group);
                        [~, ~, ~, ~, ~, all_imageHeight, all_imageWidth] = load_or_process_image_data(gcamp_output_folders, current_gcamp_folders_group);
                        [NCell_all, mean_frequency_per_minute_all, std_frequency_per_minute_all, cell_density_per_microm2_all] = basic_metrics(gcamp_data.DF, gcamp_data.Raster, gcamp_data.MAct, gcamp_output_folders, gcamp_data.sampling_rate, all_imageHeight, all_imageWidth);
                    
                        if strcmpi(include_blue_cells, '1')
                            [NCell_all_blue, mean_frequency_per_minute_all_blue, std_frequency_per_minute_all_blue, cell_density_per_microm2_all_blue] = basic_metrics(mtor_data.DF, mtor_data.Raster, mtor_data.MAct, gcamp_output_folders, gcamp_data.sampling_rate, all_imageHeight, all_imageWidth);
                        end
                    
                        export_data(current_animal_group, current_gcamp_folders_names_group, current_ages_group, analysis_choice, pathexcel, current_animal_type, ...
                            all_recording_time, all_optical_zoom, all_position, all_time_minutes, ...
                            gcamp_data.sampling_rate, gcamp_data.synchronous_frames, NCell_all, NCell_all_blue, mean_frequency_per_minute_all, mean_frequency_per_minute_all_blue, std_frequency_per_minute_all, std_frequency_per_minute_all_blue, cell_density_per_microm2_all, cell_density_per_microm2_all_blue);
                    
                    case 3
                        disp(['Performing SCEs analysis for ', current_animal_group]);
                        gcamp_data = load_or_process_sce_data(current_animal_group, current_dates_group, gcamp_output_folders, gcamp_data);
                        
                        assignin('base', 'gcamp_data', gcamp_data);

                        gcamp_data_groups.Race_groups{k} = gcamp_data.Race;
                        gcamp_data_groups.TRace_groups{k} = gcamp_data.TRace;
                        gcamp_data_groups.sce_n_cells_threshold_groups{k} = gcamp_data.sce_n_cells_threshold;
                        gcamp_data_groups.sces_distances_groups{k} = gcamp_data.sces_distances;
                        gcamp_data_groups. RasterRace_groups{k} = gcamp_data.RasterRace;

                        %[all_num_sces, all_sce_frequency_seconds, all_avg_active_cell_SCEs, all_prop_active_cell_SCEs, all_avg_duration_ms] = SCEs_analysis(all_TRace, all_sampling_rate, all_Race, gcamp_data.Raster, all_sces_distances, gcamp_output_folders);
                        % 
                        % export_data(current_animal_group, current_gcamp_folders_names_group, current_ages_group, analysis_choice, pathexcel, current_animal_type, ...
                        %     all_sce_n_cells_threshold, all_num_sces, all_sce_frequency_seconds, all_avg_active_cell_SCEs, all_prop_active_cell_SCEs, all_avg_duration_ms);
                        % 
                    
                    case 4
                        disp(['Performing clusters analysis for ', current_animal_group]);
                        [gcamp_data.Raster, all_sce_n_cells_threshold, all_synchronous_frames, ~, all_IDX2, all_RaceOK, all_clusterMatrix, all_NClOK, all_assemblystat, all_outlines_gcampx, all_outlines_gcampy, all_meandistance_assembly] = load_or_process_clusters_data(current_animal_group, current_dates_group, gcamp_output_folders, current_gcamp_folders_group, current_env_group);
                        
                        plot_assemblies(all_assemblystat, all_outlines_gcampx, all_outlines_gcampy, all_meandistance_assembly, current_gcamp_folders_group);
                        plot_clusters_metrics(gcamp_output_folders, all_NClOK, all_RaceOK, all_IDX2, all_clusterMatrix, gcamp_data.Raster, all_sce_n_cells_threshold, all_synchronous_frames, current_animal_group, current_dates_group);
                    
                    case 5
                        disp(['Performing pairwise correlation analysis for ', current_animal_group]);
                        if strcmpi(include_blue_cells, '1')
                           [all_max_corr_gcamp_gcamp, all_max_corr_gcamp_mtor, all_max_corr_mtor_mtor] = compute_pairwise_corr(gcamp_data.DF, gcamp_output_folders, gcamp_data.sampling_rate, all_data.DF, all_data.blue_indices); 
                        else
                            [all_max_corr_gcamp_gcamp, all_max_corr_gcamp_mtor, all_max_corr_mtor_mtor] = compute_pairwise_corr(gcamp_data.DF, gcamp_output_folders, gcamp_data.sampling_rate);
                        end
                        
                        plot_pairwise_corr(current_ages_group, all_max_corr_gcamp_gcamp, current_ani_path_group, current_animal_group)

                        all_max_corr_gcamp_gcamp_groups{k} = all_max_corr_gcamp_gcamp;
                        all_max_corr_gcamp_mtor_groups{k} = all_max_corr_gcamp_mtor;
                        all_max_corr_mtor_mtor_groups{k} = all_max_corr_mtor_mtor;

                otherwise
                    disp('Invalid analysis choice. Skipping...');
            end

        end
    end

    % % Analyses globales après la boucle (une meme mesure pour plusieurs animaux)
    if analysis_choice == 3
        SCEs_groups_analysis2(selected_groups, gcamp_data_groups.DF_groups, gcamp_data_groups.Race_groups, gcamp_data_groups.TRace_groups, gcamp_data_groups.sampling_rate_groups, gcamp_data_groups.Raster_groups,  gcamp_data_groups.sce_n_cells_threshold_groups);
    end
    
    % if analysis_choice == 6
    %     corr_groups_violins_ind(selected_groups, daytime, all_max_corr_gcamp_gcamp_groups, all_max_corr_gcamp_mtor_groups, all_max_corr_mtor_mtor_groups);
    % end

    % Demander à l'utilisateur s'il souhaite créer un fichier PowerPoint
    create_ppt = input('Do you want to generate a PowerPoint presentation with the generated figure(s)? (1/2): ', 's');
    if strcmpi(create_ppt, '1')
        create_ppt_from_figs(selected_groups, gcamp_data_groups, gcamp_output_folders_groups, daytime, analysis_choices)
    end
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