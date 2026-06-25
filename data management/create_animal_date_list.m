function updated_animal_date_list = create_animal_date_list(TSeriesPaths, PathSave)
% create_animal_date_list
% Structure sauvegardée :
%   {type, group, animal, date, age, sex, birth_date}
%
% birth_date :
%   - demandée une seule fois par group_part si group_part existe
%   - sinon demandée par animal
%
% age :
%   - inféré automatiquement pour chaque date

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

    nRows = size(TSeriesPaths, 1);

    % Colonnes :
    % 1 type
    % 2 group
    % 3 animal
    % 4 date acquisition
    % 5 age
    % 6 sex
    % 7 birth_date
    animal_date_list = cell(nRows, 7);

    pattern_mTOR = ['D:\\Imaging\\([^\\]+)\\([^\\]+)\\([^\\]+)\\([^\\]+)' ...
                    '\\TSeries-[^\\]+'];

    pattern_ani = ['D:\\Imaging\\([^\\]+)\\([^\\]+)\\([^\\]+)' ...
                   '\\TSeries-[^\\]+'];

    pattern_jm = ['D:\\Imaging\\jm\\([^\\]+)\\([^\\]+)' ...
                  '\\TSeries-[^\\]+'];

    %======================================================
    % Extraction des infos depuis les chemins
    %======================================================
    for k = 1:nRows

        file_path = '';

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

        tokens = regexp(file_path, pattern_mTOR, 'tokens');

        if ~isempty(tokens)

            type_part   = tokens{1}{1};
            group_part  = tokens{1}{2};
            animal_part = tokens{1}{3};
            date_part   = tokens{1}{4};

        else

            tokens = regexp(file_path, pattern_ani, 'tokens');

            if ~isempty(tokens)

                type_part   = tokens{1}{1};
                group_part  = '';
                animal_part = tokens{1}{2};
                date_part   = tokens{1}{3};

            else

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
            animal_date_list{k, 7} = '';
        end
    end

    %======================================================
    % Nettoyage lignes vides
    %======================================================
    non_empty_type = ~cellfun('isempty', animal_date_list(:, 1));
    animal_date_list = animal_date_list(non_empty_type, :);

    if isempty(animal_date_list)
        updated_animal_date_list = {};
        return;
    end

    unique_types = unique(animal_date_list(:, 1));
    updated_animal_date_list = {};

    %======================================================
    % Gestion par type
    %======================================================
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

        existing_data = cell(0, 7);

        %======================================================
        % Charger fichier existant
        %======================================================
        if exist(type_save_path, 'file')

            fprintf('File "%s" exists. Loading existing data...\n', type_save_path);

            loaded_data = load(type_save_path);
            field_names = fieldnames(loaded_data);

            if ~isempty(field_names)
                existing_data = loaded_data.(field_names{1});
            end

            if isempty(existing_data)
                existing_data = cell(0, 7);
            end

            % Compatibilité anciens fichiers à 6 colonnes
            if size(existing_data, 2) < 7
                existing_data(:, end+1:7) = {''};
            end

            % Reprendre infos existantes
            for i = 1:size(animal_date_list_type, 1)

                current_group  = animal_date_list_type{i, 2};
                current_animal = animal_date_list_type{i, 3};
                current_date   = animal_date_list_type{i, 4};

                idx = find_existing_row(existing_data, ...
                    current_group, current_animal, current_date);

                if ~isempty(idx)
                    animal_date_list_type{i, 5} = existing_data{idx, 5};
                    animal_date_list_type{i, 6} = existing_data{idx, 6};
                    animal_date_list_type{i, 7} = existing_data{idx, 7};
                end
            end

        else
            fprintf('No existing file found. Creating new file...\n');
        end

        %======================================================
        % Birth keys : group_part si présent, sinon animal
        %======================================================
        birth_keys = cell(size(animal_date_list_type, 1), 1);

        for i = 1:size(animal_date_list_type, 1)
            if ~isempty(animal_date_list_type{i, 2})
                birth_keys{i} = animal_date_list_type{i, 2};
            else
                birth_keys{i} = animal_date_list_type{i, 3};
            end
        end

        unique_birth_keys = unique(birth_keys);

        %======================================================
        % Date de naissance par groupe
        %======================================================
        for b = 1:length(unique_birth_keys)

            current_birth_key = unique_birth_keys{b};

            key_indices = strcmp(birth_keys, current_birth_key);
            key_rows = find(key_indices);

            type_name = animal_date_list_type{key_rows(1), 1};
            group_name = animal_date_list_type{key_rows(1), 2};

            if isempty(group_name)
                group_name = 'No group';
            end

            animals_in_key = unique(animal_date_list_type(key_rows, 3));
            dates_in_key   = unique(animal_date_list_type(key_rows, 4));

            birth_date_str = '';

            % Chercher birth_date déjà présente dans animal_date_list_type
            existing_birth_rows = key_rows(~cellfun(@is_empty_or_nan, ...
                animal_date_list_type(key_rows, 7)));

            if ~isempty(existing_birth_rows)
                birth_date_str = animal_date_list_type{existing_birth_rows(1), 7};
            end

            % Chercher birth_date dans existing_data
            if isempty(birth_date_str) && ~isempty(existing_data)

                for r = 1:size(existing_data, 1)

                    if size(existing_data, 2) < 7
                        continue;
                    end

                    existing_group  = existing_data{r, 2};
                    existing_animal = existing_data{r, 3};

                    if ~isempty(existing_group)
                        existing_key = existing_group;
                    else
                        existing_key = existing_animal;
                    end

                    if strcmp_safe(existing_key, current_birth_key) && ...
                       ~is_empty_or_nan(existing_data{r, 7})

                        birth_date_str = existing_data{r, 7};
                        break;
                    end
                end
            end

            % Demander birth_date si absente
            if isempty(birth_date_str)

                fprintf('\n====================================\n');
                fprintf('Type   : %s\n', type_name);
                fprintf('Group  : %s\n', group_name);
                fprintf('Animals: ');
                fprintf('%s ', animals_in_key{:});
                fprintf('\nDates  :\n');
                disp(dates_in_key);
                fprintf('====================================\n');

                valid_birth = false;

                while ~valid_birth

                    birth_input = input(sprintf( ...
                        'Enter birth date for group "%s" (dd/mm/yyyy or dd_mm_yy): ', ...
                        current_birth_key), 's');

                    birth_input = strtrim(birth_input);

                    try
                        birth_dt = parse_date_flexible(birth_input);
                        birth_date_str = datestr(birth_dt, 'dd/mm/yyyy');
                        valid_birth = true;

                    catch
                        warning('Date de naissance invalide. Exemple valide : 01/11/2025');
                    end
                end

            else
                birth_dt = parse_date_flexible(birth_date_str);
                birth_date_str = datestr(birth_dt, 'dd/mm/yyyy');
            end

            % Appliquer birth_date à toutes les lignes du groupe
            [animal_date_list_type{key_rows, 7}] = deal(birth_date_str);

            % Calculer âge pour chaque date
            for rr = key_rows'

                acq_date_str = animal_date_list_type{rr, 4};

                try
                    acq_dt = parse_date_flexible(acq_date_str);
                    age_days = round(days(acq_dt - birth_dt));

                    if age_days < 0
                        warning('Âge négatif détecté pour group "%s", date "%s".', ...
                            current_birth_key, acq_date_str);

                        animal_date_list_type{rr, 5} = NaN;
                    else
                        animal_date_list_type{rr, 5} = sprintf('P%d', age_days);
                    end

                catch ME
                    warning('Impossible de calculer l''âge pour group "%s", date "%s" : %s', ...
                        current_birth_key, acq_date_str, ME.message);
                end
            end
        end

        %======================================================
        % Sexe : demandé par animal
        %======================================================
        unique_animals = unique(animal_date_list_type(:, 3));

        for a = 1:length(unique_animals)

            animal_name = unique_animals{a};
            animal_indices = strcmp(animal_date_list_type(:, 3), animal_name);

            nan_sex_indices = find(animal_indices & ...
                cellfun(@is_empty_or_nan, animal_date_list_type(:, 6)));

            if ~isempty(nan_sex_indices)

                group_for_display = animal_date_list_type{nan_sex_indices(1), 2};

                if isempty(group_for_display)
                    group_for_display = 'No group';
                end

                fprintf('\nAnimal "%s" | Group "%s"\n', ...
                    animal_name, group_for_display);

                sexe_input = input(sprintf( ...
                    'Enter sex for animal "%s" (M/F/IND): ', animal_name), 's');

                sexe_input = upper(strtrim(sexe_input));

                if ismember(sexe_input, {'M', 'F', 'IND'})
                    [animal_date_list_type{nan_sex_indices, 6}] = deal(sexe_input);
                else
                    warning('Invalid sex entered. Please use "M", "F", or "IND".');
                end
            end
        end

        %======================================================
        % Fusion avec existing_data
        %======================================================
        for i = 1:size(animal_date_list_type, 1)

            current_group  = animal_date_list_type{i, 2};
            current_animal = animal_date_list_type{i, 3};
            current_date   = animal_date_list_type{i, 4};

            duplicate_idx = find_existing_row(existing_data, ...
                current_group, current_animal, current_date);

            if ~isempty(duplicate_idx)

                % Age recalculé automatiquement
                existing_data{duplicate_idx, 5} = animal_date_list_type{i, 5};

                % Sexe seulement si absent dans existing_data
                if is_empty_or_nan(existing_data{duplicate_idx, 6})
                    existing_data{duplicate_idx, 6} = animal_date_list_type{i, 6};
                end

                % birth_date mise à jour
                existing_data{duplicate_idx, 7} = animal_date_list_type{i, 7};

            else

                if ~isempty(animal_date_list_type{i, 1}) && ...
                   ~isempty(animal_date_list_type{i, 3}) && ...
                   ~isempty(animal_date_list_type{i, 4})

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

