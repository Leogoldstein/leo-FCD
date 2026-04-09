function blue_plane = process_blue_cells( ...
    gcamp_output_folders, include_blue_cells, ...
    date_group_paths, current_blue_TSeries_path, ...
    current_gcamp_folders_group, current_red_folders_group, current_blue_folders_group, current_green_folders_group, ...
    meanImgs_gcamp, ...
    data)

    numFolders = numel(gcamp_output_folders);

    % Champs sauvegardés
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
        'blue_match_mask_by_plane' ...
    };

    % Mémoire uniquement
    fields_blue_memory = { ...
        'ops_suite2p_blue_by_plane' ...
    };

    fields_blue_all = [fields_blue_saved, fields_blue_memory];

    gcamp_needed = { ...
        'stat_by_plane', 'F_gcamp_by_plane', 'gcamp_props_by_plane', ...
        'outlines_gcampx_by_plane', 'outlines_gcampy_by_plane', ...
        'iscell_gcamp_by_plane', ...
        'gcamp_mask_by_plane', ...
        'gcamp_props_false_by_plane', ...
        'outlines_gcampx_false_by_plane', 'outlines_gcampy_false_by_plane', ...
        'gcamp_mask_false_by_plane' ...
    };

    data = init_blue_plane_struct_if_needed(data, numFolders, fields_blue_all);
    data = init_gcamp_plane_struct_if_needed_local(data, numFolders, gcamp_needed);

    for m = 1:numFolders

        if isempty(gcamp_output_folders) || m > numel(gcamp_output_folders) || isempty(gcamp_output_folders{m})
            fprintf('Group %d: empty gcamp_output_folders entry, skipping group.\n', m);
            continue;
        end

        if ~iscell(gcamp_output_folders{m}) || isempty(gcamp_output_folders{m}{1})
            fprintf('Group %d: invalid gcamp_output_folders{%d}{1}, skipping group.\n', m, m);
            continue;
        end

        root_folder_m  = fileparts(gcamp_output_folders{m}{1});
        filePath_blue  = fullfile(root_folder_m, 'results_blue.mat');
        filePath_gcamp = fullfile(root_folder_m, 'results_gcamp.mat');

        if isempty(current_gcamp_folders_group) || m > numel(current_gcamp_folders_group) || isempty(current_gcamp_folders_group{m})
            gcamp_planes_for_session_m = {};
        else
            gcamp_planes_for_session_m = current_gcamp_folders_group{m};
        end

        nPlanes = numel(gcamp_planes_for_session_m);

        if nPlanes == 0
            fprintf('Group %d: no GCaMP planes found, skipping group.\n', m);
            continue;
        end

        for f = 1:numel(fields_blue_all)
            data = ensure_blue_plane_cell(data, fields_blue_all{f}, m, nPlanes);
        end

        for f = 1:numel(gcamp_needed)
            data = ensure_local_gcamp_plane_cell(data, gcamp_needed{f}, m, nPlanes);
        end

        if exist(filePath_blue, 'file') == 2
            loaded = load(filePath_blue);
            data = merge_loaded_blue_into_data(data, loaded, fields_blue_saved, m, nPlanes);
        end

        if exist(filePath_gcamp, 'file') == 2
            loaded_gcamp = load(filePath_gcamp);
            data = merge_loaded_local_gcamp_into_data(data, loaded_gcamp, gcamp_needed, m, nPlanes);
        end

        if ~strcmp(include_blue_cells, '1')
            fprintf('Group %d: include_blue_cells != 1, skipping blue processing.\n', m);
            continue;
        end

        if ~local_gcamp_group_has_values(data, 'F_gcamp_by_plane', m, nPlanes)
            fprintf('Group %d: no F_gcamp_by_plane, saving empty blue outputs for all planes.\n', m);

            has_new_blue_data_for_group = false;
            for p = 1:nPlanes
                if ~blue_plane_has_meaningful_content(data, m, p)
                    data = set_empty_blue_plane(data, m, p);
                    has_new_blue_data_for_group = true;
                end
            end

            if has_new_blue_data_for_group
                saveStruct_blue = collect_blue_fields_for_save(data, m, fields_blue_saved);
                if exist(filePath_blue, 'file') == 2
                    save(filePath_blue, '-struct', 'saveStruct_blue', '-append');
                else
                    save(filePath_blue, '-struct', 'saveStruct_blue');
                end
            end
            continue;
        end

        F_gcamp_by_plane = coerce_to_plane_cell_local(data.gcamp_plane.F_gcamp_by_plane{m}, nPlanes);

        gcamp_props_by_plane = cell(nPlanes,1);
        if isfield(data.gcamp_plane, 'gcamp_props_by_plane') && numel(data.gcamp_plane.gcamp_props_by_plane) >= m
            gcamp_props_by_plane = coerce_to_plane_cell_local(data.gcamp_plane.gcamp_props_by_plane{m}, nPlanes);
        end

        iscell_gcamp_by_plane = cell(nPlanes,1);
        if isfield(data.gcamp_plane, 'iscell_gcamp_by_plane') && numel(data.gcamp_plane.iscell_gcamp_by_plane) >= m
            iscell_gcamp_by_plane = coerce_to_plane_cell_local(data.gcamp_plane.iscell_gcamp_by_plane{m}, nPlanes);
        end

        gcamp_mask_by_plane = cell(nPlanes,1);
        if isfield(data.gcamp_plane, 'gcamp_mask_by_plane') && numel(data.gcamp_plane.gcamp_mask_by_plane) >= m
            gcamp_mask_by_plane = coerce_to_plane_cell_local(data.gcamp_plane.gcamp_mask_by_plane{m}, nPlanes);
        end

        gcamp_mask_false_by_plane = cell(nPlanes,1);
        if isfield(data.gcamp_plane, 'gcamp_mask_false_by_plane') && numel(data.gcamp_plane.gcamp_mask_false_by_plane) >= m
            gcamp_mask_false_by_plane = coerce_to_plane_cell_local(data.gcamp_plane.gcamp_mask_false_by_plane{m}, nPlanes);
        end

        if isempty(current_red_folders_group) || m > numel(current_red_folders_group)
            red_planes_for_session_m = {};
        else
            red_planes_for_session_m = current_red_folders_group{m};
        end

        if isempty(current_blue_folders_group) || m > numel(current_blue_folders_group)
            blue_planes_for_session_m = {};
        else
            blue_planes_for_session_m = current_blue_folders_group{m};
        end

        if isempty(current_green_folders_group) || m > numel(current_green_folders_group)
            green_planes_for_session_m = {};
        else
            green_planes_for_session_m = current_green_folders_group{m};
        end

        has_new_blue_data_for_group = false;

        fprintf('Processing blue cells for group %d (%d planes)...\n', m, nPlanes);

        for p = 1:nPlanes

            already_has_blue = blue_plane_has_meaningful_content(data, m, p);

            % Recharger ops blue en mémoire si absent (mémoire-only)
            if ~blue_plane_slot_exists(data, 'ops_suite2p_blue_by_plane', m, p) || ...
               isempty(data.blue_plane.ops_suite2p_blue_by_plane{m}{p})

                blue_plane_folder = get_blue_plane_folder(current_blue_folders_group, m, p);

                if ~isempty(blue_plane_folder)
                    data.blue_plane.ops_suite2p_blue_by_plane{m}{p} = load_ops_only(blue_plane_folder);
                else
                    data.blue_plane.ops_suite2p_blue_by_plane{m}{p} = [];
                end
            end

            if already_has_blue
                fprintf('    Plane %d: blue variables already exist, skipping.\n', p);
                continue;
            end

            if p > numel(F_gcamp_by_plane) || isempty(F_gcamp_by_plane{p})
                fprintf('    Plane %d: empty F_gcamp_plane, saving empty blue outputs.\n', p);
                data = set_empty_blue_plane(data, m, p);
                has_new_blue_data_for_group = true;
                continue;
            end

            F_gcamp_plane = F_gcamp_by_plane{p};

            if p <= numel(gcamp_props_by_plane)
                gcamp_props_plane = gcamp_props_by_plane{p}; %#ok<NASGU>
            end

            if p <= numel(gcamp_mask_by_plane)
                gcamp_mask_plane = gcamp_mask_by_plane{p};
            else
                gcamp_mask_plane = [];
            end

            if p <= numel(iscell_gcamp_by_plane)
                iscell_gcamp_plane = iscell_gcamp_by_plane{p};
            else
                iscell_gcamp_plane = [];
            end

            if m <= numel(meanImgs_gcamp) && ~isempty(meanImgs_gcamp{m}) && numel(meanImgs_gcamp{m}) >= p
                meanImg_plane = meanImgs_gcamp{m}{p};
            else
                meanImg_plane = [];
            end

            if p <= numel(gcamp_mask_false_by_plane)
                gcamp_mask_false_plane = gcamp_mask_false_by_plane{p};
            else
                gcamp_mask_false_plane = [];
            end

            if numel(gcamp_planes_for_session_m) < p || isempty(gcamp_planes_for_session_m{p})
                fprintf('    Plane %d: missing gcamp plane folder, saving empty blue outputs.\n', p);
                data = set_empty_blue_plane(data, m, p);
                has_new_blue_data_for_group = true;
                continue;
            end

            try
                [meanImg_channels, aligned_image_plane, npy_file_path, ~] = ...
                    load_or_process_cellpose_TSeries( ...
                        filePath_blue, date_group_paths{m}, ...
                        gcamp_planes_for_session_m, ...
                        red_planes_for_session_m, ...
                        blue_planes_for_session_m, ...
                        green_planes_for_session_m, ...
                        current_blue_TSeries_path, p);
            catch ME
                warning('process_blue_cells:load_or_process_cellpose_TSeriesFailed', ...
                    'Group %d plane %d: load_or_process_cellpose_TSeries failed: %s', ...
                    m, p, ME.message);
                data = set_empty_blue_plane(data, m, p);
                has_new_blue_data_for_group = true;
                continue;
            end

            if isempty(npy_file_path)
                fprintf('    Plane %d: empty npy_file_path, saving empty blue outputs.\n', p);
                data = set_empty_blue_plane(data, m, p);
                has_new_blue_data_for_group = true;
                continue;
            end

            try
                [num_cellpose_raw_p, mask_cellpose_raw_p, props_cellpose_raw_p, outlines_x_raw_p, outlines_y_raw_p] = ...
                    load_or_process_cellpose_data(npy_file_path); %#ok<ASGLU>
            catch ME
                warning('process_blue_cells:load_or_process_cellpose_dataFailed', ...
                    'Group %d plane %d: load_or_process_cellpose_data failed: %s', ...
                    m, p, ME.message);
                data = set_empty_blue_plane(data, m, p);
                has_new_blue_data_for_group = true;
                continue;
            end

            mask_cellpose_raw_p = cell_mask_list_to_stack(mask_cellpose_raw_p);

            if isempty(props_cellpose_raw_p) || isempty(meanImg_channels)
                fprintf('    Plane %d: empty Cellpose props or meanImg_channels, saving empty blue outputs.\n', p);
                data = set_empty_blue_plane(data, m, p);
                has_new_blue_data_for_group = true;
                continue;
            end

            try
                [matched_gcamp_idx_p, matched_cellpose_idx_p, ...
                 matched_gcamp_false_idx_p, matched_cellpose_false_idx_p, ...
                 gcamp_unmatched_idx_p, cellpose_unmatched_idx_p, ...
                 is_cellpose_matched_to_true_gcamp_p, IoU_matrix_p] = ...
                    match_gcamp_cellpose_masks_iou( ...
                        iscell_gcamp_plane, ...
                        gcamp_mask_plane, ...
                        gcamp_mask_false_plane, ...
                        mask_cellpose_raw_p, ...
                        0.05); %#ok<ASGLU>
            catch ME
                warning('process_blue_cells:matchMasksFailed', ...
                    'Group %d plane %d: match_gcamp_cellpose_masks_iou failed: %s', ...
                    m, p, ME.message);
                data = set_empty_blue_plane(data, m, p);
                has_new_blue_data_for_group = true;
                continue;
            end

            matched_iou_values_p = nan(numel(matched_gcamp_idx_p),1);
            for kk = 1:numel(matched_gcamp_idx_p)
                gi = matched_gcamp_idx_p(kk);
                cj = matched_cellpose_idx_p(kk);
                if gi >= 1 && gi <= size(IoU_matrix_p,1) && cj >= 1 && cj <= size(IoU_matrix_p,2)
                    matched_iou_values_p(kk) = IoU_matrix_p(gi,cj);
                end
            end

            cellpose_unmatched_or_false_idx_p = unique([ ...
                cellpose_unmatched_idx_p(:); ...
                matched_cellpose_false_idx_p(:) ...
            ], 'stable');

            try
                show_masks_and_overlaps( ...
                    meanImg_plane, aligned_image_plane, ...
                    gcamp_mask_plane, mask_cellpose_raw_p, ...
                    matched_gcamp_idx_p, matched_cellpose_idx_p, ...
                    cellpose_unmatched_or_false_idx_p, ...
                    matched_iou_values_p, ...
                    gcamp_output_folders{m}{p}, ...
                    sprintf('GCaMP_vs_Cellpose_group_%d_plane_%d', m, p));
            catch
            end

            data.blue_plane.matched_gcamp_idx_by_plane{m}{p}      = matched_gcamp_idx_p(:);
            data.blue_plane.matched_cellpose_idx_by_plane{m}{p}   = matched_cellpose_idx_p(:);
            data.blue_plane.gcamp_unmatched_idx_by_plane{m}{p}    = gcamp_unmatched_idx_p(:);
            data.blue_plane.cellpose_unmatched_idx_by_plane{m}{p} = cellpose_unmatched_or_false_idx_p(:);

            nCellpose = size(mask_cellpose_raw_p,1);
            cellpose_blue_idx_p = (1:nCellpose)';

            mask_blue_final_p  = subset_mask_stack(mask_cellpose_raw_p, cellpose_blue_idx_p);
            props_blue_final_p = subset_cells_or_struct(props_cellpose_raw_p, cellpose_blue_idx_p);
            outlines_x_blue_final_p = subset_cells_or_struct(outlines_x_raw_p, cellpose_blue_idx_p);
            outlines_y_blue_final_p = subset_cells_or_struct(outlines_y_raw_p, cellpose_blue_idx_p);

            num_blue_cellpose_p = numel(cellpose_blue_idx_p);

            try
                F_blue_final_p = get_blue_cells_rois( ...
                    F_gcamp_plane, [], ...
                    num_blue_cellpose_p, mask_blue_final_p, ...
                    props_blue_final_p, ...
                    outlines_x_blue_final_p, outlines_y_blue_final_p, ...
                    gcamp_planes_for_session_m{p}, "all");
            catch ME
                warning('process_blue_cells:get_blue_cells_roisFailed', ...
                    'Group %d plane %d: get_blue_cells_rois failed: %s', ...
                    m, p, ME.message);
                data = set_empty_blue_plane(data, m, p);
                has_new_blue_data_for_group = true;
                continue;
            end

            if ~isempty(F_blue_final_p)
                F_blue_final_p = double(F_blue_final_p);
            else
                F_blue_final_p = [];
            end

            blue_from_matched_gcamp_mask_p = ismember( ...
                cellpose_blue_idx_p(:), ...
                unique(round(matched_cellpose_idx_p(:))));

            data.blue_plane.F_blue_by_plane{m}{p}              = F_blue_final_p;
            data.blue_plane.mask_cellpose_by_plane{m}{p}       = mask_blue_final_p;
            data.blue_plane.props_cellpose_by_plane{m}{p}      = props_blue_final_p;
            data.blue_plane.outlines_x_cellpose_by_plane{m}{p} = outlines_x_blue_final_p;
            data.blue_plane.outlines_y_cellpose_by_plane{m}{p} = outlines_y_blue_final_p;
            data.blue_plane.num_cells_mask_by_plane{m}{p}      = size(F_blue_final_p, 1);
            data.blue_plane.blue_match_mask_by_plane{m}{p}     = blue_from_matched_gcamp_mask_p(:);

            has_new_blue_data_for_group = true;
        end

        if has_new_blue_data_for_group
            saveStruct_blue = collect_blue_fields_for_save(data, m, fields_blue_saved);

            if exist(filePath_blue, 'file') == 2
                save(filePath_blue, '-struct', 'saveStruct_blue', '-append');
            else
                save(filePath_blue, '-struct', 'saveStruct_blue');
            end

            fprintf('Group %d: blue extraction fields updated in results_blue.mat.\n', m);
        else
            fprintf('Group %d: no new blue data, results_blue.mat not modified.\n', m);
        end
    end

    blue_plane = data.blue_plane;
