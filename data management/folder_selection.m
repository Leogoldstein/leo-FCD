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

    if isempty(new_selected_groups)
        selected_groups = struct();
        return;
    end

    updated_groups = new_selected_groups;

    type_names = fieldnames(new_selected_groups);

    for t = 1:numel(type_names)

        current_type = type_names{t};

        if ~isfield(selected_groups, current_type)
            continue;
        end

        old_groups = selected_groups.(current_type);

        for k = 1:numel(new_selected_groups.(current_type))

            new_group = new_selected_groups.(current_type)(k);

            old_idx = find_matching_group(old_groups, new_group);

            if isempty(old_idx)
                fprintf('Nouveau groupe : %s | %s | %s\n', ...
                    char(string(new_group.type)), ...
                    char(string(new_group.line)), ...
                    char(string(new_group.animal_group)));
                continue;
            end

            old_group = old_groups(old_idx);

            if isfield(old_group, 'data') && ~isempty(old_group.data)

                clean_data = prune_data_to_current_selection(old_group.data, new_group);

                updated_groups.(current_type)(k).data = clean_data;

                fprintf('Groupe mis à jour, data conservée et nettoyée : %s | %s | %s\n', ...
                    char(string(new_group.type)), ...
                    char(string(new_group.line)), ...
                    char(string(new_group.animal_group)));
            end
        end
    end

    selected_groups = updated_groups;
end


function idx = find_matching_group(old_groups, new_group)

    idx = [];

    new_type   = string(new_group.type);
    new_line   = string(new_group.line);
    new_animal = string(new_group.animal_group);
    new_path   = "";

    if isfield(new_group, 'paths') && isfield(new_group.paths, 'animal')
        new_path = string(new_group.paths.animal);
    end

    for j = 1:numel(old_groups)

        old_type   = string(old_groups(j).type);
        old_line   = string(old_groups(j).line);
        old_animal = string(old_groups(j).animal_group);
        old_path   = "";

        if isfield(old_groups(j), 'paths') && isfield(old_groups(j).paths, 'animal')
            old_path = string(old_groups(j).paths.animal);
        end

        if old_type == new_type && ...
           old_line == new_line && ...
           old_animal == new_animal && ...
           old_path == new_path

            idx = j;
            return;
        end
    end
end


% =====================================================================
% Nettoyage centralisé de data
% =====================================================================

function data = prune_data_to_current_selection(data, new_group)

    if isempty(data) || ~isstruct(data)
        return;
    end

    if ~isfield(new_group, 'paths') || ~isstruct(new_group.paths)
        return;
    end

    % ------------------------------------------------------
    % Motion + stim : indexés par TSeries GCaMP colonne 1
    % ------------------------------------------------------
    if isfield(new_group.paths, 'TSeries') && ~isempty(new_group.paths.TSeries)

        current_tseries = new_group.paths.TSeries(:,1);

        if isfield(data, 'motion')
            data = prune_linear_branch_by_path( ...
                data, 'motion', 'motion_tseries_path', current_tseries);
        end

        if isfield(data, 'stim')
            data = prune_linear_branch_by_path( ...
                data, 'stim', 'stim_tseries_path', current_tseries);
        end
    end

    % ------------------------------------------------------
    % GCaMP : indexé par suite2p colonne 1
    % ------------------------------------------------------
    if isfield(new_group.paths, 'suite2p') && ~isempty(new_group.paths.suite2p)

        current_gcamp_folders = rows_to_nested_cell(new_group.paths.suite2p(:,1));

        if isfield(data, 'gcamp_plane')
            data = prune_plane_branch_by_path( ...
                data, 'gcamp_plane', 'gcamp_fall_path_by_plane', current_gcamp_folders);
        end

        current_blue_folders = rows_to_nested_cell(new_group.paths.suite2p(:,3));

        if isfield(data, 'blue_plane')
            data = prune_plane_branch_by_path( ...
                data, 'blue_plane', 'blue_fall_path_by_plane', current_blue_folders);
        end
    end

    % ------------------------------------------------------
    % Combined : indexé par gcamp_output
    % ------------------------------------------------------
    if isfield(new_group.paths, 'gcamp_output') && ~isempty(new_group.paths.gcamp_output)

        current_output_folders = rows_to_nested_cell(new_group.paths.gcamp_output);

        if isfield(data, 'combined_plane')
            data = prune_plane_branch_by_path( ...
                data, 'combined_plane', 'combined_output_path_by_plane', current_output_folders);
        end
    end
end


function data = prune_linear_branch_by_path(data, branchName, pathField, current_paths)

    if ~isfield(data, branchName) || ~isstruct(data.(branchName))
        return;
    end

    branch = data.(branchName);

    if ~isfield(branch, pathField) || ~iscell(branch.(pathField))

        warning('%s : champ de traçabilité "%s" absent. Branche réinitialisée pour éviter les incohérences.', ...
            branchName, pathField);

        data.(branchName) = struct();
        return;
    end

    current_paths = normalize_path_list(current_paths);
    old_paths = normalize_path_list(branch.(pathField));

    keep_idx = false(numel(old_paths), 1);

    for i = 1:numel(old_paths)
        if old_paths{i} == ""
            continue;
        end

        keep_idx(i) = any(strcmp(string(old_paths{i}), string(current_paths)));
    end

    fields = fieldnames(branch);

    for f = 1:numel(fields)

        fn = fields{f};

        if iscell(branch.(fn)) && numel(branch.(fn)) == numel(keep_idx)
            branch.(fn) = branch.(fn)(keep_idx);
        end
    end

    data.(branchName) = branch;
end


function data = prune_plane_branch_by_path(data, branchName, pathField, current_paths_by_group)

    if ~isfield(data, branchName) || ~isstruct(data.(branchName))
        return;
    end

    branch = data.(branchName);

    if ~isfield(branch, pathField) || ~iscell(branch.(pathField))

        warning('%s : champ de traçabilité "%s" absent. Branche réinitialisée pour éviter les incohérences.', ...
            branchName, pathField);

        data.(branchName) = struct();
        return;
    end

    fields = fieldnames(branch);

    current_paths_by_group = force_column_cell(current_paths_by_group);
    nGroups = numel(current_paths_by_group);

    % Supprime les anciens groupes au-delà de la nouvelle sélection
    for f = 1:numel(fields)

        fn = fields{f};

        if iscell(branch.(fn)) && numel(branch.(fn)) > nGroups
            branch.(fn) = branch.(fn)(1:nGroups);
        end
    end

    for m = 1:min(numel(branch.(pathField)), nGroups)

        current_paths = current_paths_by_group{m};

        if isempty(current_paths)
            current_paths = {};
        end

        if ischar(current_paths) || isstring(current_paths)
            current_paths = {char(current_paths)};
        end

        current_paths = normalize_path_list(current_paths);

        if isempty(branch.(pathField){m}) || ~iscell(branch.(pathField){m})
            continue;
        end

        old_paths = normalize_path_list(branch.(pathField){m});

        keep_p = false(numel(old_paths), 1);

        for p = 1:numel(old_paths)
            if old_paths{p} == ""
                continue;
            end

            keep_p(p) = any(strcmp(string(old_paths{p}), string(current_paths)));
        end

        for f = 1:numel(fields)

            fn = fields{f};

            if numel(branch.(fn)) >= m && ...
                    iscell(branch.(fn){m}) && ...
                    numel(branch.(fn){m}) == numel(keep_p)

                branch.(fn){m} = branch.(fn){m}(keep_p);
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