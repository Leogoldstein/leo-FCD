function [processing_cache, data] = process_electroporated_pass1( ...
    gcamp_output_folders, include_blue_cells, ...
    date_group_paths, current_blue_TSeries_path, ...
    current_gcamp_folders_group, current_red_folders_group, ...
    current_blue_folders_group, current_green_folders_group, ...
    data)

    numFolders = numel(gcamp_output_folders);

    fields_blue_saved = { ...
        'matched_gcamp_idx_by_plane', ...
        'matched_cellpose_idx_by_plane', ...
        'gcamp_unmatched_idx_by_plane', ...
        'cellpose_unmatched_idx_by_plane', ...
        'num_cells_mask_by_plane', ...
        'mask_cellpose_by_plane', ...
        'props_cellpose_by_plane', ...
        'outlines_x_cellpose_by_plane', ...
        'outlines_y_cellpose_by_plane', ...
        'F_blue_by_plane', ...
        'blue_match_mask_by_plane'};

    fields_blue_memory = { ...
        'ops_suite2p_blue_by_plane', ...
        'blue_fall_path_by_plane'};

    fields_blue_all = [fields_blue_saved, fields_blue_memory];

    gcamp_needed = { ...
        'stat_by_plane', ...
        'F_gcamp_by_plane', ...
        'gcamp_props_by_plane', ...
        'outlines_gcampx_by_plane', ...
        'outlines_gcampy_by_plane', ...
        'iscell_gcamp_by_plane', ...
        'gcamp_mask_by_plane', ...
        'gcamp_props_false_by_plane', ...
        'outlines_gcampx_false_by_plane', ...
        'outlines_gcampy_false_by_plane', ...
        'gcamp_mask_false_by_plane'};

    data = init_blue_plane_struct_if_needed(data, numFolders, fields_blue_all);
    data = init_gcamp_plane_struct_if_needed_local(data, numFolders, gcamp_needed);

    processing_cache = cell(numFolders, 1);

    fprintf('\n============================================================\n');
    fprintf('BLUE PASS 1: CELLPPOSE PREPARATION\n');
    fprintf('============================================================\n');

    for m = 1:numFolders

        cache = struct();
        cache.valid_group = false;
        cache.skip_group = false;
        cache.nPlanes = 0;
        cache.filePath_blue = '';
        cache.filePath_gcamp = '';
        cache.gcamp_planes = {};
        cache.red_planes = {};
        cache.blue_planes = {};
        cache.green_planes = {};
        cache.F_gcamp_by_plane = {};
        cache.gcamp_props_by_plane = {};
        cache.iscell_gcamp_by_plane = {};
        cache.gcamp_mask_by_plane = {};
        cache.gcamp_mask_false_by_plane = {};
        cache.has_new_blue_data = false;
        cache.planes = {};

        fprintf('\nPreparing recording group %d/%d...\n', m, numFolders);

        if m > numel(gcamp_output_folders) || ...
                isempty(gcamp_output_folders{m}) || ...
                ~iscell(gcamp_output_folders{m}) || ...
                isempty(gcamp_output_folders{m}{1})

            fprintf('Group %d: invalid output folder, skipped.\n', m);
            cache.skip_group = true;
            processing_cache{m} = cache;
            continue;
        end

        root_folder_m = fileparts(gcamp_output_folders{m}{1});
        cache.filePath_blue = fullfile(root_folder_m, 'results_blue.mat');
        cache.filePath_gcamp = fullfile(root_folder_m, 'results_gcamp.mat');

        if m <= numel(current_gcamp_folders_group)
            cache.gcamp_planes = current_gcamp_folders_group{m};
        end

        cache.nPlanes = numel(cache.gcamp_planes);

        if cache.nPlanes == 0
            fprintf('Group %d: no GCaMP planes, skipped.\n', m);
            cache.skip_group = true;
            processing_cache{m} = cache;
            continue;
        end

        for f = 1:numel(fields_blue_all)
            data = ensure_blue_plane_cell(data, fields_blue_all{f}, m, cache.nPlanes);
        end

        for f = 1:numel(gcamp_needed)
            data = ensure_local_gcamp_plane_cell(data, gcamp_needed{f}, m, cache.nPlanes);
        end

        for p = 1:cache.nPlanes
            blue_path_p = get_blue_plane_folder(current_blue_folders_group, m, p);
            if isempty(blue_path_p)
                data.blue_plane.blue_fall_path_by_plane{m}{p} = '';
            else
                data.blue_plane.blue_fall_path_by_plane{m}{p} = char(blue_path_p);
            end
        end

        if ~blue_group_already_complete(data, m, cache.nPlanes) && ...
                exist(cache.filePath_blue, 'file') == 2

            loaded_blue = load(cache.filePath_blue);
            data = merge_loaded_blue_into_data( ...
                data, loaded_blue, fields_blue_saved, m, cache.nPlanes);
        end

        if ~local_gcamp_group_already_complete( ...
                data, gcamp_needed, m, cache.nPlanes) && ...
                exist(cache.filePath_gcamp, 'file') == 2

            loaded_gcamp = load(cache.filePath_gcamp);
            data = merge_loaded_local_gcamp_into_data( ...
                data, loaded_gcamp, gcamp_needed, m, cache.nPlanes);
        end

        if include_blue_cells ~= 1
            fprintf('Group %d: blue processing disabled.\n', m);
            cache.skip_group = true;
            processing_cache{m} = cache;
            continue;
        end

        if ~local_gcamp_group_has_values( ...
                data, 'F_gcamp_by_plane', m, cache.nPlanes)

            fprintf('Group %d: no GCaMP fluorescence, empty outputs stored.\n', m);

            for p = 1:cache.nPlanes
                if ~blue_plane_has_meaningful_content(data, m, p)
                    data = set_empty_blue_plane(data, m, p);
                    cache.has_new_blue_data = true;
                end
            end

            cache.skip_group = true;
            processing_cache{m} = cache;
            continue;
        end

        cache.F_gcamp_by_plane = coerce_to_plane_cell_local( ...
            data.gcamp_plane.F_gcamp_by_plane{m}, cache.nPlanes);

        cache.gcamp_props_by_plane = get_gcamp_field_as_plane_cell( ...
            data, 'gcamp_props_by_plane', m, cache.nPlanes);

        cache.iscell_gcamp_by_plane = get_gcamp_field_as_plane_cell( ...
            data, 'iscell_gcamp_by_plane', m, cache.nPlanes);

        cache.gcamp_mask_by_plane = get_gcamp_field_as_plane_cell( ...
            data, 'gcamp_mask_by_plane', m, cache.nPlanes);

        cache.gcamp_mask_false_by_plane = get_gcamp_field_as_plane_cell( ...
            data, 'gcamp_mask_false_by_plane', m, cache.nPlanes);

        cache.red_planes = get_group_entry(current_red_folders_group, m);
        cache.blue_planes = get_group_entry(current_blue_folders_group, m);
        cache.green_planes = get_group_entry(current_green_folders_group, m);

        cache.planes = cell(cache.nPlanes, 1);
        for p = 1:cache.nPlanes
            cache.planes{p} = struct( ...
                'process_plane', false, ...
                'meanImg_channels', [], ...
                'aligned_image', [], ...
                'npy_file_path', '', ...
                'error_message', '');
        end

        cache.valid_group = true;
        processing_cache{m} = cache;
    end

    for m = 1:numFolders

        cache = processing_cache{m};

        if cache.skip_group || ~cache.valid_group
            continue;
        end

        fprintf('\nCellpose | Recording group %d/%d | %d planes\n', ...
            m, numFolders, cache.nPlanes);

        for p = 1:cache.nPlanes

            fprintf('\nCellpose | Group %d/%d | Plane %d/%d\n', ...
                m, numFolders, p, cache.nPlanes);

            blue_plane_folder = get_blue_plane_folder( ...
                current_blue_folders_group, m, p);

            if isempty(blue_plane_folder)
                data.blue_plane.blue_fall_path_by_plane{m}{p} = '';
            else
                data.blue_plane.blue_fall_path_by_plane{m}{p} = ...
                    char(blue_plane_folder);
            end

            if ~blue_plane_slot_exists( ...
                    data, 'ops_suite2p_blue_by_plane', m, p) || ...
                    isempty(data.blue_plane.ops_suite2p_blue_by_plane{m}{p})

                if isempty(blue_plane_folder)
                    data.blue_plane.ops_suite2p_blue_by_plane{m}{p} = [];
                else
                    data.blue_plane.ops_suite2p_blue_by_plane{m}{p} = ...
                        load_ops_only(blue_plane_folder);
                end
            end

                        % =====================================================
            % Vérifier si les résultats des cellules bleues existent
            % déjà, sans empêcher le chargement de l'image alignée
            % =====================================================

            blue_results_already_complete = ...
                blue_plane_has_meaningful_content( ...
                    data, ...
                    m, ...
                    p);

            if blue_results_already_complete

                fprintf( ...
                    ['Plane %d: blue ROI results already complete. ' ...
                     'Aligned image will still be loaded.\n'], ...
                    p);
            end

            % =====================================================
            % Vérifications GCaMP nécessaires
            % =====================================================

            if p > numel(cache.F_gcamp_by_plane) || ...
                    isempty(cache.F_gcamp_by_plane{p})

                fprintf( ...
                    'Plane %d: empty GCaMP fluorescence.\n', ...
                    p);

                if ~blue_results_already_complete

                    data = set_empty_blue_plane( ...
                        data, ...
                        m, ...
                        p);

                    cache.has_new_blue_data = true;
                end

                continue;
            end

            if p > numel(cache.gcamp_planes) || ...
                    isempty(cache.gcamp_planes{p})

                fprintf( ...
                    'Plane %d: missing GCaMP folder.\n', ...
                    p);

                if ~blue_results_already_complete

                    data = set_empty_blue_plane( ...
                        data, ...
                        m, ...
                        p);

                    cache.has_new_blue_data = true;
                end

                continue;
            end

            current_blue_TSeries_path_m = ...
                get_group_entry( ...
                    current_blue_TSeries_path, ...
                    m);

            % =====================================================
            % Charger ou reconstruire les données Cellpose
            %
            % Cet appel est effectué même lorsque les résultats ROI
            % existent déjà afin de récupérer aligned_image_plane.
            % =====================================================

            try

                [ ...
                    meanImg_channels, ...
                    aligned_image_plane, ...
                    npy_file_path, ...
                    ~ ...
                ] = load_or_process_cellpose_TSeries( ...
                    cache.filePath_blue, ...
                    date_group_paths{m}, ...
                    get_plane_path( ...
                        cache.gcamp_planes, ...
                        p), ...
                    get_plane_path( ...
                        cache.red_planes, ...
                        p), ...
                    get_plane_path( ...
                        cache.blue_planes, ...
                        p), ...
                    get_plane_path( ...
                        cache.green_planes, ...
                        p), ...
                    current_blue_TSeries_path_m, ...
                    get_plane_path( ...
                        gcamp_output_folders{m}, ...
                        p));

            catch ME

                warning( ...
                    'process_blue_cells_pass1:CellposeFailed', ...
                    ['Group %d plane %d failed while loading ' ...
                     'the aligned image: %s'], ...
                    m, ...
                    p, ...
                    ME.message);

                cache.planes{p}.error_message = ...
                    ME.message;

                if ~blue_results_already_complete

                    data = set_empty_blue_plane( ...
                        data, ...
                        m, ...
                        p);

                    cache.has_new_blue_data = true;
                end

                continue;
            end

            % =====================================================
            % Stocker les images même si les ROI existaient déjà
            % =====================================================

            cache.planes{p}.meanImg_channels = ...
                meanImg_channels;

            cache.planes{p}.aligned_image = ...
                aligned_image_plane;

            % =====================================================
            % Vérifier le chemin du fichier NPY
            % =====================================================

            if isempty(npy_file_path) || ...
                    ~(ischar(npy_file_path) || ...
                      isstring(npy_file_path))

                fprintf( ...
                    ['Plane %d: invalid or empty NPY path. ' ...
                     'Aligned image was nevertheless stored.\n'], ...
                    p);

                cache.planes{p}.npy_file_path = '';

                if blue_results_already_complete

                    cache.planes{p}.process_plane = false;

                else

                    data = set_empty_blue_plane( ...
                        data, ...
                        m, ...
                        p);

                    cache.has_new_blue_data = true;
                end

                continue;
            end

            npy_file_path = ...
                char(npy_file_path);

            cache.planes{p}.npy_file_path = ...
                npy_file_path;

            if exist(npy_file_path, 'file') ~= 2

                fprintf( ...
                    ['Plane %d: NPY not found. ' ...
                     'Aligned image was nevertheless stored:\n%s\n'], ...
                    p, ...
                    npy_file_path);

                if blue_results_already_complete

                    cache.planes{p}.process_plane = false;

                else

                    data = set_empty_blue_plane( ...
                        data, ...
                        m, ...
                        p);

                    cache.has_new_blue_data = true;
                end

                continue;
            end

            fprintf( ...
                'Plane %d: Cellpose NPY ready:\n%s\n', ...
                p, ...
                npy_file_path);

            % =====================================================
            % Déterminer si le pass 2 doit traiter ce plan
            % =====================================================

            if blue_results_already_complete

                % Les ROI existent déjà :
                % l'image alignée est chargée pour l'overview,
                % mais le pass 2 ne doit pas retraiter ce plan.

                cache.planes{p}.process_plane = false;

                fprintf( ...
                    ['Plane %d: aligned image loaded. ' ...
                     'Blue ROI extraction remains skipped.\n'], ...
                    p);

            else

                % Les ROI n'existent pas encore :
                % le pass 2 pourra utiliser le fichier seg.npy.

                cache.planes{p}.process_plane = true;

                fprintf( ...
                    ['Plane %d: aligned image loaded. ' ...
                     'Blue ROI extraction enabled.\n'], ...
                    p);
            end
        end

        processing_cache{m} = cache;
    end
