function [selected_groups, animal_date_list] = folder_selection( ...
    choices, group_order, dataFolders_by_group, selected_groups)

    destinationFolder = 'D:/Imaging/jm/';
    root_path = 'D:\Imaging';

    if nargin < 4
        selected_groups = [];
    end

    TSeriesPaths    = {};
    true_xml_paths  = {};
    suite2p_folders = {};
    Fallmat_paths   = {};

    %======================================================
    % Collecte de tous les chemins
    %======================================================
    for i = 1:numel(choices)

        choice = choices(i);
        dataFolders = dataFolders_by_group{i};

        if isempty(dataFolders)
            fprintf('Group %d: no folders selected.\n', choice);
            continue;
        end

        switch choice

            case 1
                disp('Processing JM data...');

                [true_xml_paths_jm, TSeriesPaths_jm, ~, statPaths, FPaths, ...
                 iscellPaths, opsPaths, spksPaths] = find_npy_folders(dataFolders);

                valid_jm = ~cellfun('isempty', TSeriesPaths_jm);

                TSeriesPaths_jm   = TSeriesPaths_jm(valid_jm);
                true_xml_paths_jm = true_xml_paths_jm(valid_jm);

                [~, ~, ~, ~, ~, gcampdataFolders] = preprocess_npy_files( ...
                    FPaths, statPaths, iscellPaths, opsPaths, spksPaths, destinationFolder);

                nJM = numel(TSeriesPaths_jm);

                TSeriesPaths_4col    = cell(nJM,4);
                suite2p_folders_4col = cell(nJM,4);
                Fallmat_paths_4col   = cell(nJM,4);

                for j = 1:nJM
                    TSeriesPaths_4col{j,1} = TSeriesPaths_jm{j};

                    if j <= numel(gcampdataFolders)
                        suite2p_folders_4col{j,1} = gcampdataFolders{j};
                    end
                end

                TSeriesPaths    = concat_cell_matrices_4col(TSeriesPaths, TSeriesPaths_4col);
                true_xml_paths  = [true_xml_paths; true_xml_paths_jm(:)];
                suite2p_folders = concat_cell_matrices_4col(suite2p_folders, suite2p_folders_4col);
                Fallmat_paths   = concat_cell_matrices_4col(Fallmat_paths, Fallmat_paths_4col);

            case {2,3,4}
                group_name = group_order{choice};
                fprintf('Processing %s data...\n', group_name);

                [suite2p_tmp, TSeries_tmp, ~, xml_tmp, ~, Fall_tmp] = ...
                    find_suite2p_folders(dataFolders);

                TSeriesPaths    = concat_cell_matrices_4col(TSeriesPaths, force_4col(TSeries_tmp));
                true_xml_paths  = [true_xml_paths; xml_tmp];

                suite2p_folders = concat_cell_matrices_4col(suite2p_folders, force_4col(suite2p_tmp));
                Fallmat_paths   = concat_cell_matrices_4col(Fallmat_paths, force_4col(Fall_tmp));
        end
    end

    animal_date_list = create_animal_date_list(first_col_safe(TSeriesPaths), root_path);

    selected_groups_flat = build_selected_groups_minimal( ...
        animal_date_list, TSeriesPaths, true_xml_paths, ...
        suite2p_folders, Fallmat_paths);

    new_selected_groups = group_selected_groups_by_type(selected_groups_flat);

    [new_selected_groups, daytime] = create_gcamp_output_folders(new_selected_groups);

    selected_groups = update_selected_groups_in_place( ...
        selected_groups, ...
        new_selected_groups);
end


% =====================================================================
% Construction selected_groups minimal
% =====================================================================

