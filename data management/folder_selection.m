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

    [new_selected_groups, ~] = create_gcamp_output_folders(new_selected_groups);

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

function selected_groups = update_selected_groups_in_place( ...
        old_selected_groups, new_selected_groups)

    if isempty(new_selected_groups) || ...
            ~isstruct(new_selected_groups) || ...
            isempty(fieldnames(new_selected_groups))

        selected_groups = struct();
        fprintf('\nAucune donnée sélectionnée : selected_groups vidé.\n');
        return;
    end

    if nargin < 1 || ...
            isempty(old_selected_groups) || ...
            ~isstruct(old_selected_groups)

        selected_groups = new_selected_groups;
        fprintf('\nNouvelle sélection créée sans historique précédent.\n');
        return;
    end

    selected_groups = struct();
    selected_type_names = fieldnames(new_selected_groups);

    for t = 1:numel(selected_type_names)

        current_type = selected_type_names{t};
        current_new_groups = new_selected_groups.(current_type);
        current_output_groups = struct([]);

        if isfield(old_selected_groups, current_type)
            current_old_groups = old_selected_groups.(current_type);
        else
            current_old_groups = struct([]);
        end

        for k = 1:numel(current_new_groups)

            selection_group = current_new_groups(k);

            old_idx = find_matching_group( ...
                current_old_groups, selection_group);

            if isempty(old_idx)

                final_group = selection_group;

                fprintf([ ...
                    'Nouveau groupe conservé : ' ...
                    '%s | %s | %s | %d recording(s)\n'], ...
                    char(string(final_group.type)), ...
                    char(string(final_group.line)), ...
                    char(string(final_group.animal_group)), ...
                    get_recording_count(final_group));

            else

                old_group = current_old_groups(old_idx);

                final_group = keep_group_current_selection( ...
                    old_group, selection_group);

                fprintf([ ...
                    'Groupe filtré sur la sélection : ' ...
                    '%s | %s | %s | %d recording(s)\n'], ...
                    char(string(final_group.type)), ...
                    char(string(final_group.line)), ...
                    char(string(final_group.animal_group)), ...
                    get_recording_count(final_group));
            end

            if isempty(current_output_groups)

                current_output_groups = final_group;

            else

                [current_output_groups, final_group] = ...
                    harmonize_struct_fields_for_append( ...
                        current_output_groups, final_group);

                current_output_groups(end+1,1) = final_group;
            end
        end

        selected_groups.(current_type) = current_output_groups;
    end
end


function final_group = keep_group_current_selection( ...
        old_group, new_group)

    nOld = get_recording_count(old_group);
    nNew = get_recording_count(new_group);

    old_indices = zeros(nNew,1);
    used_old = false(nOld,1);

    for j = 1:nNew

        idx = find_matching_recording( ...
            old_group, new_group, j, used_old);

        if ~isempty(idx)
            old_indices(j) = idx;
            used_old(idx) = true;
        end
    end

    % La structure finale suit exactement la sélection courante.
    final_group = new_group;

    % Conserver les champs top-level supplémentaires de l'ancien groupe.
    old_fields = fieldnames(old_group);

    protected_fields = { ...
        'animal_group', 'type', 'line', 'sex', ...
        'ages', 'paths', 'data'};

    for f = 1:numel(old_fields)

        fn = old_fields{f};

        if any(strcmp(fn, protected_fields))
            continue;
        end

        old_value = old_group.(fn);

        if is_recording_indexed_cell(old_value, nOld)

            final_group.(fn) = subset_recording_cell( ...
                old_value, old_indices, nNew);

        elseif ~isfield(final_group, fn) || ...
                isempty(final_group.(fn))

            final_group.(fn) = old_value;
        end
    end

    final_group.paths = merge_paths_for_current_selection( ...
        old_group, new_group, old_indices, nOld, nNew);

    % Âges : priorité à la sélection actuelle.
    new_ages = get_group_vector(new_group, 'ages', nNew);
    old_ages = get_group_vector(old_group, 'ages', nOld);

    final_ages = cell(nNew,1);

    for j = 1:nNew

        if j <= numel(new_ages) && ~isempty(new_ages{j})

            final_ages{j} = new_ages{j};

        elseif old_indices(j) > 0 && ...
                old_indices(j) <= numel(old_ages)

            final_ages{j} = old_ages{old_indices(j)};
        end
    end

    final_group.ages = final_ages;

    % Conserver uniquement les données des recordings sélectionnés.
    if isfield(old_group, 'data') && ...
            ~isempty(old_group.data)

        final_group.data = subset_data_for_current_selection( ...
            old_group.data, old_indices, nOld, nNew);
    end
end