end


function out = get_group_entry(group_cell, m)
    out = {};
    if isempty(group_cell)
        return;
    end

    if iscell(group_cell)
        if m <= numel(group_cell)
            out = group_cell{m};
        end
    elseif ischar(group_cell) || isstring(group_cell)
        out = char(group_cell);
    end
end

function vals = get_gcamp_field_as_plane_cell(data, fieldName, m, nPlanes)
    vals = cell(nPlanes, 1);
    if isfield(data, 'gcamp_plane') && ...
            isfield(data.gcamp_plane, fieldName) && ...
            numel(data.gcamp_plane.(fieldName)) >= m

        vals = coerce_to_plane_cell_local( ...
            data.gcamp_plane.(fieldName){m}, nPlanes);
    end
end

function tf = blue_group_already_complete(data, m, nPlanes)
    tf = nPlanes > 0;
    for p = 1:nPlanes
        if ~blue_plane_has_meaningful_content(data, m, p)
            tf = false;
            return;
        end
    end
end

function tf = local_gcamp_group_already_complete(data, fields, m, nPlanes)
    tf = nPlanes > 0;
    for p = 1:nPlanes
        for f = 1:numel(fields)
            name = fields{f};
            if ~local_gcamp_slot_exists(data, name, m, p) || ...
                    isempty(data.gcamp_plane.(name){m}{p})
                tf = false;
                return;
            end
        end
    end