function selected_groups = build_selected_groups_minimal( ...
    animal_date_list, TSeriesPaths, true_xml_paths, ...
    suite2p_folders, Fallmat_paths)

    if isempty(animal_date_list)
        selected_groups = struct([]);
        return;
    end

    if istable(animal_date_list)
        T = animal_date_list;

    elseif iscell(animal_date_list)

        if size(animal_date_list, 2) == 6
            T = cell2table(animal_date_list, ...
                'VariableNames', {'type','line','animal','date','age','sex'});

        elseif size(animal_date_list, 2) == 7
            T = cell2table(animal_date_list, ...
                'VariableNames', {'type','line','animal','date','age','sex','birth_date'});

        else
            error('animal_date_list doit avoir 6 ou 7 colonnes. Trouvé : %d colonnes.', ...
                size(animal_date_list, 2));
        end

    elseif isstruct(animal_date_list)
        T = struct2table(animal_date_list);

        if ismember('animal_type', T.Properties.VariableNames) && ...
           ~ismember('type', T.Properties.VariableNames)
            T.type = T.animal_type;
        end
    else
        error('Format non supporté pour animal_date_list.');
    end

    vars = T.Properties.VariableNames;
    for i = 1:numel(vars)
        if iscell(T.(vars{i}))
            T.(vars{i}) = string(T.(vars{i}));
        end
    end

    requiredVars = {'type','line','animal','date','sex'};
    for i = 1:numel(requiredVars)
        if ~ismember(requiredVars{i}, T.Properties.VariableNames)
            error('animal_date_list doit contenir la colonne "%s".', requiredVars{i});
        end
    end

    if ~ismember('age', T.Properties.VariableNames)
        T.age = repmat("", height(T), 1);
    end

    if ~ismember('birth_date', T.Properties.VariableNames)
        T.birth_date = repmat("", height(T), 1);
    end

    group_keys = T.type + "|" + T.line + "|" + T.animal;
    [unique_keys, ~, key_idx] = unique(group_keys, 'stable');

    nGroups = numel(unique_keys);

    empty_group = struct( ...
        'animal_group', '', ...
        'type', '', ...
        'line', '', ...
        'sex', '', ...
        'ages', {{}}, ...
        'paths', struct( ...
            'animal', '', ...
            'date', {{}}, ...
            'TSeries', {cell(0,4)}, ...
            'xml', {{}}, ...
            'suite2p', {cell(0,4)}, ...
            'fallmat', {cell(0,4)}));

    selected_groups = repmat(empty_group, nGroups, 1);

    for k = 1:nGroups

        idx = find(key_idx == k);
        firstRow = idx(1);

        type_value = char(T.type(firstRow));
        line_name  = char(T.line(firstRow));
        animal_id  = char(T.animal(firstRow));
        sex_value  = char(T.sex(firstRow));

        animal_group = animal_id;
        animal_path = infer_animal_path_from_tseries(TSeriesPaths, idx);

        dates_group = cellstr(T.date(idx));
        ages_group  = cellstr(T.age(idx));

        date_group_path = cell(numel(idx),1);

        for j = 1:numel(idx)

            this_tseries = get_cell_safe(TSeriesPaths, idx(j), 1);

            if ~isempty(this_tseries)
                [date_path, ~, ~] = fileparts(this_tseries);
                date_group_path{j} = date_path;

            elseif ~isempty(animal_path) && ~isempty(dates_group{j})
                date_group_path{j} = fullfile(animal_path, dates_group{j});

            else
                date_group_path{j} = '';
            end
        end

        selected_groups(k).animal_group = animal_group;
        selected_groups(k).type         = type_value;
        selected_groups(k).line         = line_name;
        selected_groups(k).sex          = sex_value;
        selected_groups(k).ages         = ages_group;

        selected_groups(k).paths.animal  = animal_path;
        selected_groups(k).paths.date    = date_group_path;
        selected_groups(k).paths.TSeries = subset_rows_safe_4col(TSeriesPaths, idx);
        selected_groups(k).paths.xml     = subset_vector_safe(true_xml_paths, idx);
        selected_groups(k).paths.suite2p = subset_rows_safe_4col(suite2p_folders, idx);
        selected_groups(k).paths.fallmat = subset_rows_safe_4col(Fallmat_paths, idx);
    end
end


% =====================================================================
% Mise à jour selected_groups existant
% =====================================================================