function final_paths = merge_paths_for_current_selection( ...
        old_group, new_group, old_indices, nOld, nNew)

    if isfield(new_group, 'paths') && ...
            isstruct(new_group.paths)

        final_paths = new_group.paths;
    else
        final_paths = struct();
    end

    if ~isfield(old_group, 'paths') || ...
            ~isstruct(old_group.paths)

        return;
    end

    old_path_fields = fieldnames(old_group.paths);

    if isfield(new_group, 'paths') && ...
            isstruct(new_group.paths)

        new_path_fields = fieldnames(new_group.paths);
    else
        new_path_fields = {};
    end

    all_path_fields = unique( ...
        [old_path_fields; new_path_fields], 'stable');

    for f = 1:numel(all_path_fields)

        fn = all_path_fields{f};

        old_exists = isfield(old_group.paths, fn);
        new_exists = isfield(new_group, 'paths') && ...
            isstruct(new_group.paths) && ...
            isfield(new_group.paths, fn);

        if old_exists
            old_value = old_group.paths.(fn);
        else
            old_value = [];
        end

        if new_exists
            new_value = new_group.paths.(fn);
        else
            new_value = [];
        end

        if strcmp(fn, 'animal')

            if ~isempty(new_value)
                final_paths.(fn) = new_value;
            elseif ~isempty(old_value)
                final_paths.(fn) = old_value;
            else
                final_paths.(fn) = '';
            end

            continue;
        end

        old_is_indexed = is_recording_indexed_cell(old_value, nOld);
        new_is_indexed = is_recording_indexed_cell(new_value, nNew);

        if old_is_indexed || new_is_indexed

            nCols = max([ ...
                get_cell_column_count(old_value), ...
                get_cell_column_count(new_value), ...
                1]);

            old_matrix = resize_cell_matrix( ...
                force_cell_matrix(old_value), nOld, nCols);

            new_matrix = resize_cell_matrix( ...
                force_cell_matrix(new_value), nNew, nCols);

            merged_value = cell(nNew, nCols);

            for j = 1:nNew

                source_idx = old_indices(j);

                if source_idx > 0 && source_idx <= nOld
                    merged_value(j,:) = old_matrix(source_idx,:);
                end

                for c = 1:nCols
                    if ~isempty(new_matrix{j,c})
                        merged_value{j,c} = new_matrix{j,c};
                    end
                end
            end

            final_paths.(fn) = merged_value;

        elseif new_exists && ~isempty(new_value)

            final_paths.(fn) = new_value;

        elseif old_exists

            final_paths.(fn) = old_value;
        end
    end
end


function new_data = subset_data_for_current_selection( ...
        old_data, old_indices, nOld, nNew)

    new_data = struct();

    if isempty(old_data) || ~isstruct(old_data)
        return;
    end

    data_fields = fieldnames(old_data);

    for f = 1:numel(data_fields)

        fn = data_fields{f};
        old_value = old_data.(fn);

        if isstruct(old_value)

            new_data.(fn) = subset_struct_branch( ...
                old_value, old_indices, nOld, nNew);

        elseif is_recording_indexed_cell(old_value, nOld)

            new_data.(fn) = subset_recording_cell( ...
                old_value, old_indices, nNew);

        else

            new_data.(fn) = old_value;
        end
    end
end


function new_branch = subset_struct_branch( ...
        old_branch, old_indices, nOld, nNew)

    if isscalar(old_branch)

        new_branch = struct();
        branch_fields = fieldnames(old_branch);

        for f = 1:numel(branch_fields)

            fn = branch_fields{f};
            old_value = old_branch.(fn);

            if isstruct(old_value)

                new_branch.(fn) = subset_struct_branch( ...
                    old_value, old_indices, nOld, nNew);

            elseif is_recording_indexed_cell(old_value, nOld)

                new_branch.(fn) = subset_recording_cell( ...
                    old_value, old_indices, nNew);

            else

                new_branch.(fn) = old_value;
            end
        end

        return;
    end

    if numel(old_branch) == nOld

        if isempty(old_branch)
            new_branch = old_branch;
            return;
        end

        template = old_branch(1);
        empty_template = empty_struct_like(template);
        new_branch = repmat(empty_template, nNew, 1);

        for j = 1:nNew

            source_idx = old_indices(j);

            if source_idx > 0 && source_idx <= nOld
                new_branch(j,1) = old_branch(source_idx);
            end
        end

    else

        new_branch = old_branch;
    end
end


function out = subset_recording_cell(C, old_indices, nNew)

    if isempty(C)
        out = cell(nNew,1);
        return;
    end

    if ~iscell(C)
        out = C;
        return;
    end

    is_row_vector = size(C,1) == 1 && size(C,2) > 1;

    if is_row_vector

        C_work = C(:);
        out_work = cell(nNew,1);

        for j = 1:nNew

            source_idx = old_indices(j);

            if source_idx > 0 && source_idx <= numel(C_work)
                out_work{j} = C_work{source_idx};
            end
        end

        out = out_work.';
        return;
    end

    nCols = size(C,2);
    out = cell(nNew,nCols);

    for j = 1:nNew

        source_idx = old_indices(j);

        if source_idx > 0 && source_idx <= size(C,1)
            out(j,:) = C(source_idx,:);
        end
    end
end


function tf = is_recording_indexed_cell(value, nRecordings)

    tf = false;

    if ~iscell(value) || nRecordings <= 0
        return;
    end

    tf = size(value,1) == nRecordings || ...
        (size(value,1) == 1 && size(value,2) == nRecordings);
end


function nCols = get_cell_column_count(value)

    if isempty(value) || ~iscell(value)
        nCols = 0;
        return;
    end

    % Important :
    % une matrice 1x4 de chemins correspond à un seul recording
    % avec quatre canaux/colonnes, et non à quatre recordings.
    nCols = size(value, 2);
end


function S = empty_struct_like(template)

    S = template;
    fields = fieldnames(S);

    for f = 1:numel(fields)
        S.(fields{f}) = [];
    end
end


function [A, b] = harmonize_struct_fields_for_append(A, b)

    if isempty(A)
        return;
    end

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


% =====================================================================
% Helpers chemins / cellules
% =====================================================================

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