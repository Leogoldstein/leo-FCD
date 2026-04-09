function updated_animal_date_list = create_animal_date_list(TSeriesPaths, PathSave)
% create_animal_date_list
% Extrait les informations depuis les chemins TSeries et sauvegarde
% une liste structurée :
%   {type, group, animal, date, age, sex}
%
% INPUTS:
%   TSeriesPaths : cell array N x M contenant les chemins TSeries
%   PathSave     : dossier racine de sauvegarde
%
% OUTPUT:
%   updated_animal_date_list : cell array final fusionné par type

    %===================%
    %   Vérifications
    %===================%
    if nargin < 1 || isempty(TSeriesPaths)
        updated_animal_date_list = {};
        return;
    end

    if ~iscell(TSeriesPaths)
        error('TSeriesPaths doit être un cell array.');
    end

    if nargin < 2 || isempty(PathSave)
        error('PathSave doit être fourni.');
    end

    %===================%
    %   Initialisation
    %===================%
    nRows = size(TSeriesPaths, 1);
    animal_date_list = cell(nRows, 6); % {type, group, animal, date, age, sex}

    % Patterns adaptés aux chemins TSeries
    pattern_mTOR = ['D:\\Imaging\\([^\\]+)\\([^\\]+)\\([^\\]+)\\([^\\]+)' ...
                    '\\TSeries-[^\\]+'];

    pattern_ani = ['D:\\Imaging\\([^\\]+)\\([^\\]+)\\([^\\]+)' ...
                   '\\TSeries-[^\\]+'];

    pattern_jm = ['D:\\Imaging\\jm\\([^\\]+)\\([^\\]+)' ...
                  '\\TSeries-[^\\]+'];

    %===================%
    %   Extraction des infos
    %===================%
    for k = 1:nRows

        file_path = '';

        % Prendre colonne 1 si possible, sinon premier chemin non vide
        if size(TSeriesPaths, 2) >= 1 && ~isempty(TSeriesPaths{k, 1})
            file_path = TSeriesPaths{k, 1};
        else
            row_paths = TSeriesPaths(k, :);
            non_empty_idx = find(~cellfun(@isempty, row_paths), 1, 'first');
            if ~isempty(non_empty_idx)
                file_path = row_paths{non_empty_idx};
            end
        end

        if isempty(file_path)
            continue;
        end

        if isstring(file_path)
            file_path = char(file_path);
        end

        tokens = [];

        % --- Cas mTOR ---
        tokens = regexp(file_path, pattern_mTOR, 'tokens');
        if ~isempty(tokens)
            type_part   = tokens{1}{1};
            group_part  = tokens{1}{2};
            animal_part = tokens{1}{3};
            date_part   = tokens{1}{4};

        else
            % --- Cas sans groupe ---
            tokens = regexp(file_path, pattern_ani, 'tokens');
            if ~isempty(tokens)
                type_part   = tokens{1}{1};
                group_part  = '';
                animal_part = tokens{1}{2};
                date_part   = tokens{1}{3};

            else
                % --- Cas JM ---
                tokens = regexp(file_path, pattern_jm, 'tokens');
                if ~isempty(tokens)
                    type_part   = 'jm';
                    group_part  = '';
                    animal_part = tokens{1}{1};
                    date_part   = tokens{1}{2};
                end
            end
        end

        if ~isempty(tokens)
            animal_date_list{k, 1} = type_part;
            animal_date_list{k, 2} = group_part;
            animal_date_list{k, 3} = animal_part;
            animal_date_list{k, 4} = date_part;
            animal_date_list{k, 5} = NaN;
            animal_date_list{k, 6} = NaN;
        end
    end

    %===================%
    %   Nettoyage lignes vides
    %===================%
    non_empty_type = ~cellfun('isempty', animal_date_list(:, 1));
    animal_date_list = animal_date_list(non_empty_type, :);

    if isempty(animal_date_list)
        updated_animal_date_list = {};
        return;
    end

    unique_types = unique(animal_date_list(:, 1));
    updated_animal_date_list = {};

    %===================%
    %   Gestion par type
    %===================%
    for h = 1:length(unique_types)

        current_type = unique_types{h};
        type_indices = strcmp(animal_date_list(:, 1), current_type);
        animal_date_list_type = animal_date_list(type_indices, :);

        save_folder = fullfile(PathSave, current_type);
        save_file = 'animal_date_list.mat';
        type_save_path = fullfile(save_folder, save_file);

        if ~exist(save_folder, 'dir')
            mkdir(save_folder);
        end

        % Toujours initialiser proprement
        existing_data = cell(0,6);

        %===================%
        %   Charger existant
        %===================%
        if exist(type_save_path, 'file')
            fprintf('File "%s" exists. Loading existing data...\n', type_save_path);

            loaded_data = load(type_save_path);
            field_names = fieldnames(loaded_data);

            if ~isempty(field_names)
                existing_data = loaded_data.(field_names{1});
            end

            if isempty(existing_data)
                existing_data = cell(0,6);
            end

            if size(existing_data, 2) < 6
                existing_data(:, end+1:6) = {''};
            end

            for i = 1:size(animal_date_list_type, 1)
                current_group  = animal_date_list_type{i, 2};
                current_animal = animal_date_list_type{i, 3};
                current_date   = animal_date_list_type{i, 4};

                idx = [];

                if ~isempty(existing_data) && size(existing_data,2) >= 6
                    group_col  = existing_data(:, 2);
                    animal_col = existing_data(:, 3);
                    date_col   = existing_data(:, 4);

                    group_col(cellfun(@isempty, group_col))   = {''};
                    animal_col(cellfun(@isempty, animal_col)) = {''};
                    date_col(cellfun(@isempty, date_col))     = {''};

                    idx = find(strcmp(group_col, current_group) & ...
                               strcmp(animal_col, current_animal) & ...
                               strcmp(date_col, current_date), 1);
                end

                if ~isempty(idx)
                    animal_date_list_type{i, 5} = existing_data{idx, 5};
                    animal_date_list_type{i, 6} = existing_data{idx, 6};
                end
            end
        else
            fprintf('No existing file found. Creating new file...\n');
        end

        %===================%
        %   Construction des groupes
        %===================%
        group_names = cell(size(animal_date_list_type, 1), 1);

        for i = 1:size(animal_date_list_type, 1)
            if isempty(animal_date_list_type{i, 2})
                group_names{i, 1} = animal_date_list_type{i, 3};
            else
                group_names{i, 1} = animal_date_list_type{i, 2};
            end
        end

        unique_groups = unique(group_names);

        %===================%
        %   Demande âge / sexe
        %===================%
        for g = 1:length(unique_groups)
            group = unique_groups{g};

            group_indices = strcmp(animal_date_list_type(:, 2), group);

            if any(cellfun(@isempty, animal_date_list_type(:, 2)))
                empty_group_indices = strcmp(animal_date_list_type(:, 3), group);
                group_indices = group_indices | empty_group_indices;
            end

            unique_animals_in_group = unique(animal_date_list_type(group_indices, 3));

            for a = 1:length(unique_animals_in_group)
                animal_group = unique_animals_in_group{a};
                animal_indices = strcmp(animal_date_list_type(:, 3), animal_group);

                nan_age_indices = find(animal_indices & ...
                    cellfun(@(x) (isnumeric(x) && isnan(x)) || ...
                                 (ischar(x) && strcmpi(x, 'nan')), ...
                                 animal_date_list_type(:, 5)));

                nan_sex_indices = find(animal_indices & ...
                    cellfun(@(x) isempty(x) || ...
                                 (isnumeric(x) && isnan(x)) || ...
                                 (ischar(x) && strcmpi(x, 'nan')), ...
                                 animal_date_list_type(:, 6)));

                for i = nan_age_indices'
                    if strcmp(animal_date_list_type{i, 3}, animal_group)

                        if ~isempty(animal_date_list_type{i, 5}) && ...
                           ~((isnumeric(animal_date_list_type{i, 5}) && isnan(animal_date_list_type{i, 5})) || ...
                             (ischar(animal_date_list_type{i, 5}) && strcmpi(animal_date_list_type{i, 5}, 'nan')))
                            continue;
                        end

                        fprintf('For animal "%s" in group "%s", the dates are:\n', ...
                            animal_date_list_type{i, 3}, animal_date_list_type{i, 2});
                        disp(animal_date_list_type(i, 4));

                        age_input = input(sprintf( ...
                            'Enter age(s) for animal "%s" (e.g., 8:10 or 8 9): ', ...
                            animal_date_list_type{i, 3}), 's');

                        if contains(age_input, ':')
                            age_range = str2double(strsplit(age_input, ':'));
                            age_list = num2cell(age_range(1):age_range(2));
                        else
                            age_list = num2cell(str2double(strsplit(strtrim(age_input))));
                        end

                        for j = 1:length(age_list)
                            if isnan(age_list{j})
                                continue;
                            end
                            if i + j - 1 <= size(animal_date_list_type, 1)
                                animal_date_list_type{i + j - 1, 5} = sprintf('P%d', age_list{j});
                            end
                        end
                    end
                end

                if ~isempty(nan_sex_indices)
                    sexe_input = input(sprintf('Enter sex for animal "%s" (M/F/IND): ', animal_group), 's');
                    sexe_input = upper(strtrim(sexe_input));

                    if ismember(sexe_input, {'M', 'F', 'IND'})
                        [animal_date_list_type{nan_sex_indices, 6}] = deal(sexe_input);
                    else
                        warning('Invalid sex entered. Please use "M", "F", or "IND".');
                    end
                end
            end
        end

        %===================%
        %   Fusion avec existant
        %===================%
        for i = 1:size(animal_date_list_type, 1)

            current_animal = animal_date_list_type{i, 3};
            current_group  = animal_date_list_type{i, 2};
            current_date   = animal_date_list_type{i, 4};

            duplicate_idx = [];

            if ~isempty(existing_data) && size(existing_data,2) >= 6
                group_col  = existing_data(:, 2);
                animal_col = existing_data(:, 3);
                date_col   = existing_data(:, 4);

                group_col(cellfun(@isempty, group_col))   = {''};
                animal_col(cellfun(@isempty, animal_col)) = {''};
                date_col(cellfun(@isempty, date_col))     = {''};

                duplicate_idx = find(strcmp(animal_col, current_animal) & ...
                                     strcmp(group_col, current_group) & ...
                                     strcmp(date_col, current_date), 1);
            end

            if ~isempty(duplicate_idx)
                if isempty(existing_data{duplicate_idx, 6}) || ...
                   (ischar(existing_data{duplicate_idx, 6}) && strcmpi(existing_data{duplicate_idx, 6}, 'nan')) || ...
                   (isnumeric(existing_data{duplicate_idx, 6}) && isnan(existing_data{duplicate_idx, 6}))
                    existing_data{duplicate_idx, 6} = animal_date_list_type{i, 6};
                end

                if isempty(existing_data{duplicate_idx, 5}) || ...
                   (ischar(existing_data{duplicate_idx, 5}) && strcmpi(existing_data{duplicate_idx, 5}, 'nan')) || ...
                   (isnumeric(existing_data{duplicate_idx, 5}) && isnan(existing_data{duplicate_idx, 5}))
                    existing_data{duplicate_idx, 5} = animal_date_list_type{i, 5};
                end
            else
                % Condition d'ajout robuste
                if ~isempty(animal_date_list_type{i,1}) && ...
                   ~isempty(animal_date_list_type{i,3}) && ...
                   ~isempty(animal_date_list_type{i,4})

                    existing_data = [existing_data; animal_date_list_type(i, :)]; %#ok<AGROW>
                else
                    warning('Une ligne vide ou invalide a été détectée et ignorée.');
                end
            end
        end

        disp(animal_date_list_type);
        save(type_save_path, 'existing_data');
        fprintf('Data saved to "%s".\n', type_save_path);

        updated_animal_date_list = [updated_animal_date_list; animal_date_list_type]; %#ok<AGROW>
    end
end