function selected_groups = update_selected_groups_in_place(selected_groups, new_selected_groups)

    if isempty(selected_groups)
        selected_groups = new_selected_groups;
        return;
    end

    updated_groups = selected_groups;

    % ================================================================
    % 1) Mettre à jour les groupes déjà existants
    % ================================================================
    old_type_names = fieldnames(updated_groups);

    for t = 1:numel(old_type_names)

        current_type = old_type_names{t};

        if isfield(new_selected_groups, current_type)
            new_groups_this_type = new_selected_groups.(current_type);
        else
            new_groups_this_type = struct([]);
        end

        old_groups_this_type = updated_groups.(current_type);

        for k = 1:numel(old_groups_this_type)

            old_group = old_groups_this_type(k);

            if isempty(new_groups_this_type)
                new_idx = [];
            else
                new_idx = find_matching_group(new_groups_this_type, old_group);
            end

            if isempty(new_idx)

                % Groupe absent de la sélection actuelle :
                % conserver l'historique mais vider les chemins dépendant
                % de la sélection et masquer data avec des [].
                [merged_group, selection_group] = ...
                    mask_group_as_not_selected(old_group);

                fprintf('Groupe non sélectionné, indices conservés avec [] : %s | %s | %s', ...
                    char(string(old_group.type)), ...
                    char(string(old_group.line)), ...
                    char(string(old_group.animal_group)));

            else

                new_group = new_groups_this_type(new_idx);

                % Conserver l'historique des recordings et aligner
                % la sélection actuelle sur les anciens indices.
                [merged_group, selection_group] = ...
                    merge_group_keep_alignment(old_group, new_group);

                fprintf('Groupe mis à jour sans suppression d''indices : %s | %s | %s', ...
                    char(string(new_group.type)), ...
                    char(string(new_group.line)), ...
                    char(string(new_group.animal_group)));
            end

            if isfield(old_group, 'data') && ...
                    ~isempty(old_group.data)

                merged_group.data = mask_data_to_current_selection( ...
                    old_group.data, selection_group);
            end

            updated_groups.(current_type)(k) = merged_group;
        end
    end

    % ================================================================
    % 2) Ajouter les nouveaux groupes absents de selected_groups
    % ================================================================
    new_type_names = fieldnames(new_selected_groups);

    for t = 1:numel(new_type_names)

        current_type = new_type_names{t};
        new_groups_this_type = new_selected_groups.(current_type);

        if ~isfield(updated_groups, current_type)

            updated_groups.(current_type) = new_groups_this_type;

            fprintf('Nouveau type ajouté : %s', current_type);
            continue;
        end

        for k = 1:numel(new_groups_this_type)

            new_group = new_groups_this_type(k);

            old_idx = find_matching_group( ...
                updated_groups.(current_type), new_group);

            if ~isempty(old_idx)
                continue;
            end

            [updated_groups.(current_type), new_group] = ...
                harmonize_struct_fields_for_append( ...
                    updated_groups.(current_type), new_group);

            updated_groups.(current_type)(end+1) = new_group;

            fprintf('Nouveau groupe ajouté : %s | %s | %s', ...
                char(string(new_group.type)), ...
                char(string(new_group.line)), ...
                char(string(new_group.animal_group)));
        end
    end

    selected_groups = updated_groups;
end