%==========================================================
% HELPERS
%==========================================================

function idx = find_existing_row(existing_data, current_group, current_animal, current_date)

    idx = [];

    if isempty(existing_data) || size(existing_data, 2) < 4
        return;
    end

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

function tf = is_empty_or_nan(x)

    tf = isempty(x) || ...
         (isnumeric(x) && isnan(x)) || ...
         (ischar(x) && strcmpi(strtrim(x), 'nan')) || ...
         (isstring(x) && (strlength(x) == 0 || strcmpi(strtrim(x), "nan")));
end

function tf = strcmp_safe(a, b)

    if isempty(a)
        a = '';
    end

    if isempty(b)
        b = '';
    end

    if isstring(a)
        a = char(a);
    end

    if isstring(b)
        b = char(b);
    end

    tf = strcmp(a, b);
end

function dt = parse_date_flexible(date_str)

    if isstring(date_str)
        date_str = char(date_str);
    end

    date_str = strtrim(date_str);

    formats = { ...
        'dd/MM/yyyy', ...
        'dd_MM_yyyy', ...
        'dd-MM-yyyy', ...
        'dd/MM/yy', ...
        'dd_MM_yy', ...
        'dd-MM-yy', ...
        'yyyy-MM-dd', ...
        'yyyy_MM_dd' ...
    };

    last_err = [];

    for f = 1:numel(formats)

        try
            dt = datetime(date_str, 'InputFormat', formats{f});
            return;

        catch ME
            last_err = ME;
        end
    end

    error('Date format not recognized: %s. Last error: %s', ...
        date_str, last_err.message);
end