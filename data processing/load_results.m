function [all_DF, all_ops, all_isort1, all_Raster, all_MAct, all_Race, dataFolders, all_data, animal_date_list, newStatPaths, newIscellPaths, newOpsPaths, validDirectories] = load_results(chosenSubfolderPaths)
    % Fonction pour charger plusieurs fichiers .mat depuis différents sous-dossiers

    % Vérifier que la liste des chemins fournie n'est pas vide
    if isempty(chosenSubfolderPaths)
        error('Aucun sous-dossier spécifié.');
    end

    % Initialiser des listes pour stocker les fichiers et les données
    allMatFiles = [];
    newStatPaths = [];
    newIscellPaths = [];
    newOpsPaths = [];
    all_DF = {};
    all_ops = {};
    all_isort1 = {};
    all_Raster = {};
    all_MAct = {};
    all_Race = {};
    dataFolders = {};
    animal_date_list = cell(length(chosenSubfolderPaths), 5);
    validDirectories = {};

    % Initialiser la structure de all_data
    all_data = struct();
    fields = {'TRace', 'RasterRace', 'sce_n_cells_threshold', 'IDX2', 'sCl', 'M', 'S', 'R', ...
              'CellScore', 'CellScoreN', 'CellCl', 'NClOK', 'assemblyraw', 'assemblystat', ...
              'RaceOK', 'clusterMatrix', 'std_distance_gcamp', 'meandistance_gcamp', ...
              'meandistance_assembly', 'mean_mean_distance_assembly', 'gcamp_props', ...
              'gcamp_mask', 'imageHeight', 'outline_gcampy', 'field_size_fraction', ...
              'num_SCEs', 'num_cells_fraction'};
    for f = fields
        all_data.(f{1}) = cell(1, length(chosenSubfolderPaths));
    end
    
    % Initialiser allMatFiles comme un tableau struct vide
    allMatFiles = struct('name', {}, 'folder', {}, 'date', {}, 'bytes', {}, 'isdir', {}, 'datenum', {});
    
    % Parcourir chaque sous-dossier et rechercher les fichiers .mat
    for i = 1:length(chosenSubfolderPaths)
        subfolderPath = chosenSubfolderPaths{i};
        matFiles = dir(fullfile(subfolderPath, '*.mat'));
    
        % Ajouter les fichiers trouvés à la liste
        if ~isempty(matFiles)
            for j = 1:length(matFiles)
                matFiles(j).folder = subfolderPath; % Ajouter le chemin du sous-dossier
            end
            % Concaténer les fichiers trouvés
            allMatFiles = vertcat(allMatFiles, matFiles); 
        end
    end
    
    % Vérifier s'il y a des fichiers .mat disponibles
    if isempty(allMatFiles)
        error('Aucun fichier .mat trouvé dans les sous-dossiers spécifiés.');
    end

    % Éliminer les fichiers dupliqués
    [~, uniqueIndices] = unique({allMatFiles.name});
    uniqueMatFiles = allMatFiles(uniqueIndices);

    % Afficher les fichiers .mat uniques et demander à l'utilisateur de choisir
    disp('Voici les fichiers disponibles :');
    for i = 1:length(uniqueMatFiles)
        disp([num2str(i) ': ' uniqueMatFiles(i).name]);
    end

    % Demander à l'utilisateur s'il souhaite charger tous les fichiers
    loadAll = input('Voulez-vous charger tous les fichiers disponibles ? (y/n) : ', 's');

    % Charger les fichiers selon le choix de l'utilisateur
    if strcmpi(loadAll, 'y')
        disp('Chargement de tous les fichiers disponibles...');
        for k = 1:length(chosenSubfolderPaths)
            subfolderPath = chosenSubfolderPaths{k};
            
            % Charger tous les fichiers préalablement définis
            filePaths = fullfile(subfolderPath, {uniqueMatFiles.name});

            % Charger chaque fichier .mat
            for j = 1:length(filePaths)
                filePath = filePaths{j};
                [~, fileName, ~] = fileparts(filePath);
                disp(['Chargement du fichier : ' filePath]);

                % Utiliser try-catch pour éviter que le code ne plante en cas d'erreur
                try
                    data = load(filePath);
                    % Charger les données spécifiques en fonction du fichier
                    [dataFolders, animal_date_list, newStatPaths, newIscellPaths, newOpsPaths, validDirectories, all_DF, all_ops, all_isort1, all_Raster, all_MAct, all_Race, all_data] = load_data_from_file(data, animal_date_list, fileName, k, dataFolders, newStatPaths, newIscellPaths, newOpsPaths, all_data, all_DF, all_ops, all_isort1, all_Raster, all_MAct, all_Race, validDirectories);
                catch ME
                    % Afficher un message d'avertissement sans bloquer l'exécution
                    disp(['Erreur lors du chargement du fichier : ' filePath]);
                    disp(['Message d''erreur : ' ME.message]);
                end
            end
        end
    else
        % Si l'utilisateur veut choisir des fichiers spécifiques
        selectedFiles = input('Entrez les numéros des fichiers que vous souhaitez charger (ex: 2 3) : ', 's');
        selectedFiles = str2num(selectedFiles); %#ok<ST2NM> % Convertir la chaîne en un tableau de nombres

        % Vérifier que la sélection est valide
        if isempty(selectedFiles) || any(selectedFiles < 1) || any(selectedFiles > length(uniqueMatFiles))
            error('Sélection de fichiers invalide.');
        end

        % Charger uniquement les fichiers sélectionnés
        for k = 1:length(chosenSubfolderPaths)
            subfolderPath = chosenSubfolderPaths{k};
            for j = selectedFiles
                filePath = fullfile(subfolderPath, uniqueMatFiles(j).name);
                [~, fileName, ~] = fileparts(filePath);
                disp(['Chargement du fichier : ' filePath]);

                % Utiliser try-catch pour éviter que le code ne plante en cas d'erreur
                try
                    data = load(filePath);
                    % Charger les données spécifiques en fonction du fichier
                    [dataFolders, animal_date_list, newStatPaths, newIscellPaths, newOpsPaths, validDirectories, all_DF, all_ops, all_isort1, all_Raster, all_MAct, all_Race, all_data] = load_data_from_file(data, animal_date_list, fileName, k, dataFolders, newStatPaths, newIscellPaths, newOpsPaths, all_data, all_DF, all_ops, all_isort1, all_Raster, all_MAct, all_Race, validDirectories);
                catch ME
                    % Afficher un message d'avertissement sans bloquer l'exécution
                    disp(['Erreur lors du chargement du fichier : ' filePath]);
                    disp(['Message d''erreur : ' ME.message]);
                end
            end
        end
    end

    % Afficher un message de confirmation
    disp('Les fichiers ont été chargés avec succès.');