function [merged_group, selection_group] = ...
    merge_group_keep_alignment(old_group, new_group)

    merged_group = old_group;

    % ------------------------------------------------------
    % Mettre à jour les informations générales
    % ------------------------------------------------------
    scalar_fields = {'animal_group','type','line','sex'};

    for i = 1:numel(scalar_fields)

        fn = scalar_fields{i};

        if isfield(new_group, fn) && ~isempty(new_group.(fn))
            merged_group.(fn) = new_group.(fn);
        end
    end

    if ~isfield(merged_group, 'paths') || ...
            ~isstruct(merged_group.paths)
        merged_group.paths = struct();
    end

    if ~isfield(new_group, 'paths') || ...
            ~isstruct(new_group.paths)
        new_group.paths = struct();
    end

    nOld = get_recording_count(old_group);
    nNew = get_recording_count(new_group);

    % ------------------------------------------------------
    % Trouver l'indice historique correspondant à chaque
    % recording de la sélection actuelle
    % ------------------------------------------------------
    new_to_merged = zeros(nNew,1);
    used_old = false(nOld,1);
    nTotal = nOld;

    for j = 1:nNew

        old_idx = find_matching_recording( ...
            old_group, new_group, j, used_old);

        if isempty(old_idx)
            nTotal = nTotal + 1;
            new_to_merged(j) = nTotal;
        else
            new_to_merged(j) = old_idx;
            used_old(old_idx) = true;
        end
    end

    % ------------------------------------------------------
    % Champs historiques : jamais supprimés
    % ------------------------------------------------------
    old_tseries = get_path_matrix(old_group, 'TSeries', nOld, 4);
    old_xml     = get_path_vector(old_group, 'xml', nOld);
    old_date    = get_path_vector(old_group, 'date', nOld);
    old_ages    = get_group_vector(old_group, 'ages', nOld);

    merged_tseries = resize_cell_matrix(old_tseries, nTotal, 4);
    merged_xml     = resize_cell_vector(old_xml, nTotal);
    merged_date    = resize_cell_vector(old_date, nTotal);
    merged_ages    = resize_cell_vector(old_ages, nTotal);

    new_tseries = get_path_matrix(new_group, 'TSeries', nNew, 4);
    new_xml     = get_path_vector(new_group, 'xml', nNew);
    new_date    = get_path_vector(new_group, 'date', nNew);
    new_ages    = get_group_vector(new_group, 'ages', nNew);

    for j = 1:nNew

        target_idx = new_to_merged(j);

        for c = 1:4
            if ~isempty(new_tseries{j,c})
                merged_tseries{target_idx,c} = new_tseries{j,c};
            end
        end

        if ~isempty(new_xml{j})
            merged_xml{target_idx,1} = new_xml{j};
        end

        if ~isempty(new_date{j})
            merged_date{target_idx,1} = new_date{j};
        end

        if ~isempty(new_ages{j})
            merged_ages{target_idx,1} = new_ages{j};
        end
    end

    merged_group.paths.TSeries = merged_tseries;
    merged_group.paths.xml     = merged_xml;
    merged_group.paths.date    = merged_date;
    merged_group.ages          = merged_ages;

    % ------------------------------------------------------
    % animal : conserver l'ancien si le nouveau est vide
    % ------------------------------------------------------
    if isfield(new_group.paths, 'animal') && ...
            ~isempty(new_group.paths.animal)

        merged_group.paths.animal = new_group.paths.animal;

    elseif ~isfield(merged_group.paths, 'animal')

        merged_group.paths.animal = '';
    end

    % ------------------------------------------------------
    % Tous les autres champs paths :
    % aucune suppression de ligne.
    % Les recordings non sélectionnés deviennent [].
    % ------------------------------------------------------
    reserved_fields = {'animal','date','TSeries','xml'};

    old_path_fields = fieldnames(merged_group.paths);
    new_path_fields = fieldnames(new_group.paths);

    all_path_fields = unique( ...
        [old_path_fields; new_path_fields], 'stable');

    for f = 1:numel(all_path_fields)

        fn = all_path_fields{f};

        if any(strcmp(fn, reserved_fields))
            continue;
        end

        old_value = [];
        new_value = [];

        if isfield(old_group, 'paths') && ...
                isfield(old_group.paths, fn)
            old_value = old_group.paths.(fn);
        end

        if isfield(new_group.paths, fn)
            new_value = new_group.paths.(fn);
        end

        if iscell(old_value) || iscell(new_value)

            nCols = max([ ...
                get_cell_ncols(old_value), ...
                get_cell_ncols(new_value), ...
                1]);

            aligned_value = cell(nTotal, nCols);
            new_value = resize_cell_matrix( ...
                force_cell_matrix(new_value), nNew, nCols);

            for j = 1:nNew

                target_idx = new_to_merged(j);

                for c = 1:nCols
                    aligned_value{target_idx,c} = new_value{j,c};
                end
            end

            merged_group.paths.(fn) = aligned_value;

        else

            % Champ non indexé par recording
            if ~isempty(new_value)
                merged_group.paths.(fn) = new_value;
            elseif ~isfield(merged_group.paths, fn)
                merged_group.paths.(fn) = old_value;
            end
        end
    end

    % ------------------------------------------------------
    % selection_group sert uniquement à masquer data.
    % TSeries non sélectionnées = [] ici, sans modifier
    % merged_group.paths.TSeries.
    % ------------------------------------------------------
    selection_group = merged_group;
    selection_group.paths.TSeries = cell(nTotal,4);

    for j = 1:nNew

        target_idx = new_to_merged(j);
        selection_group.paths.TSeries(target_idx,:) = ...
            new_tseries(j,:);
    end
end


function [masked_group, selection_group] = ...
    mask_group_as_not_selected(old_group)

    masked_group = old_group;

    if ~isfield(masked_group, 'paths') || ...
            ~isstruct(masked_group.paths)

        masked_group.paths = struct();
    end

    nRecordings = get_recording_count(old_group);

    reserved_fields = {'animal','date','TSeries','xml'};
    path_fields = fieldnames(masked_group.paths);

    for f = 1:numel(path_fields)

        fn = path_fields{f};

        if any(strcmp(fn, reserved_fields))
            continue;
        end

        value = masked_group.paths.(fn);

        if iscell(value)
            nCols = max(get_cell_ncols(value), 1);
            masked_group.paths.(fn) = cell(nRecordings, nCols);
        end
    end

    selection_group = masked_group;
    selection_group.paths.TSeries = cell(nRecordings,4);
end