end

function data = init_blue_plane_struct_if_needed(data, numFolders, fields)
    if nargin < 1 || isempty(data)
        data = struct();
    end

    if ~isfield(data, 'blue_plane') || ~isstruct(data.blue_plane) || isempty(data.blue_plane)
        data.blue_plane = struct();
    end

    for f = 1:numel(fields)
        fieldName = fields{f};
        if ~isfield(data.blue_plane, fieldName) || ~iscell(data.blue_plane.(fieldName))
            data.blue_plane.(fieldName) = cell(numFolders, 1);
        elseif numel(data.blue_plane.(fieldName)) < numFolders
            oldv = data.blue_plane.(fieldName);
            tmpCell = cell(numFolders, 1);
            tmpCell(1:numel(oldv)) = oldv(:);
            data.blue_plane.(fieldName) = tmpCell;
        end
    end
end

function data = init_gcamp_plane_struct_if_needed_local(data, numFolders, fields)
    if ~isfield(data, 'gcamp_plane') || ~isstruct(data.gcamp_plane) || isempty(data.gcamp_plane)
        data.gcamp_plane = struct();
    end

    for f = 1:numel(fields)
        fieldName = fields{f};
        if ~isfield(data.gcamp_plane, fieldName) || ~iscell(data.gcamp_plane.(fieldName))
            data.gcamp_plane.(fieldName) = cell(numFolders,1);
        elseif numel(data.gcamp_plane.(fieldName)) < numFolders
            oldv = data.gcamp_plane.(fieldName);
            tmpCell = cell(numFolders,1);
            tmpCell(1:numel(oldv)) = oldv(:);
            data.gcamp_plane.(fieldName) = tmpCell;
        end
    end
