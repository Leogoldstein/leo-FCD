function [chosenSubfolderPaths] = retrieve_results(PathSave)
    % Fonction pour récupérer les sous-dossiers uniques dans les sous-dossiers
    % choisis, avec une option pour sélectionner tous les sous-dossiers ou seulement certains.

    % Vérifier que le chemin fourni est valide
    if ~isfolder(PathSave)
        error('Le chemin spécifié n''est pas valide.');
    end

    % Sélectionner tous les dossiers dans le chemin donné
    selectedFolders = dir(PathSave);
    selectedFolders = selectedFolders([selectedFolders.isdir]); % Filtrer les sous-dossiers
    selectedFolders = selectedFolders(~ismember({selectedFolders.name}, {'.', '..'})); % Exclure '.' et '..'

    % Initialiser une liste pour stocker les chemins choisis
    chosenSubfolderPaths = {};

    % Afficher les dossiers et demander à l'utilisateur de choisir
    disp('Veuillez choisir les sous-dossiers parmi les suivants :');
    for i = 1:length(selectedFolders)
        disp([num2str(i) ': ' selectedFolders(i).name]);
    end

    % Demander à l'utilisateur de choisir les sous-dossiers
    choices = input('Entrez les numéros des sous-dossiers que vous souhaitez sélectionner, séparés par des espaces : ', 's');
    choiceIndices = str2double(strsplit(choices));

    % Vérifier que les choix sont valides
    if any(isnan(choiceIndices)) || any(choiceIndices < 1) || any(choiceIndices > length(selectedFolders))
        error('Choix invalide.');
    end

    % Obtenir les sous-dossiers sélectionnés
    chosenFolders = selectedFolders(choiceIndices);

    % Initialiser une liste pour stocker tous les sous-dossiers choisis
    allChosenSubfolders = {};

    % Traiter chaque dossier choisi
    for k = 1:length(chosenFolders)
        subfolderPath = fullfile(PathSave, chosenFolders(k).name);

        % Filtrer les sous-dossiers
        subfolders = dir(subfolderPath);
        subfolders = subfolders([subfolders.isdir]); % Filtrer les sous-dossiers
        subfolders = subfolders(~ismember({subfolders.name}, {'.', '..'})); % Exclure '.' et '..'

        % Afficher les sous-dossiers non au format spécifique disponibles
        disp('Sous-dossiers disponibles :');
        for i = 1:length(subfolders)
            disp([num2str(i) ': ' subfolders(i).name]);
        end
        
        % Demander à l'utilisateur s'il souhaite sélectionner tous les sous-dossiers
        selectAll = input('Voulez-vous sélectionner tous les sous-dossiers non au format spécifique ? (y/n) : ', 's');

        if strcmpi(selectAll, 'y')
            % Ajouter tous les sous-dossiers non au format spécifique à la liste
            for idx = 1:length(subfolders)
                allChosenSubfolders{end+1} = fullfile(subfolderPath, subfolders(idx).name);
            end
        else
            % Demander à l'utilisateur de choisir parmi les sous-dossiers non spécifiques
            choicesOther = input('Entrez les numéros des sous-dossiers que vous souhaitez sélectionner, séparés par des espaces : ', 's');
            choiceIndicesOther = str2double(strsplit(choicesOther));

            % Vérifier que les choix sont valides
            if any(isnan(choiceIndicesOther)) || any(choiceIndicesOther < 1) || any(choiceIndicesOther > length(subfolders))
                error('Choix invalide.');
            end

            % Ajouter les sous-dossiers choisis à la liste
            for idx = choiceIndicesOther
                if ~isnan(idx)
                    allChosenSubfolders{end+1} = fullfile(subfolderPath, subfolders(idx).name);
                end
            end
        end
    end
    
    allChosenSubfolders2 = {};

    % Traiter chaque dossier choisi
    for k = 1:length(allChosenSubfolders)
        subfolderPath = allChosenSubfolders{k}; % Corrected indexing to access string

        % Filtrer les sous-dossiers
        subfolders = dir(subfolderPath);
        subfolders = subfolders([subfolders.isdir]); % Filtrer les sous-dossiers
        subfolders = subfolders(~ismember({subfolders.name}, {'.', '..'})); % Exclure '.' et '..'
        
        % Filtrer les sous-dossiers au format spécifique
        specificSubfolders = subfolders(~cellfun('isempty', regexp({subfolders.name}, '^\d{4}-\d{2}-\d{2}$', 'once'))); % Sous-dossiers au format spécifique
        otherSubfolders = subfolders(cellfun('isempty', regexp({subfolders.name}, '^\d{4}-\d{2}-\d{2}$', 'once'))); % Autres sous-dossiers
        
        % Afficher les sous-dossiers au format spécifique
        if ~isempty(specificSubfolders)
            disp('Sous-dossiers au format spécifique :');
            for i = 1:length(specificSubfolders)
                disp([num2str(i) ': ' specificSubfolders(i).name]);
            end

            % Demander à l'utilisateur s'il souhaite sélectionner tous les sous-dossiers
            selectAll = input('Voulez-vous sélectionner tous les sous-dossiers ? (y/n) : ', 's');

            if strcmpi(selectAll, 'y')
                % Ajouter tous les sous-dossiers au format spécifique à la liste
                for idx = 1:length(specificSubfolders)
                    allChosenSubfolders2{end+1} = fullfile(subfolderPath, specificSubfolders(idx).name);
                end
            else
                % Ajouter les sous-dossiers au format spécifique à la liste
                if ~isempty(specificSubfolders)
                    % Demander à l'utilisateur de choisir parmi les sous-dossiers disponibles
                    choicesSpecific = input('Entrez les numéros des sous-dossiers que vous souhaitez sélectionner, séparés par des espaces : ', 's');
                    choiceIndicesSpecific = str2double(strsplit(choicesSpecific));

                    % Vérifier que les choix sont valides
                    if any(isnan(choiceIndicesSpecific)) || any(choiceIndicesSpecific < 1) || any(choiceIndicesSpecific > length(specificSubfolders))
                        error('Choix invalide.');
                    end

                    % Ajouter les sous-dossiers choisis à la liste
                    for idx = choiceIndicesSpecific
                        if ~isnan(idx)
                            allChosenSubfolders2{end+1} = fullfile(subfolderPath, specificSubfolders(idx).name);
                        end
                    end
                end

                % Ajouter les autres sous-dossiers disponibles à la liste
                if ~isempty(otherSubfolders)
                    disp('Sous-dossiers non au format spécifique disponibles :');
                    for i = 1:length(otherSubfolders)
                        disp([num2str(i) ': ' otherSubfolders(i).name]);
                    end

                    % Demander à l'utilisateur de choisir parmi les autres sous-dossiers
                    choicesOther = input('Entrez les numéros des sous-dossiers que vous souhaitez sélectionner, séparés par des espaces : ', 's');
                    choiceIndicesOther = str2double(strsplit(choicesOther));

                    % Vérifier que les choix sont valides
                    if any(isnan(choiceIndicesOther)) || any(choiceIndicesOther < 1) || any(choiceIndicesOther > length(otherSubfolders))
                        error('Choix invalide.');
                    end

                    % Ajouter les sous-dossiers choisis à la liste
                    for idx = choiceIndicesOther
                        if ~isnan(idx)
                            allChosenSubfolders2{end+1} = fullfile(subfolderPath, otherSubfolders(idx).name);
                        end
                    end
                end
            end
        else
            disp('Aucun sous-dossier au format spécifique disponible.');
        end
    end

    % Extraire les sous-dossiers uniques parmi les sous-dossiers choisis
    uniqueSubfolders = {};
    for i = 1:length(allChosenSubfolders2)
        subfolderPath = allChosenSubfolders2{i};
        subfolderContents = dir(subfolderPath);
        subfolderContents = subfolderContents([subfolderContents.isdir]); % Filtrer les sous-dossiers
        subfolderContents = subfolderContents(~ismember({subfolderContents.name}, {'.', '..'})); % Exclure '.' et '..'

        for j = 1:length(subfolderContents)
            folderName = subfolderContents(j).name;
            % Ajouter à la liste des sous-dossiers uniques si pas déjà présent
            if ~ismember(folderName, uniqueSubfolders)
                uniqueSubfolders{end+1} = folderName; % Ajouter à la fin
            end
        end
    end

    % Afficher les sous-dossiers uniques
    disp('Sous-dossiers uniques parmi les choisis :');
    for i = 1:length(uniqueSubfolders)
        disp([num2str(i) ': ' uniqueSubfolders{i}]);
    end

    % Demander à l'utilisateur de choisir parmi les sous-dossiers uniques
    choicesUnique = input('Entrez les numéros des sous-dossiers que vous souhaitez sélectionner, séparés par des espaces : ', 's');
    choiceIndicesUnique = str2double(strsplit(choicesUnique));

    % Vérifier que les choix sont valides
    if any(isnan(choiceIndicesUnique)) || any(choiceIndicesUnique < 1) || any(choiceIndicesUnique > length(uniqueSubfolders))
        error('Choix invalide.');
    end

    % Ajouter les chemins des sous-dossiers uniques choisis à la liste finale
    for idx = choiceIndicesUnique
        if ~isnan(idx)
            chosenSubfolderName = uniqueSubfolders{idx};
            for i = 1:length(allChosenSubfolders2)
                subfolderPath = allChosenSubfolders2{i};
                if isfolder(fullfile(subfolderPath, chosenSubfolderName))
                    chosenSubfolderPaths{end+1} = fullfile(subfolderPath, chosenSubfolderName);
                end
            end
        end
    end

    % Afficher tous les chemins complets choisis
    disp('Chemins complets vers les sous-dossiers choisis :');
    for i = 1:length(chosenSubfolderPaths)
        disp(chosenSubfolderPaths{i});
    end
end