function idx = find_matching_group(old_groups, new_group)

    idx = [];

    new_type   = string(new_group.type);
    new_line   = string(new_group.line);
    new_animal = string(new_group.animal_group);
    new_path   = "";

    if isfield(new_group, 'paths') && ...
            isfield(new_group.paths, 'animal')
        new_path = string(new_group.paths.animal);
    end

    for j = 1:numel(old_groups)

        old_type   = string(old_groups(j).type);
        old_line   = string(old_groups(j).line);
        old_animal = string(old_groups(j).animal_group);
        old_path   = "";

        if isfield(old_groups(j), 'paths') && ...
                isfield(old_groups(j).paths, 'animal')
            old_path = string(old_groups(j).paths.animal);
        end

        same_identity = ...
            old_type == new_type && ...
            old_line == new_line && ...
            old_animal == new_animal;

        same_path = ...
            old_path == new_path || ...
            old_path == "" || ...
            new_path == "";

        if same_identity && same_path
            idx = j;
            return;
        end
    end
end


function idx = find_matching_recording( ...
    old_group, new_group, new_idx, used_old)

    idx = [];

    nOld = get_recording_count(old_group);

    if nOld == 0
        return;
    end

    old_tseries = get_path_matrix(old_group, 'TSeries', nOld, 4);
    new_tseries = get_path_matrix(new_group, 'TSeries', ...
        get_recording_count(new_group), 4);

    new_tseries_path = normalize_one_path( ...
        get_cell_safe(new_tseries, new_idx, 1));

    if new_tseries_path ~= ""

        for i = 1:nOld

            if used_old(i)
                continue;
            end

            old_path = normalize_one_path( ...
                get_cell_safe(old_tseries, i, 1));

            if old_path ~= "" && old_path == new_tseries_path
                idx = i;
                return;
            end
        end
    end

    old_xml = get_path_vector(old_group, 'xml', nOld);
    new_xml = get_path_vector(new_group, 'xml', ...
        get_recording_count(new_group));

    new_xml_path = normalize_one_path( ...
        get_cell_safe(new_xml, new_idx, 1));

    if new_xml_path ~= ""

        for i = 1:nOld

            if used_old(i)
                continue;
            end

            old_path = normalize_one_path( ...
                get_cell_safe(old_xml, i, 1));

            if old_path ~= "" && old_path == new_xml_path
                idx = i;
                return;
            end
        end
    end

    old_date = get_path_vector(old_group, 'date', nOld);
    new_date = get_path_vector(new_group, 'date', ...
        get_recording_count(new_group));

    new_date_path = normalize_one_path( ...
        get_cell_safe(new_date, new_idx, 1));

    if new_date_path ~= ""

        candidates = [];

        for i = 1:nOld

            if used_old(i)
                continue;
            end

            old_path = normalize_one_path( ...
                get_cell_safe(old_date, i, 1));

            if old_path ~= "" && old_path == new_date_path
                candidates(end+1) = i; %#ok<AGROW>
            end
        end

        if numel(candidates) == 1
            idx = candidates(1);
        end
    end
end


function n = get_recording_count(group)

    counts = 0;

    if isfield(group, 'ages') && iscell(group.ages)
        counts(end+1) = numel(group.ages);
    end

    if isfield(group, 'paths') && isstruct(group.paths)

        fields = {'date','TSeries','xml','suite2p','fallmat', ...
            'gcamp_output','gcamp_root'};

        for i = 1:numel(fields)

            fn = fields{i};

            if isfield(group.paths, fn) && ...
                    iscell(group.paths.(fn))

                counts(end+1) = size(group.paths.(fn),1);
            end
        end
    end

    n = max(counts);
end


function C = get_path_matrix(group, field, nRows, nCols)

    C = cell(nRows, nCols);

    if ~isfield(group, 'paths') || ...
            ~isstruct(group.paths) || ...
            ~isfield(group.paths, field)

        return;
    end

    C = resize_cell_matrix( ...
        force_cell_matrix(group.paths.(field)), ...
        nRows, nCols);
end


function C = get_path_vector(group, field, nRows)

    C = cell(nRows,1);

    if ~isfield(group, 'paths') || ...
            ~isstruct(group.paths) || ...
            ~isfield(group.paths, field)

        return;
    end

    value = group.paths.(field);

    if isempty(value)
        return;
    end

    if isstring(value)
        value = cellstr(value(:));
    elseif ischar(value)
        value = {value};
    elseif ~iscell(value)
        value = num2cell(value);
    end

    value = value(:);
    C = resize_cell_vector(value, nRows);
end