end

function data = init_blue_plane_struct_if_needed(data, numFolders, fields)
    if nargin < 1 || isempty(data)
        data = struct();
    end
    if ~isfield(data, 'blue_plane') || ~isstruct(data.blue_plane)
        data.blue_plane = struct();
    end
    for f = 1:numel(fields)
        name = fields{f};
        if ~isfield(data.blue_plane, name) || ...
                ~iscell(data.blue_plane.(name))
            data.blue_plane.(name) = cell(numFolders, 1);
        elseif numel(data.blue_plane.(name)) < numFolders
            old = data.blue_plane.(name);
            tmp = cell(numFolders, 1);
            tmp(1:numel(old)) = old(:);
            data.blue_plane.(name) = tmp;
        end
    end
end

function data = init_gcamp_plane_struct_if_needed_local(data, numFolders, fields)
    if ~isfield(data, 'gcamp_plane') || ~isstruct(data.gcamp_plane)
        data.gcamp_plane = struct();
    end
    for f = 1:numel(fields)
        name = fields{f};
        if ~isfield(data.gcamp_plane, name) || ...
                ~iscell(data.gcamp_plane.(name))
            data.gcamp_plane.(name) = cell(numFolders, 1);
        elseif numel(data.gcamp_plane.(name)) < numFolders
            old = data.gcamp_plane.(name);
            tmp = cell(numFolders, 1);
            tmp(1:numel(old)) = old(:);
            data.gcamp_plane.(name) = tmp;
        end
    end
