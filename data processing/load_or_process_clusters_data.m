function data = load_or_process_clusters_data(current_animal_group, current_dates_group, gcamp_output_folders, current_env_group, data)
    
    % Initialize output cell arrays to store results for each directory
    numFolders = length(gcamp_output_folders);  % Number of groups
    
     % Ajouter dynamiquement les nouveaux champs à gcamp_fields
    new_fields = {'IDX2', 'sCl', 'M', 'S', 'R', 'CellScore', 'CellScoreN', 'CellCl', ...
                              'NClOK', 'validDirectory','assemblystat', 'RaceOK', 'clusterMatrix', 'meandistance_assembly'};
 
    % Initialize a flag to track if processing is needed
    further_process_needed = false;
    
    % Load Race_gcamp in prevision of clustering
    if ~isfield(data, 'Race_gcamp') || isempty(data.Race_gcamp)
        data = load_or_process_sce_data(current_animal_group, current_dates_group, gcamp_output_folders, data);
    end

    % First loop: Check if results exist and load them
    for m = 1:numFolders
        % Chemin complet pour le fichier results_clustering.mat
        filePath = fullfile(gcamp_output_folders{m}, 'results_clustering.mat');
        
        %delete(filePath)
        
        if exist(filePath, 'file') == 2
            disp(['Loading file: ', filePath]);
            % Try to load the pre-existing results from the file
            loaded = load(filePath);
            for f = 1:length(new_fields)
                data.(new_fields{f}){m} = getFieldOrDefault(loaded, new_fields{f}, []);
            end
        end

        required_fields = setdiff(new_fields, {'meandistance_assembly'});  % exclure ce champ
        hasAllRequiredFields = all(cellfun(@(field) isfield(data, field), required_fields));

        if hasAllRequiredFields
            % Charger les informations supplémentaires pour les distances
            if ~isempty(data.meandistance_assembly{m})
                meandistance_assembly = data.meandistance_assembly{m};
            else
                % Si les fichiers sont absents, marquer pour traitement
                further_process_needed = true;
            end     
        else
            % Extract relevant data for the current folder
            kmean_iter = 100;
            kmeans_surrogate = 100;

            % Call the processing function
            [IDX2, sCl, M, S, R, CellScore, CellScoreN, CellCl, NClOK, assemblyraw, assemblystat, RaceOK, clusterMatrix, validDirectory] = ...
                cluster_synchronies(gcamp_output_folders{m}, data.Race_gcamp{m}, kmean_iter, kmeans_surrogate);

            data.IDX2{m}           = IDX2;
            data.sCl{m}            = sCl;
            data.M{m}              = M;
            data.S{m}              = S;
            data.R{m}              = R;
            data.CellScore{m}      = CellScore;
            data.CellScoreN{m}     = CellScoreN;
            data.CellCl{m}         = CellCl;
            data.NClOK{m}          = NClOK;
            data.assemblystat{m}   = assemblystat;
            data.RaceOK{m}         = RaceOK;
            data.clusterMatrix{m}  = clusterMatrix;
            data.validDirectory{m} = validDirectory;

            further_process_needed = true;
        end    
    end

    % Si des traitements sont nécessaires pour des fichiers manquants
    if further_process_needed
        % Charger les fichiers nécessaires pour les distances
        for m = 1:numFolders
            % Create the full file path for results_SCEs.mat
            filePath = fullfile(gcamp_output_folders{m}, 'results_clustering.mat');

            assemblystat = data.assemblystat{m};
            gcamp_props = data.gcamp_props{m};

            % Calculer les distances
            [~, ~, ~, size_pixel] = find_key_value(current_env_group{m});
            [meandistance_gcamp, meandistance_assembly, mean_mean_distance_assembly] = ...
                distance_btw_centroid(size_pixel, gcamp_props, assemblystat, filePath);
            
            data.meandistance_gcamp{m} = meandistance_gcamp;
            data.meandistance_assembly{m} = meandistance_assembly;
            data.mean_mean_distance_assembly{m} = mean_mean_distance_assembly;
        end
    end
end

function value = getFieldOrDefault(structure, fieldName, defaultValue)
    if isfield(structure, fieldName)
        value = structure.(fieldName);
    else
        value = defaultValue;
    end
end