end

function data = ensure_blue_plane_cell(data, fieldName, m, nPlanes)
    if ~isfield(data.blue_plane, fieldName)
        data.blue_plane.(fieldName) = cell(m,1);
    end
    if numel(data.blue_plane.(fieldName)) < m
        tmp = cell(m,1);
        tmp(1:numel(data.blue_plane.(fieldName))) = data.blue_plane.(fieldName)(:);
        data.blue_plane.(fieldName) = tmp;
    end
    if isempty(data.blue_plane.(fieldName){m}) || ~iscell(data.blue_plane.(fieldName){m})
        data.blue_plane.(fieldName){m} = cell(nPlanes,1);
    elseif numel(data.blue_plane.(fieldName){m}) ~= nPlanes
        old = data.blue_plane.(fieldName){m};
        new = cell(nPlanes,1);
        n = min(numel(old), nPlanes);
        new(1:n) = old(1:n);
        data.blue_plane.(fieldName){m} = new;
    end
end

function data = ensure_local_gcamp_plane_cell(data, fieldName, m, nPlanes)
    if ~isfield(data.gcamp_plane, fieldName)
        data.gcamp_plane.(fieldName) = cell(m,1);
    end
    if numel(data.gcamp_plane.(fieldName)) < m
        tmp = cell(m,1);
        tmp(1:numel(data.gcamp_plane.(fieldName))) = data.gcamp_plane.(fieldName)(:);
        data.gcamp_plane.(fieldName) = tmp;
    end
    if isempty(data.gcamp_plane.(fieldName){m}) || ~iscell(data.gcamp_plane.(fieldName){m})
        data.gcamp_plane.(fieldName){m} = cell(nPlanes,1);
    elseif numel(data.gcamp_plane.(fieldName){m}) ~= nPlanes
        old = data.gcamp_plane.(fieldName){m};
        new = cell(nPlanes,1);
        n = min(numel(old), nPlanes);
        new(1:n) = old(1:n);
        data.gcamp_plane.(fieldName){m} = new;
    end