end

function data = ensure_blue_plane_cell(data, fieldName, m, nPlanes)
    if ~isfield(data.blue_plane, fieldName)
        data.blue_plane.(fieldName) = cell(m, 1);
    end
    if numel(data.blue_plane.(fieldName)) < m
        tmp = cell(m, 1);
        tmp(1:numel(data.blue_plane.(fieldName))) = ...
            data.blue_plane.(fieldName)(:);
        data.blue_plane.(fieldName) = tmp;
    end
    if isempty(data.blue_plane.(fieldName){m}) || ...
            ~iscell(data.blue_plane.(fieldName){m})
        data.blue_plane.(fieldName){m} = cell(nPlanes, 1);
    elseif numel(data.blue_plane.(fieldName){m}) ~= nPlanes
        old = data.blue_plane.(fieldName){m};
        tmp = cell(nPlanes, 1);
        n = min(numel(old), nPlanes);
        tmp(1:n) = old(1:n);
        data.blue_plane.(fieldName){m} = tmp;
    end
end

function data = ensure_local_gcamp_plane_cell(data, fieldName, m, nPlanes)
    if ~isfield(data.gcamp_plane, fieldName)
        data.gcamp_plane.(fieldName) = cell(m, 1);
    end
    if numel(data.gcamp_plane.(fieldName)) < m
        tmp = cell(m, 1);
        tmp(1:numel(data.gcamp_plane.(fieldName))) = ...
            data.gcamp_plane.(fieldName)(:);
        data.gcamp_plane.(fieldName) = tmp;
    end
    if isempty(data.gcamp_plane.(fieldName){m}) || ...
            ~iscell(data.gcamp_plane.(fieldName){m})
        data.gcamp_plane.(fieldName){m} = cell(nPlanes, 1);
    elseif numel(data.gcamp_plane.(fieldName){m}) ~= nPlanes
        old = data.gcamp_plane.(fieldName){m};
        tmp = cell(nPlanes, 1);
        n = min(numel(old), nPlanes);
        tmp(1:n) = old(1:n);
        data.gcamp_plane.(fieldName){m} = tmp;
    end