function C = get_group_vector(group, field, nRows)

    C = cell(nRows,1);

    if ~isfield(group, field)
        return;
    end

    value = group.(field);

    if isempty(value)
        return;
    end

    if isstring(value)
        value = cellstr(value(:));
    elseif ischar(value)
        value = {value};
    elseif ~iscell(value)
        value = num2cell(value);
    end

    C = resize_cell_vector(value(:), nRows);
end


function C = force_cell_matrix(C)

    if isempty(C)
        C = cell(0,1);
        return;
    end

    if isstring(C)
        C = cellstr(C);
    elseif ischar(C)
        C = {C};
    elseif ~iscell(C)
        C = num2cell(C);
    end
end


function C = resize_cell_matrix(C, nRows, nCols)

    C = force_cell_matrix(C);

    out = cell(nRows, nCols);

    nCopyRows = min(size(C,1), nRows);
    nCopyCols = min(size(C,2), nCols);

    if nCopyRows > 0 && nCopyCols > 0
        out(1:nCopyRows,1:nCopyCols) = ...
            C(1:nCopyRows,1:nCopyCols);
    end

    C = out;
end


function C = resize_cell_vector(C, nRows)

    if isempty(C)
        C = cell(nRows,1);
        return;
    end

    if isstring(C)
        C = cellstr(C(:));
    elseif ischar(C)
        C = {C};
    elseif ~iscell(C)
        C = num2cell(C);
    end

    C = C(:);

    out = cell(nRows,1);
    nCopy = min(numel(C), nRows);

    if nCopy > 0
        out(1:nCopy) = C(1:nCopy);
    end

    C = out;
end


function nCols = get_cell_ncols(C)

    if isempty(C)
        nCols = 0;
        return;
    end

    if iscell(C)
        nCols = size(C,2);
    else
        nCols = 0;
    end
end


function [A, b] = harmonize_struct_fields_for_append(A, b)

    fieldsA = fieldnames(A);
    fieldsB = fieldnames(b);

    all_fields = unique([fieldsA; fieldsB], 'stable');

    for i = 1:numel(all_fields)

        fn = all_fields{i};

        if ~isfield(A, fn)
            for j = 1:numel(A)
                A(j).(fn) = [];
            end
        end

        if ~isfield(b, fn)
            b.(fn) = [];
        end
    end

    A = orderfields(A, all_fields);
    b = orderfields(b, all_fields);
end


% =====================================================================
% Masquage centralisé de data
% Aucun indice n'est supprimé
% =====================================================================

function data = mask_data_to_current_selection(data, selection_group)

    if isempty(data) || ~isstruct(data)
        return;
    end

    if ~isfield(selection_group, 'paths') || ...
            ~isstruct(selection_group.paths)
        return;
    end

    % ------------------------------------------------------
    % Motion + stim : TSeries de la sélection courante
    % Les indices absents deviennent []
    % ------------------------------------------------------
    if isfield(selection_group.paths, 'TSeries')

        current_tseries = selection_group.paths.TSeries(:,1);

        if isfield(data, 'motion')
            data = mask_linear_branch_by_path( ...
                data, 'motion', ...
                'motion_tseries_path', current_tseries);
        end

        if isfield(data, 'stim')
            data = mask_linear_branch_by_path( ...
                data, 'stim', ...
                'stim_tseries_path', current_tseries);
        end
    end

    % ------------------------------------------------------
    % GCaMP + blue : suite2p aligné par recording
    % ------------------------------------------------------
    if isfield(selection_group.paths, 'suite2p')

        suite2p_paths = force_4col( ...
            selection_group.paths.suite2p);

        current_gcamp_folders = rows_to_nested_cell( ...
            suite2p_paths(:,1));

        if isfield(data, 'gcamp_plane')
            data = mask_plane_branch_by_path( ...
                data, 'gcamp_plane', ...
                'gcamp_fall_path_by_plane', ...
                current_gcamp_folders);
        end

        current_blue_folders = rows_to_nested_cell( ...
            suite2p_paths(:,3));

        if isfield(data, 'blue_plane')
            data = mask_plane_branch_by_path( ...
                data, 'blue_plane', ...
                'blue_fall_path_by_plane', ...
                current_blue_folders);
        end
    end

    % ------------------------------------------------------
    % Combined : gcamp_output aligné par recording
    % ------------------------------------------------------
    if isfield(selection_group.paths, 'gcamp_output')

        current_output_folders = rows_to_nested_cell( ...
            selection_group.paths.gcamp_output);

        if isfield(data, 'combined_plane')
            data = mask_plane_branch_by_path( ...
                data, 'combined_plane', ...
                'combined_output_path_by_plane', ...
                current_output_folders);
        end
    end
