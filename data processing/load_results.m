function [results] = load_results(chosenSubfolderPaths) 
    % Fonction pour charger plusieurs fichiers .mat depuis différents sous-dossiers

    if isempty(chosenSubfolderPaths)
        error('Aucun sous-dossier spécifié.');
    end

    allMatFiles = struct('name', {}, 'folder', {}, 'date', {}, 'bytes', {}, 'isdir', {}, 'datenum', {});
    dataFolders = {};
    animal_date_list = cell(length(chosenSubfolderPaths), 5); % Initialisation d'animal_date_list
    results = struct(); % Structure dynamique pour les résultats
    
    % Initialisation des variables dans la structure results.paths
    results.paths = struct('dataFolders', [], 'newStatPaths', [], 'newIscellPaths', [], 'newOpsPaths', []);

    for i = 1:length(chosenSubfolderPaths)
        subfolderPath = chosenSubfolderPaths{i};
        matFiles = dir(fullfile(subfolderPath, '*.mat'));

        if ~isempty(matFiles)
            for j = 1:length(matFiles)
                matFiles(j).folder = subfolderPath; % Ajouter le chemin du sous-dossier
            end
            allMatFiles = vertcat(allMatFiles, matFiles); 
        end
    end

    if isempty(allMatFiles)
        disp('Aucun fichier .mat trouvé dans les sous-dossiers spécifiés. La structure "results" sera vide.');
        return; % Retourne un "results" vide
    end

    % Éliminer les fichiers dupliqués
    [~, uniqueIndices] = unique({allMatFiles.name});
    uniqueMatFiles = allMatFiles(uniqueIndices);

    disp('Voici les fichiers disponibles :');
    for i = 1:length(uniqueMatFiles)
        disp([num2str(i) ': ' uniqueMatFiles(i).name]);
    end

    loadAll = input('Voulez-vous charger tous les fichiers disponibles ? (y/n) : ', 's');

    if strcmpi(loadAll, 'y')
        disp('Chargement de tous les fichiers disponibles...');
        selectedFiles = 1:length(uniqueMatFiles);
    else
        selectedFiles = input('Entrez les numéros des fichiers que vous souhaitez charger (ex: 2 3) : ', 's');
        selectedFiles = str2num(selectedFiles); %#ok<ST2NM>

        if isempty(selectedFiles) || any(selectedFiles < 1) || any(selectedFiles > length(uniqueMatFiles))
            error('Sélection de fichiers invalide.');
        end
    end

    % Charger les fichiers sélectionnés
    for k = 1:length(chosenSubfolderPaths)
        subfolderPath = chosenSubfolderPaths{k};
        for j = selectedFiles
            filePath = fullfile(subfolderPath, uniqueMatFiles(j).name);
            [~, fileName, ~] = fileparts(filePath);
            disp(['Chargement du fichier : ' filePath]);

            try
                data = load(filePath);
                [animal_date_list, results] = load_data_to_struct(data, results, fileName, k, animal_date_list);
            catch ME
                disp(['Erreur lors du chargement du fichier : ' filePath]);
                disp(['Message d''erreur : ' ME.message]);
            end
        end
    end

    disp('Les fichiers ont été chargés avec succès.');
end