end

function out = coerce_to_plane_cell_local(val, nPlanes)
    out = cell(nPlanes, 1);
    if isempty(val)
        return;
    end
    if iscell(val)
        n = min(numel(val), nPlanes);
        out(1:n) = val(1:n);
    elseif nPlanes >= 1
        out{1} = val;
    end
end

function data = merge_loaded_blue_into_data(data, loaded, fields, m, nPlanes)
    for f = 1:numel(fields)
        name = fields{f};
        if ~isfield(loaded, name)
            continue;
        end
        vals = coerce_to_plane_cell_local(loaded.(name), nPlanes);
        for p = 1:nPlanes
            if ~blue_plane_slot_exists(data, name, m, p) || ...
                    isempty(data.blue_plane.(name){m}{p})
                data.blue_plane.(name){m}{p} = vals{p};
            end
        end
    end
end

function data = merge_loaded_local_gcamp_into_data(data, loaded, fields, m, nPlanes)
    for f = 1:numel(fields)
        name = fields{f};
        if ~isfield(loaded, name)
            continue;
        end
        vals = coerce_to_plane_cell_local(loaded.(name), nPlanes);
        for p = 1:nPlanes
            if ~local_gcamp_slot_exists(data, name, m, p) || ...
                    isempty(data.gcamp_plane.(name){m}{p})
                data.gcamp_plane.(name){m}{p} = vals{p};
            end
        end
    end
