function animal_date_list = create_animal_date_list(dataFolders, PathSave)
    % Cette fonction extrait des informations à partir de chemins de fichiers et
    % stocke les résultats dans une liste structurée. Elle demande et affecte les âges avant la sauvegarde.
    %
    % Arguments :
    % - dataFolders : Cell array des chemins d'accès aux fichiers.
    % - PathSave : Chemin où sauvegarder les données extraites.
    %
    % Retour :
    % - animal_date_list : Cell array contenant {type, group, animal, date, age}.
    
    % Initialisation de la liste de sortie (contient uniquement les nouvelles entrées)
    animal_date_list = cell(length(dataFolders), 5); % {type, group, animal, date, age}

    % Définition des patterns pour extraire les informations
    pattern_mTOR = 'D:\\imaging\\FCD(?:\\to processed)?\\([^\\]+)\\([^\\]+)\\([^\\]+)\\TSeries-[^\\]+\\suite2p\\plane0\\Fall\.mat';
    pattern_ani = 'D:\\imaging\\([^\\]+)\\([^\\]+)\\([^\\]+)\\TSeries-[^\\]+\\suite2p\\plane0\\Fall\.mat';
    pattern_jm = 'D:\\imaging\\jm\\([^\\]+)\\([^\\]+)';

    % Parcourir les chemins des fichiers
    for k = 1:length(dataFolders)
        file_path = dataFolders{k};
        tokens = []; % Initialisation des tokens

        % Essayer de faire correspondre chaque pattern
        tokens = regexp(file_path, pattern_mTOR, 'tokens');
        if ~isempty(tokens)
            type_part = 'FCD';
            group_part = tokens{1}{1}; % Exemple : mTor13
            animal_part = tokens{1}{2}; % Exemple : ani2
            date_part = tokens{1}{3}; % Exemple : 2024-06-27
        else
            tokens = regexp(file_path, pattern_ani, 'tokens');
            if ~isempty(tokens)
                type_part = tokens{1}{1}; % Exemple : CTRL
                group_part = ''; % Vide pour pattern_ani
                animal_part = tokens{1}{2}; % Exemple : ani2
                date_part = tokens{1}{3}; % Exemple : 2024-06-27
            else
                tokens = regexp(file_path, pattern_jm, 'tokens');
                if ~isempty(tokens)
                    type_part = 'jm';
                    group_part = ''; % Vide pour pattern_jm
                    animal_part = tokens{1}{1}; % Exemple : jm040
                    date_part = tokens{1}{2}; % Exemple : 2024-06-27
                end
            end
        end

        % Si des tokens valides ont été trouvés, les ajouter à la liste
        if ~isempty(tokens)
            animal_date_list{k, 1} = type_part;
            animal_date_list{k, 2} = group_part;
            animal_date_list{k, 3} = animal_part;
            animal_date_list{k, 4} = date_part;
            animal_date_list{k, 5} = NaN; % Initialiser la colonne des âges à NaN
        end
    end

    % Identifier les groupes et animaux uniques
    unique_groups = unique(animal_date_list(:, 2));
    
    % Liste pour garder une trace des animaux dont l'âge a été assigné
    animals_with_assigned_ages = {};

    % Charger les données existantes si le fichier .mat existe
    save_folder = fullfile(PathSave, 'FCD');
    save_file = 'animal_date_list.mat';
    type_save_path = fullfile(save_folder, save_file);

    % Créer le dossier de sauvegarde si nécessaire
    if ~exist(save_folder, 'dir')
        mkdir(save_folder);
    end

    % Vérifier si le fichier existe déjà
    if exist(type_save_path, 'file')
        fprintf('File "%s" exists. Loading existing data...\n', type_save_path);
        
        % Charger les données existantes
        loaded_data = load(type_save_path);
        field_names = fieldnames(loaded_data);
        loaded_data = loaded_data.(field_names{1}); % Extraire les données
        
        % Initialiser les indices pour ajouter ou modifier les données existantes
        existing_data = loaded_data;
        
        % Assigner les âges existants aux animaux
        for i = 1:size(animal_date_list, 1)
            current_animal = animal_date_list{i, 3};
            current_date = animal_date_list{i, 4};

            % Chercher l'animal et la date dans les données existantes
            idx = find(strcmp(existing_data(:, 3), current_animal) & strcmp(existing_data(:, 4), current_date));
            if ~isempty(idx)
                % Récupérer l'âge existant
                animal_date_list{i, 5} = existing_data{idx, 5};
            end
        end
    else
        fprintf('No existing file found. Creating new file...\n');
    end

    % Parcourir chaque groupe unique
    for g = 1:length(unique_groups)
        group = unique_groups{g};
        group_indices = strcmp(animal_date_list(:, 2), group);
    
        % Trouver les animaux uniques dans ce groupe
        unique_animals_in_group = unique(animal_date_list(group_indices, 3));
    
        % Parcourir chaque animal unique dans le groupe
        for a = 1:length(unique_animals_in_group)
            animal_group = unique_animals_in_group{a};
            animal_indices = strcmp(animal_date_list(:, 3), animal_group) & group_indices;
    
            % Trouver les indices des lignes où l'âge est NaN
            nan_indices = find(cellfun(@(x) isnumeric(x) && isnan(x), animal_date_list(:, 5)));
    
            % Parcourir les dates associées à cet animal et demander l'âge
            for i = nan_indices'
                if strcmp(animal_date_list{i, 3}, animal_group) && strcmp(animal_date_list{i, 2}, group)
                    % Vérifier si un âge a déjà été assigné pour cet animal
                    if ~isnan(animal_date_list{i, 5})
                        % Si un âge est déjà assigné, passer à la prochaine itération
                        continue;
                    end

                    % Afficher les dates uniquement si l'âge n'est pas encore attribué
                    fprintf('For animal "%s" in group "%s", the dates are:\n', animal_date_list{i, 3}, animal_date_list{i, 2});
                    disp(animal_date_list(animal_indices, 4)); % Afficher les dates associées à cet animal uniquement
                    
                    % Demander l'âge si nécessaire
                    age_input = input(sprintf('Enter age(s) for animal "%s" (e.g., 8:10 or 8 9): ', animal_date_list{i, 3}), 's');
    
                    % Traiter l'entrée utilisateur
                    if contains(age_input, ':')
                        age_range = str2double(strsplit(age_input, ':'));
                        age_list = num2cell(age_range(1):age_range(2));
                    else
                        age_list = num2cell(str2double(strsplit(age_input)));
                    end
    
                    % Assigner les âges
                    for j = 1:length(age_list)
                        if isnan(age_list{j})
                            continue; % Skip if age is NaN
                        else
                            if i + j - 1 <= size(animal_date_list, 1)
                                animal_date_list{i + j - 1, 5} = sprintf('P%d', age_list{j});
                            else
                                animal_date_list{i + j - 1, 5} = NaN; % Placeholder si nécessaire
                            end
                        end
                    end
    
                    % Ajouter l'animal à la liste des animaux traités
                    animals_with_assigned_ages = [animals_with_assigned_ages, animal_group];
                end
            end
        end
    end

    % Sauvegarder les données combinées dans le fichier .mat
    save(type_save_path, 'animal_date_list');
    fprintf('Data saved to "%s".\n', type_save_path);
end