end


function data = mask_linear_branch_by_path( ...
    data, branchName, pathField, current_paths)

    if ~isfield(data, branchName) || ...
            ~isstruct(data.(branchName))
        return;
    end

    branch = data.(branchName);

    if ~isfield(branch, pathField) || ...
            ~iscell(branch.(pathField))

        warning('%s : champ de traçabilité "%s" absent. Branche conservée sans masquage.', ...
            branchName, pathField);

        return;
    end

    current_paths = normalize_path_list(current_paths);
    old_paths = normalize_path_list(branch.(pathField));

    nOld = numel(old_paths);
    nTarget = max(nOld, numel(current_paths));

    fields = fieldnames(branch);

    % Étendre les champs linéaires sans supprimer les indices existants
    for f = 1:numel(fields)

        fn = fields{f};

        if iscell(branch.(fn)) && ...
                numel(branch.(fn)) == nOld

            original_size = size(branch.(fn));
            branch.(fn) = branch.(fn)(:);

            if numel(branch.(fn)) < nTarget
                branch.(fn){nTarget,1} = [];
            end

            if original_size(1) == 1
                branch.(fn) = branch.(fn).';
            end
        end
    end

    old_paths = normalize_path_list(branch.(pathField));
    keep_idx = false(nTarget,1);

    for i = 1:min(numel(old_paths), nTarget)

        if old_paths{i} == ""
            continue;
        end

        keep_idx(i) = any(strcmp( ...
            string(old_paths{i}), ...
            string(current_paths)));
    end

    for f = 1:numel(fields)

        fn = fields{f};

        if iscell(branch.(fn)) && ...
                numel(branch.(fn)) == nTarget

            for i = 1:nTarget
                if ~keep_idx(i)
                    branch.(fn){i} = [];
                end
            end
        end
    end

    data.(branchName) = branch;
end


function data = mask_plane_branch_by_path( ...
    data, branchName, pathField, current_paths_by_group)

    if ~isfield(data, branchName) || ...
            ~isstruct(data.(branchName))
        return;
    end

    branch = data.(branchName);

    if ~isfield(branch, pathField) || ...
            ~iscell(branch.(pathField))

        warning('%s : champ de traçabilité "%s" absent. Branche conservée sans masquage.', ...
            branchName, pathField);

        return;
    end

    fields = fieldnames(branch);

    current_paths_by_group = ...
        force_column_cell(current_paths_by_group);

    nOldGroups = numel(branch.(pathField));
    nTargetGroups = max( ...
        nOldGroups, numel(current_paths_by_group));

    % ------------------------------------------------------
    % Étendre les champs par recording avec des []
    % Jamais de troncature
    % ------------------------------------------------------
    for f = 1:numel(fields)

        fn = fields{f};

        if iscell(branch.(fn)) && ...
                numel(branch.(fn)) == nOldGroups

            branch.(fn) = branch.(fn)(:);

            if numel(branch.(fn)) < nTargetGroups
                branch.(fn){nTargetGroups,1} = [];
            end
        end
    end

    for m = 1:nTargetGroups

        if m <= numel(current_paths_by_group)
            current_paths = current_paths_by_group{m};
        else
            current_paths = {};
        end

        if isempty(current_paths)

            % Recording absent de la sélection :
            % vider chaque champ à cet index, sans supprimer l'index.
            for f = 1:numel(fields)

                fn = fields{f};

                if iscell(branch.(fn)) && ...
                        numel(branch.(fn)) >= m

                    branch.(fn){m} = [];
                end
            end

            continue;
        end

        if ischar(current_paths) || isstring(current_paths)
            current_paths = {char(current_paths)};
        end

        current_paths = normalize_path_list(current_paths);

        if numel(branch.(pathField)) < m || ...
                isempty(branch.(pathField){m}) || ...
                ~iscell(branch.(pathField){m})

            continue;
        end

        old_paths = normalize_path_list( ...
            branch.(pathField){m});

        keep_p = false(numel(old_paths),1);

        for p = 1:numel(old_paths)

            if old_paths{p} == ""
                continue;
            end

            keep_p(p) = any(strcmp( ...
                string(old_paths{p}), ...
                string(current_paths)));
        end

        for f = 1:numel(fields)

            fn = fields{f};

            if numel(branch.(fn)) >= m && ...
                    iscell(branch.(fn){m}) && ...
                    numel(branch.(fn){m}) == numel(keep_p)

                for p = 1:numel(keep_p)

                    if ~keep_p(p)
                        branch.(fn){m}{p} = [];
                    end
                end
            end
        end
    end

    data.(branchName) = branch;
