function selected_groups = pipeline_for_data_processing(selected_groups, analysis_choices)
    % process_data generates and saves figures for raster plots, mean images, or SCE analysis
    % Inputs:
    % - PathSave: Path where results will be saved
    % - animal_date_list: Cell array containing animal information (type, group, animal, date, etc.)
    % - truedataFolders: List of paths to the true data folders
    
    PathSave = 'D:\Imaging\Outputs\';
    all_results = [];  % tableau de structures vide

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

        if ~strcmp(current_animal_type, 'jm')
            current_gcamp_folders_group = selected_groups(k).folders(:, 1);            
            current_gcamp_folders_names_group = selected_groups(k).folders_names(:, 1);           
        else    
            current_gcamp_folders_group = selected_groups(k).folders;
            current_gcamp_folders_names_group = cell(1, length(current_gcamp_TSeries_path)); % Preallocate the cell array
            for l = 1:length(current_gcamp_TSeries_path)
                [~, lastFolderName] = fileparts(current_gcamp_TSeries_path{l}); % Extract last folder name               
                current_gcamp_folders_names_group{l} = lastFolderName; % Store the folder name at index l
            end
        end

        current_ages_group = selected_groups(k).ages;
        current_env_group = selected_groups(k).env;
       
        % Create the new path for the Excel file with the modified title
        pathexcel = [PathSave 'analysis.xlsx'];

        gcamp_output_folders = selected_groups(k).gcamp_output_folders;
        blue_output_folders = selected_groups(k).blue_output_folders;

        data = selected_groups(k).data;
        
        % Loop through each selected analysis choice
        for i = 1:length(analysis_choices)
            analysis_choice = analysis_choices(i);  % Get the current analysis choice
            
            switch analysis_choice  
                    case 1
                        data = load_or_process_corr_data(gcamp_output_folders, data);
                        selected_groups(k).data = data;
                        plot_pairwise_corr(current_ages_group, data.max_corr_gcamp_gcamp, current_ani_path_group, current_animal_group)

                   case 2
                        disp(['Performing SCEs analysis for ', current_animal_group]);
                        data = load_or_process_sce_data(current_animal_group, current_dates_group, gcamp_output_folders, data);
                        selected_groups(k).data = data;

                    case 3
                        disp(['Performing Global analysis of activity for ', current_animal_group]);
                        res = basic_metrics(current_animal_group, data, gcamp_output_folders, current_env_group, current_gcamp_folders_names_group, current_ages_group);
                        all_results = [all_results, res];  % concaténer les résultats

                    case 4
                        disp(['Performing clusters analysis for ', current_animal_group]);
                        [gcamp_data.Raster, all_sce_n_cells_threshold, all_synchronous_frames, ~, all_IDX2, all_RaceOK, all_clusterMatrix, all_NClOK, all_assemblystat, all_outlines_gcampx, all_outlines_gcampy, all_meandistance_assembly] = load_or_process_clusters_data(current_animal_group, current_dates_group, gcamp_output_folders, current_gcamp_folders_group, current_env_group);
                        
                        plot_assemblies(all_assemblystat, all_outlines_gcampx, all_outlines_gcampy, all_meandistance_assembly, current_gcamp_folders_group);
                        plot_clusters_metrics(gcamp_output_folders, all_NClOK, all_RaceOK, all_IDX2, all_clusterMatrix, gcamp_data.Raster, all_sce_n_cells_threshold, all_synchronous_frames, current_animal_group, current_dates_group);
            
                otherwise
                    disp('Invalid analysis choice. Skipping...');
            end
        end
    end
    
    if analysis_choice == 3
        export_data(all_results, pathexcel, current_animal_type)
    end
    
    % if analysis_choice == 3
    %     figs = RasterChange_around_SCEs(selected_groups);
    %     figs = FiringRateChange_around_SCEs(selected_groups);
    % end

end

%% Helper Functions (loading and processing)

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