end

function out = coerce_to_plane_cell_local(val, nPlanes)
    if isempty(val)
        out = cell(nPlanes,1);
    elseif iscell(val)
        out = cell(nPlanes,1);
        nCopy = min(numel(val), nPlanes);
        out(1:nCopy) = val(1:nCopy);
    else
        out = cell(nPlanes,1);
        if nPlanes >= 1
            out{1} = val;
        end
    end
end

function data = merge_loaded_blue_into_data(data, loaded, fields_blue, m, nPlanes)
    for f = 1:numel(fields_blue)
        fieldName = fields_blue{f};
        if ~isfield(loaded, fieldName)
            continue;
        end

        loaded_field = coerce_to_plane_cell_local(loaded.(fieldName), nPlanes);

        for p = 1:nPlanes
            if ~blue_plane_slot_exists(data, fieldName, m, p) || isempty(data.blue_plane.(fieldName){m}{p})
                if numel(loaded_field) >= p
                    data.blue_plane.(fieldName){m}{p} = loaded_field{p};
                end
            end
        end
    end
end

function data = merge_loaded_local_gcamp_into_data(data, loaded_gcamp, gcamp_needed, m, nPlanes)
    for f = 1:numel(gcamp_needed)
        fieldName = gcamp_needed{f};
        if ~isfield(loaded_gcamp, fieldName)
            continue;
        end

        loaded_field = coerce_to_plane_cell_local(loaded_gcamp.(fieldName), nPlanes);

        for p = 1:nPlanes
            if ~local_gcamp_slot_exists(data, fieldName, m, p) || isempty(data.gcamp_plane.(fieldName){m}{p})
                if numel(loaded_field) >= p
                    data.gcamp_plane.(fieldName){m}{p} = loaded_field{p};
                end
            end
        end
    end
