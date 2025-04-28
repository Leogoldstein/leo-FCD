function updated_animal_date_list = create_animal_date_list(dataFolders, PathSave)
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
    animal_date_list = cell(length(dataFolders), 6); % {type, group, animal, date, age, sex}

    % Définition des patterns pour extraire les informations
    pattern_mTOR = 'D:\\Imaging\\FCD(?:\\to processed)?\\([^\\]+)\\([^\\]+)\\([^\\]+)\\TSeries-[^\\]+\\suite2p\\plane0\\Fall\.mat';
    pattern_ani = 'D:\\Imaging\\([^\\]+)\\([^\\]+)\\([^\\]+)\\TSeries-[^\\]+\\suite2p\\plane0\\Fall\.mat';
    pattern_jm = 'D:\\Imaging\\jm\\([^\\]+)\\([^\\]+)';

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
            animal_date_list{k, 6} = NaN; % Initialiser la colonne des sexes à NaN
        end
    end

    %disp(animal_date_list)

    % Identifier les types uniques
    unique_types = unique(animal_date_list(:, 1));
    updated_animal_date_list = {}; % Initialisation

    % Itérer sur chaque type pour gérer les âges indépendamment
    for h = 1:length(unique_types)
        current_type = unique_types{h};
        type_indices = strcmp(animal_date_list(:, 1), current_type);
        animal_date_list_type = animal_date_list(type_indices, :);

        disp(animal_date_list_type);
        %disp(size(animal_date_list_type, 1))

        save_folder = fullfile(PathSave, current_type);
        save_file = 'animal_date_list.mat';
        type_save_path = fullfile(save_folder, save_file);
        
        % Créer le dossier de sauvegarde si nécessaire
        if ~exist(save_folder, 'dir')
            mkdir(save_folder);
        end
        
        % Initialiser une variable pour stocker les anciennes données
        existing_data = {};
        
        % Vérifier si le fichier existe déjà
        if exist(type_save_path, 'file')
            fprintf('File "%s" exists. Loading existing data...\n', type_save_path);
            
            % Charger les données existantes
            loaded_data = load(type_save_path);
            field_names = fieldnames(loaded_data);
            existing_data = loaded_data.(field_names{1}); % Extraire les données existantes

            if size(existing_data, 2) < 6
                % Ajouter une 6ème colonne vide (sexe) si manquante
                existing_data(:, end+1:6) = {''};
            end
            
            % Assigner les âges existants aux animaux
            for i = 1:size(animal_date_list_type, 1)
                current_type = animal_date_list_type{i, 2};
                current_animal = animal_date_list_type{i, 3};
                current_date = animal_date_list_type{i, 4};
        
                % Chercher l'animal et la date dans les données existantes
                if ~isempty(strcmp(existing_data(:, 2), current_type))
                    idx = find(strcmp(existing_data(:, 2), current_type) & strcmp(existing_data(:, 3), current_animal) & strcmp(existing_data(:, 4), current_date));
                else
                     idx = find(strcmp(existing_data(:, 3), current_animal) & strcmp(existing_data(:, 4), current_date));
                end
                
                if ~isempty(idx)
                    % Récupérer l'âge et le sexe existant
                    animal_date_list_type{i, 5} = existing_data{idx, 5};
                    animal_date_list_type{i, 6} = existing_data{idx, 6};
                end
            end
        else
            fprintf('No existing file found. Creating new file...\n');
        end
        
        % Pré-définir group_names comme une cellule vide de la bonne taille
        group_names = cell(size(animal_date_list_type, 1), 1);
        
        % Parcourir chaque ligne
        for i = 1:size(animal_date_list_type, 1)
            % Si la 2ᵉ colonne est vide
            if isempty(animal_date_list_type{i, 2})
                group_names{i, 1} = animal_date_list_type{i, 3};  % Prendre la 3ᵉ colonne
            else
                group_names{i, 1} = animal_date_list_type{i, 2};  % Sinon, prendre la 2ᵉ colonne
            end
        end
        
        % Obtenir les groupes uniques
        unique_groups = unique(group_names);
        
        % Parcourir chaque groupe unique
        for g = 1:length(unique_groups)
            group = unique_groups{g};
            
            % Trouver les indices des lignes correspondant au groupe
            group_indices = strcmp(animal_date_list_type(:, 2), group);  % Cas où la 2ᵉ colonne est remplie
            
            % Ajouter les indices où la 2ᵉ colonne est vide et la 3ᵉ colonne correspond au groupe
            if any(cellfun('isempty', animal_date_list_type(:, 2)))  % Si des lignes ont la 2ᵉ colonne vide
                empty_group_indices = strcmp(animal_date_list_type(:, 3), group);  % Chercher dans la 3ᵉ colonne
                group_indices = group_indices | empty_group_indices;  % Fusionner les indices
            end
                
            % Trouver les animaux uniques dans ce groupe
            unique_animals_in_group = unique(animal_date_list_type(group_indices, 3));
        
            % Parcourir chaque animal unique dans le groupe
            for a = 1:length(unique_animals_in_group)
                animal_group = unique_animals_in_group{a};
                animal_indices = strcmp(animal_date_list_type(:, 3), animal_group);

                % Trouver les indices où l'âge est NaN (colonne 5)
                nan_age_indices = find(animal_indices & ...
                    cellfun(@(x) (isnumeric(x) && isnan(x)) || (ischar(x) && strcmpi(x, 'nan')), animal_date_list_type(:, 5)));
                
                % Trouver les indices où le sexe est NaN ou vide (colonne 6)
                nan_sex_indices = find(animal_indices & ...
                     cellfun(@(x) isempty(x) || (isnumeric(x) && isnan(x)) || (ischar(x) && strcmpi(x, 'nan')), animal_date_list_type(:, 6)));
                
                disp(nan_sex_indices)


                % Parcourir les dates associées à cet animal et demander l'âge
                for i = nan_age_indices'
                    if strcmp(animal_date_list_type{i, 3}, animal_group) && strcmp(animal_date_list_type{i, 2}, group)
                        % Vérifier si un âge a déjà été assigné pour cet animal
                        if ~isnan(animal_date_list_type{i, 5})
                            % Si un âge est déjà assigné, passer à la prochaine itération
                            continue;
                        end
                
                        % Afficher les dates uniquement si l'âge n'est pas encore attribué
                        fprintf('For animal "%s" in group "%s", the dates are:\n', animal_date_list_type{i, 3}, animal_date_list_type{i, 2});
                        disp(animal_date_list_type(animal_indices, 4)); % Afficher les dates associées à cet animal uniquement
                
                        % Demander l'âge si nécessaire
                        age_input = input(sprintf('Enter age(s) for animal "%s" (e.g., 8:10 or 8 9): ', animal_date_list_type{i, 3}), 's');
                
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
                                if i + j - 1 <= size(animal_date_list_type, 1)
                                    animal_date_list_type{i + j - 1, 5} = sprintf('P%d', age_list{j});
                                else
                                    animal_date_list_type{i + j - 1, 5} = NaN; % Placeholder si nécessaire
                                end
                            end
                        end
                    end
                end
                
                if ~isempty(nan_sex_indices)
                    % Demander une seule fois le sexe pour tout l'animal
                    sexe_input = input(sprintf('Enter sex for animal "%s" (M/F/IND): ', animal_group), 's');
                    sexe_input = upper(strtrim(sexe_input));  % Normaliser

                    % Traitement pour le sexe
                    if ismember(sexe_input, {'M', 'F', 'IND'})
                        [animal_date_list_type{nan_sex_indices, 6}] = deal(sexe_input);
                    else
                        warning('Invalid sex entered. Please use "M", "F", or "IND".');
                    end
                end
            end
        end
        
        % Vérifier les doublons avant d'ajouter les nouvelles lignes
        for i = 1:size(animal_date_list_type, 1)
            current_animal = animal_date_list_type{i, 3};
            current_group = animal_date_list_type{i, 2};
            current_date = animal_date_list_type{i, 4};
            
            % Vérifier si la ligne existe déjà dans existing_data
            if size(existing_data, 2) >= 6
                % Ensure non-empty character values
                group_col   = existing_data(:, 2);
                animal_col  = existing_data(:, 3);
                date_col    = existing_data(:, 4);
            
                % Nettoyer les colonnes pour éviter les erreurs de comparaison
                group_col(cellfun(@isempty, group_col)) = {''};
                animal_col(cellfun(@isempty, animal_col)) = {''};
                date_col(cellfun(@isempty, date_col)) = {''};
    
                duplicate_idx = find(strcmp(animal_col, current_animal) & ...
                                     strcmp(group_col, current_group) & ...
                                     strcmp(date_col, current_date), 1);
            else
                warning('existing_data does not have enough columns.');
                duplicate_idx = [];
            end
        
            % Si la ligne n'existe pas déjà, l'ajouter à existing_data
            if ~isempty(duplicate_idx)
                % Mettre à jour le sexe si la cellule correspondante dans existing_data est vide
                if isempty(existing_data{duplicate_idx, 6}) || (ischar(existing_data{duplicate_idx, 6}) && strcmpi(existing_data{duplicate_idx, 6}, 'nan'))
                    existing_data{duplicate_idx, 6} = animal_date_list_type{i, 6};
                end
            
                % Mettre à jour l'âge si manquant
                if isempty(existing_data{duplicate_idx, 5}) || (ischar(existing_data{duplicate_idx, 5}) && strcmpi(existing_data{duplicate_idx, 5}, 'nan'))
                    existing_data{duplicate_idx, 5} = animal_date_list_type{i, 5};
                end
            end

            if isempty(duplicate_idx)
                % Vérifier si animal_date_list(i, :) contient des données valides avant l'ajout
                if all(~cellfun(@isempty, animal_date_list_type(i, :)))
                    existing_data = [existing_data; animal_date_list_type(i, :)];
                else
                    warning('Une ligne vide ou invalide a été détectée et ignorée.');
                end
            end
        end
        
        % Sauvegarder les données combinées dans le fichier .mat
        disp(animal_date_list_type);  % Affichez la liste avant de sauvegarder pour vérifier les changements

        save(type_save_path, 'existing_data');
        fprintf('Data saved to "%s".\n', type_save_path);
        
        updated_animal_date_list = [updated_animal_date_list; animal_date_list_type];
    
    end
end

                    
              