end

% =====================================================================
% Helpers chemins / cellules
% =====================================================================

function out = normalize_path_list(paths_in)

    if isempty(paths_in)
        out = {};
        return;
    end

    if istable(paths_in)
        paths_in = table2cell(paths_in);
    end

    if isstring(paths_in)
        paths_in = cellstr(paths_in(:));
    end

    if ischar(paths_in)
        paths_in = {paths_in};
    end

    if ~iscell(paths_in)
        out = {};
        return;
    end

    paths_in = paths_in(:);
    tmp = {};

    for i = 1:numel(paths_in)

        p = paths_in{i};

        if isempty(p)
            tmp{end+1,1} = "";
            continue;
        end

        if iscell(p)
            p = p(:);
            for j = 1:numel(p)
                tmp{end+1,1} = normalize_one_path(p{j});
            end

        elseif isstring(p)
            p = p(:);
            for j = 1:numel(p)
                tmp{end+1,1} = normalize_one_path(p(j));
            end

        else
            tmp{end+1,1} = normalize_one_path(p);
        end
    end

    out = tmp;
end


function p = normalize_one_path(p)

    if isempty(p)
        p = "";
        return;
    end

    p = string(p);
    p = p(1);
    p = replace(p, '/', '\');
    p = strip(p);

    while strlength(p) > 0 && endsWith(p, "\")
        p = extractBefore(p, strlength(p));
    end
end

function C = force_column_cell(C)

    if isempty(C)
        C = {};
        return;
    end

    if isstring(C)
        C = cellstr(C);
    end

    if ischar(C)
        C = {C};
    end

    if ~iscell(C)
        C = {};
        return;
    end

    C = C(:);
end


function nested = rows_to_nested_cell(C)

    if isempty(C)
        nested = {};
        return;
    end

    if ~iscell(C)
        C = cellstr(string(C));
    end

    nested = cell(size(C,1),1);

    for i = 1:size(C,1)
        nested{i} = C(i,:);
    end
end


function animal_path = infer_animal_path_from_tseries(TSeriesPaths, idx)

    animal_path = '';

    if isempty(TSeriesPaths) || isempty(idx)
        return;
    end

    firstPath = get_cell_safe(TSeriesPaths, idx(1), 1);

    if isempty(firstPath)
        return;
    end

    [date_path, ~, ~] = fileparts(firstPath);
    [animal_path, ~, ~] = fileparts(date_path);
end


function out = subset_vector_safe(C, idx)

    if isempty(C)
        out = {};
        return;
    end

    if size(C,2) > 1
        C = C(:,1);
    end

    out = C(idx);
end


function out = subset_rows_safe_4col(C, idx)

    if isempty(C)
        out = cell(numel(idx),4);
        return;
    end

    C = force_4col(C);
    out = C(idx, :);
end


function out = first_col_safe(C)

    if isempty(C)
        out = {};
        return;
    end

    C = force_4col(C);
    out = C(:,1);
end


function C4 = force_4col(C)

    if isempty(C)
        C4 = cell(0,4);
        return;
    end

    nRows = size(C,1);
    nCols = size(C,2);

    C4 = cell(nRows,4);
    C4(:,1:min(4,nCols)) = C(:,1:min(4,nCols));
end


function out = concat_cell_matrices_4col(a, b)

    a = force_4col(a);
    b = force_4col(b);

    if isempty(a)
        out = b;
    elseif isempty(b)
        out = a;
    else
        out = [a; b];
    end
end


function val = get_cell_safe(C, r, c)

    val = '';

    if isempty(C)
        return;
    end

    if size(C,1) >= r && size(C,2) >= c
        tmp = C{r,c};

        if ~isempty(tmp)
            val = tmp;
        end
    end
end


function selected_groups_by_type = group_selected_groups_by_type(selected_groups_flat)

    selected_groups_by_type = struct();

    if isempty(selected_groups_flat)
        return;
    end

    animal_types = unique(string({selected_groups_flat.type}), 'stable');

    for i = 1:numel(animal_types)

        current_type = char(animal_types(i));

        if isempty(current_type)
            continue;
        end

        idx = strcmpi({selected_groups_flat.type}, current_type);

        selected_groups_by_type.(matlab.lang.makeValidName(current_type)) = ...
            selected_groups_flat(idx);
    end
end