end

function tf = blue_plane_slot_exists(data, fieldName, m, p)
    tf = isfield(data, 'blue_plane') && ...
         isfield(data.blue_plane, fieldName) && ...
         numel(data.blue_plane.(fieldName)) >= m && ...
         ~isempty(data.blue_plane.(fieldName){m}) && ...
         iscell(data.blue_plane.(fieldName){m}) && ...
         numel(data.blue_plane.(fieldName){m}) >= p;
end

function tf = local_gcamp_slot_exists(data, fieldName, m, p)
    tf = isfield(data, 'gcamp_plane') && ...
         isfield(data.gcamp_plane, fieldName) && ...
         numel(data.gcamp_plane.(fieldName)) >= m && ...
         ~isempty(data.gcamp_plane.(fieldName){m}) && ...
         iscell(data.gcamp_plane.(fieldName){m}) && ...
         numel(data.gcamp_plane.(fieldName){m}) >= p;
end

function tf = local_gcamp_group_has_values(data, fieldName, m, nPlanes)
    tf = false;
    if ~isfield(data, 'gcamp_plane') || ~isfield(data.gcamp_plane, fieldName) || numel(data.gcamp_plane.(fieldName)) < m
        return;
    end
    vals = coerce_to_plane_cell_local(data.gcamp_plane.(fieldName){m}, nPlanes);
    tf = any(~cellfun(@isempty, vals));