end


function [dataFolders, animal_date_list, newStatPaths, newIscellPaths, newOpsPaths, validDirectories, all_DF, all_ops, all_isort1, all_Raster, all_MAct, all_Race, all_data] = load_data_from_file(data, animal_date_list, fileName, k, dataFolders, newStatPaths, newIscellPaths, newOpsPaths, all_data, all_DF, all_ops, all_isort1, all_Raster, all_MAct, all_Race, validDirectories)
    % Charger les données spécifiques en fonction du fichier
    switch fileName
        case 'paths'
            if isfield(data, 'dataFolder')
                dataFolders{k} = data.dataFolder;
            end
            if isfield(data, 'animal_date_list_k')
                animal_date_list{k,1} = data.animal_date_list_k{1,1};
                animal_date_list{k,2} = data.animal_date_list_k{1,2};
                animal_date_list{k,3} = data.animal_date_list_k{1,3};
                animal_date_list{k,4} = data.animal_date_list_k{1,4};
                animal_date_list{k,5} = data.animal_date_list_k{1,5};
            end
            if isfield(data, 'StatPath')
                newStatPaths{k} = data.StatPath;
            end
            if isfield(data, 'IscellPath')
                newIscellPaths{k} = data.IscellPath;
            end
            if isfield(data, 'OpsPath')
                newOpsPaths{k} = data.OpsPath;
            end

        case 'results_raster'
            if isfield(data, 'DF')
                all_DF{k} = data.DF;
            end
            if isfield(data, 'ops')
                all_ops{k} = data.ops;
            end
            if isfield(data, 'isort1')
                all_isort1{k} = data.isort1;
            end
            if isfield(data, 'Raster')
                all_Raster{k} = data.Raster;
            end
            if isfield(data, 'MAct')
                all_MAct{k} = data.MAct;
            end
    
        case 'results_SCEs'
            if isfield(data, 'Race')
                all_Race{k} = data.Race;
            end
            if isfield(data, 'TRace')
                all_data.TRace{k} = data.TRace;
            end
            if isfield(data, 'RasterRace')
                all_data.RasterRace{k} = data.RasterRace;
            end
            if isfield(data, 'sce_n_cells_threshold')
                all_data.sce_n_cells_threshold{k} = data.sce_n_cells_threshold;
            end

        case 'results_clustering'
            if isfield(data, 'IDX2')
                all_data.IDX2{k} = data.IDX2;
            end
            if isfield(data, 'IDX2')
                all_data.IDX2{k} = data.IDX2;
            end
            if isfield(data, 'sCl')
                all_data.sCl{k} = data.sCl;
            end
            if isfield(data, 'M')
                all_data.M{k} = data.M;
            end
            if isfield(data, 'S')
                all_data.S{k} = data.S;
            end
            if isfield(data, 'R')
                all_data.R{k} = data.R;
            end
            if isfield(data, 'CellScore')
                all_data.CellScore{k} = data.CellScore;
            end
            if isfield(data, 'CellScoreN')
                all_data.CellScoreN{k} = data.CellScoreN;
            end
            if isfield(data, 'CellCl')
                all_data.CellCl{k} = data.CellCl;
            end
            if isfield(data, 'NClOK')
                all_data.NClOK{k} = data.NClOK;
            end
            if isfield(data, 'validDirectory')
                validDirectories{k} = data.validDirectory;
            end
            if isfield(data, 'assemblyraw')
                all_data.assemblyraw{k} = data.assemblyraw;
            end
            if isfield(data, 'assemblystat')
                all_data.assemblystat{k} = data.assemblystat;
            end
            if isfield(data, 'RaceOK')
                all_data.RaceOK{k} = data.RaceOK;
            end
            if isfield(data, 'clusterMatrix')
                all_data.clusterMatrix{k} = data.clusterMatrix;
            end


        case 'results_distance'
            if isfield(data, 'imageHeight')
                all_data.imageHeight{k} = data.imageHeight;
            end
            if isfield(data, 'imageWidth')
                all_data.imageWidth{k} = data.imageWidth;
            end
            if isfield(data, 'gcamp_mask')
                all_data.gcamp_mask{k} = data.gcamp_mask;
            end
            if isfield(data, 'gcamp_props')
                all_data.gcamp_props{k} = data.gcamp_props;
            end
            if isfield(data, 'meandistance_gcamp')
                all_data.meandistance_gcamp{k} = data.meandistance_gcamp;
            end
            if isfield(data, 'std_distance_gcamp')
                all_data.std_distance_gcamp{k} = data.std_distance_gcamp;
            end
            if isfield(data, 'meandistance_assembly')
                all_data.meandistance_assembly{k} = data.meandistance_assembly;
            end
            if isfield(data, 'mean_mean_distance_assembly')
                all_data.mean_mean_distance_assembly{k} = data.mean_mean_distance_assembly;
            end

        case 'SCEs_evolution'

            if isfield(data, 'areas_microm2_k')
                all_data.field_size_fraction{k} = data.areas_microm2_k;
            end
            if isfield(data, 'num_cells_fraction_k')
                all_data.num_cells_fraction{k} = data.num_cells_fraction_k;
            end
            if isfield(data, 'num_sces_local_k')
                all_data.num_SCEs{k} = data.num_sces_local_k;
            end

        otherwise
            disp(['Fichier inconnu : ' fileName]);
    end
end

% function animal_name = extract_animal_name(subfolderPath)
%     % Function to extract the animal name from the subfolder path
%     parts = strsplit(subfolderPath, filesep);
%     animal_name = parts{end-2}; % Assuming the animal name is at this position
% end
% 
% function recording_date = extract_recording_date(subfolderPath)
%     % Function to extract the recording date from the subfolder path
%     parts = strsplit(subfolderPath, filesep);
%     recording_date = parts{end-1}; % Assuming the date is at this position
% end