end

function tf = blue_plane_slot_exists(data, fieldName, m, p)
    tf = isfield(data, 'blue_plane') && ...
        isfield(data.blue_plane, fieldName) && ...
        numel(data.blue_plane.(fieldName)) >= m && ...
        iscell(data.blue_plane.(fieldName){m}) && ...
        numel(data.blue_plane.(fieldName){m}) >= p;
end

function tf = local_gcamp_slot_exists(data, fieldName, m, p)
    tf = isfield(data, 'gcamp_plane') && ...
        isfield(data.gcamp_plane, fieldName) && ...
        numel(data.gcamp_plane.(fieldName)) >= m && ...
        iscell(data.gcamp_plane.(fieldName){m}) && ...
        numel(data.gcamp_plane.(fieldName){m}) >= p;
end

function tf = local_gcamp_group_has_values(data, fieldName, m, nPlanes)
    tf = false;
    if ~isfield(data, 'gcamp_plane') || ...
            ~isfield(data.gcamp_plane, fieldName) || ...
            numel(data.gcamp_plane.(fieldName)) < m
        return;
    end
    vals = coerce_to_plane_cell_local( ...
        data.gcamp_plane.(fieldName){m}, nPlanes);
    tf = any(~cellfun(@isempty, vals));
end

function tf = blue_plane_has_meaningful_content(data, m, p)
    required = { ...
        'F_blue_by_plane', ...
        'mask_cellpose_by_plane', ...
        'props_cellpose_by_plane', ...
        'outlines_x_cellpose_by_plane', ...
        'outlines_y_cellpose_by_plane', ...
        'num_cells_mask_by_plane'};

    tf = true;
    for i = 1:numel(required)
        name = required{i};
        if ~blue_plane_slot_exists(data, name, m, p) || ...
                isempty(data.blue_plane.(name){m}{p})
            tf = false;
            return;
        end
    end
end

function data = set_empty_blue_plane(data, m, p)
    data.blue_plane.matched_gcamp_idx_by_plane{m}{p} = [];
    data.blue_plane.matched_cellpose_idx_by_plane{m}{p} = [];
    data.blue_plane.gcamp_unmatched_idx_by_plane{m}{p} = [];
    data.blue_plane.cellpose_unmatched_idx_by_plane{m}{p} = [];
    data.blue_plane.num_cells_mask_by_plane{m}{p} = 0;
    data.blue_plane.mask_cellpose_by_plane{m}{p} = false(0,0,0);
    data.blue_plane.props_cellpose_by_plane{m}{p} = struct([]);
    data.blue_plane.outlines_x_cellpose_by_plane{m}{p} = {};
    data.blue_plane.outlines_y_cellpose_by_plane{m}{p} = {};
    data.blue_plane.F_blue_by_plane{m}{p} = [];
    data.blue_plane.blue_match_mask_by_plane{m}{p} = false(0,1);
    data.blue_plane.ops_suite2p_blue_by_plane{m}{p} = [];
end

function blue_plane_folder = get_blue_plane_folder(group, m, p)
    blue_plane_folder = '';
    if isempty(group) || m > numel(group) || isempty(group{m})
        return;
    end
    vals = group{m};
    if p <= numel(vals) && ~isempty(vals{p})
        blue_plane_folder = vals{p};
    end
end

function plane_path = get_plane_path(paths_by_plane, p)
    plane_path = '';
    if isempty(paths_by_plane) || ~iscell(paths_by_plane) || ...
            p > numel(paths_by_plane) || isempty(paths_by_plane{p})
        return;
    end
    candidate = paths_by_plane{p};
    if ischar(candidate) || isstring(candidate)
        plane_path = char(candidate);
    end
end