end

function tf = blue_plane_has_meaningful_content(data, m, p)
    tf = blue_plane_slot_exists(data, 'F_blue_by_plane', m, p) && ...
         blue_plane_slot_exists(data, 'mask_cellpose_by_plane', m, p) && ...
         blue_plane_slot_exists(data, 'props_cellpose_by_plane', m, p) && ...
         blue_plane_slot_exists(data, 'outlines_x_cellpose_by_plane', m, p) && ...
         blue_plane_slot_exists(data, 'outlines_y_cellpose_by_plane', m, p) && ...
         blue_plane_slot_exists(data, 'num_cells_mask_by_plane', m, p) && ...
         ~isempty(data.blue_plane.F_blue_by_plane{m}{p}) && ...
         ~isempty(data.blue_plane.mask_cellpose_by_plane{m}{p}) && ...
         ~isempty(data.blue_plane.props_cellpose_by_plane{m}{p}) && ...
         ~isempty(data.blue_plane.outlines_x_cellpose_by_plane{m}{p}) && ...
         ~isempty(data.blue_plane.outlines_y_cellpose_by_plane{m}{p}) && ...
         ~isempty(data.blue_plane.num_cells_mask_by_plane{m}{p});
end

function out = subset_cells_or_struct(x, keep_mask)
    if isempty(x)
        out = x;
        return;
    end

    if iscell(x)
        if islogical(keep_mask)
            if numel(x) == numel(keep_mask)
                out = x(keep_mask);
            else
                out = x;
            end
        else
            idx = keep_mask(:);
            idx = idx(idx >= 1 & idx <= numel(x));
            out = x(idx);
        end
    elseif isstruct(x)
        if islogical(keep_mask)
            if numel(x) == numel(keep_mask)
                out = x(keep_mask);
            else
                out = x;
            end
        else
            idx = keep_mask(:);
            idx = idx(idx >= 1 & idx <= numel(x));
            out = x(idx);
        end
    else
        out = x;
    end
