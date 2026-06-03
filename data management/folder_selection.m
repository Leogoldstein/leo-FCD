function selected_groups = folder_selection(choices, group_order, dataFolders_by_group)

    destinationFolder = 'D:/Imaging/jm/';
    root_path = 'D:\Imaging';

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

    selected_groups = group_selected_groups_by_type(selected_groups_flat);

    [selected_groups, daytime] = create_gcamp_output_folders(selected_groups);
end


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
        T = cell2table(animal_date_list, ...
            'VariableNames', {'type','line','animal','date','age','sex'});

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