end

function out = subset_mask_stack(mask_stack, keep_idx_or_mask)
    if isempty(mask_stack)
        out = mask_stack;
        return;
    end

    if islogical(keep_idx_or_mask)
        keep_idx = find(keep_idx_or_mask);
    else
        keep_idx = keep_idx_or_mask(:);
    end

    if isempty(keep_idx)
        out = false(0, size(mask_stack,2), size(mask_stack,3));
        return;
    end

    out = mask_stack(keep_idx, :, :);
end

function stack = cell_mask_list_to_stack(mask_cellpose)
    if isempty(mask_cellpose)
        stack = false(0,0,0);
        return;
    end

    if ~iscell(mask_cellpose)
        if islogical(mask_cellpose) || isnumeric(mask_cellpose)
            stack = logical(mask_cellpose);
            return;
        end
        error('cell_mask_list_to_stack:InvalidType', ...
            'mask_cellpose doit être un cell array ou un stack logique.');
    end

    N = numel(mask_cellpose);
    firstMask = mask_cellpose{1};

    if isempty(firstMask) || ~ismatrix(firstMask)
        error('cell_mask_list_to_stack:InvalidFirstMask', ...
            'Le premier masque Cellpose est vide ou non 2D.');
    end

    H = size(firstMask,1);
    W = size(firstMask,2);

    stack = false(N, H, W);

    for k = 1:N
        Mk = mask_cellpose{k};

        if isempty(Mk)
            continue;
        end

        if ~ismatrix(Mk) || size(Mk,1) ~= H || size(Mk,2) ~= W
            error('cell_mask_list_to_stack:SizeMismatch', ...
                'Le masque Cellpose %d a une taille [%d %d], attendu [%d %d].', ...
                k, size(Mk,1), size(Mk,2), H, W);
        end

        stack(k,:,:) = logical(Mk);
    end
end

function data = set_empty_blue_plane(data, m, p)
    data.blue_plane.matched_gcamp_idx_by_plane{m}{p}      = [];
    data.blue_plane.matched_cellpose_idx_by_plane{m}{p}   = [];
    data.blue_plane.gcamp_unmatched_idx_by_plane{m}{p}    = [];
    data.blue_plane.cellpose_unmatched_idx_by_plane{m}{p} = [];

    data.blue_plane.num_cells_mask_by_plane{m}{p}         = 0;
    data.blue_plane.mask_cellpose_by_plane{m}{p}          = false(0,0,0);
    data.blue_plane.props_cellpose_by_plane{m}{p}         = struct([]);
    data.blue_plane.outlines_x_cellpose_by_plane{m}{p}    = {};
    data.blue_plane.outlines_y_cellpose_by_plane{m}{p}    = {};
    data.blue_plane.F_blue_by_plane{m}{p}                 = [];
    data.blue_plane.blue_match_mask_by_plane{m}{p}        = false(0,1);
    data.blue_plane.ops_suite2p_blue_by_plane{m}{p}       = [];
end

function saveStruct_blue = collect_blue_fields_for_save(data, m, fields_blue)
    saveStruct_blue = struct();

    for f = 1:numel(fields_blue)
        fieldName = fields_blue{f};
        if isfield(data, 'blue_plane') && isfield(data.blue_plane, fieldName) && numel(data.blue_plane.(fieldName)) >= m
            saveStruct_blue.(fieldName) = data.blue_plane.(fieldName){m};
        end
    end
end


function blue_plane_folder = get_blue_plane_folder(current_blue_folders_group, m, p)

    blue_plane_folder = '';

    if isempty(current_blue_folders_group) || m > numel(current_blue_folders_group)
        return;
    end

    planes_m = current_blue_folders_group{m};

    if isempty(planes_m) || numel(planes_m) < p || isempty(planes_m{p})
        return;
    end

    blue_plane_folder = planes_m{p};
end