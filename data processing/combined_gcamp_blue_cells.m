function combined_plane = combined_gcamp_blue_cells(gcamp_output_folders, data)

    numFolders = numel(gcamp_output_folders);

    fields_combined = { ...
        'F_combined_by_plane', ...
        'mask_combined_by_plane', ...
        'props_combined_by_plane', ...
        'outlines_x_combined_by_plane', ...
        'outlines_y_combined_by_plane', ...
        'blue_indices_combined_by_plane' ...
    };

    data = init_combined_plane_struct_if_needed(data, numFolders, fields_combined);

    for m = 1:numFolders

        if isempty(gcamp_output_folders) || m > numel(gcamp_output_folders) || ...
           isempty(gcamp_output_folders{m}) || ~iscell(gcamp_output_folders{m}) || ...
           isempty(gcamp_output_folders{m}{1})
            fprintf('[COMBINED] group=%d | invalid gcamp_output_folders entry\n', m);
            continue;
        end

        root_folder_m = fileparts(gcamp_output_folders{m}{1});
        filePath = fullfile(root_folder_m, 'results_combined.mat');

        % -----------------------------------------
        % Sources
        % -----------------------------------------
        Fg_all  = get_group_field_safe(data, 'gcamp_plane', 'F_gcamp_by_plane', m);
        Fb_all  = get_group_field_safe(data, 'blue_plane',  'F_blue_by_plane', m);
        idx_all = get_group_field_safe(data, 'blue_plane',  'gcamp_unmatched_idx_by_plane', m);

        mask_g  = get_group_field_safe(data, 'gcamp_plane', 'gcamp_mask_by_plane', m);
        mask_b  = get_group_field_safe(data, 'blue_plane',  'mask_cellpose_by_plane', m);

        props_g = get_group_field_safe(data, 'gcamp_plane', 'gcamp_props_by_plane', m);
        props_b = get_group_field_safe(data, 'blue_plane',  'props_cellpose_by_plane', m);

        ox_g = get_group_field_safe(data, 'gcamp_plane', 'outlines_gcampx_by_plane', m);
        oy_g = get_group_field_safe(data, 'gcamp_plane', 'outlines_gcampy_by_plane', m);

        ox_b = get_group_field_safe(data, 'blue_plane', 'outlines_x_cellpose_by_plane', m);
        oy_b = get_group_field_safe(data, 'blue_plane', 'outlines_y_cellpose_by_plane', m);

        nPlanes = max([ ...
            numel(Fg_all), numel(Fb_all), numel(idx_all), ...
            numel(mask_g), numel(mask_b), ...
            numel(props_g), numel(props_b), ...
            numel(ox_g), numel(oy_g), numel(ox_b), numel(oy_b), 0]);

        fprintf('[COMBINED] group=%d | numel(Fg_all)=%d numel(Fb_all)=%d numel(idx_all)=%d | nPlanes=%d\n', ...
            m, numel(Fg_all), numel(Fb_all), numel(idx_all), nPlanes);

        if nPlanes == 0
            fprintf('[COMBINED] group=%d | no source planes detected\n', m);
            continue;
        end

        for f = 1:numel(fields_combined)
            data = ensure_combined_plane_cell(data, fields_combined{f}, m, nPlanes);
        end

        % -----------------------------------------
        % Reload si existe, sans écraser data en mémoire
        % -----------------------------------------
        if exist(filePath,'file') == 2
            loaded = load(filePath);
            data = merge_loaded_combined_into_data(data, loaded, fields_combined, m, nPlanes);
        end

        has_new_data_for_group = false;

        for p = 1:nPlanes

            if combined_plane_has_meaningful_content(data, m, p)
                fprintf('[COMBINED] group=%d plane=%d | already exists, skipping\n', m, p);
                continue;
            end

            % -------- Load plane --------
            Fg = get_plane(Fg_all,p);
            Fb = get_plane(Fb_all,p);
            idx_keep = get_plane(idx_all,p);

            Mg = get_plane(mask_g,p);
            Mb = get_plane(mask_b,p);

            Pg = get_plane(props_g,p);
            Pb = get_plane(props_b,p);

            Oxg = get_plane(ox_g,p);
            Oyg = get_plane(oy_g,p);

            Oxb = get_plane(ox_b,p);
            Oyb = get_plane(oy_b,p);

            fprintf('[COMBINED] group=%d plane=%d | size(Fg)=[%s] size(Fb)=[%s]\n', ...
                m, p, size_to_str(Fg), size_to_str(Fb));

            % =====================================================
            % Si un des deux signaux manque, combined du plan = vide
            % =====================================================
            if isempty(Fg) || isempty(Fb)
                data = set_empty_combined_plane(data, m, p);
                has_new_data_for_group = true;
                fprintf('[COMBINED] group=%d plane=%d | skipped (Fg or Fb empty)\n', m, p);
                continue;
            end

            % -------- Filter GCaMP : garder seulement non matchées --------
            if isempty(idx_keep)
                data = set_empty_combined_plane(data, m, p);
                has_new_data_for_group = true;
                fprintf('[COMBINED] group=%d plane=%d | skipped (idx_keep empty)\n', m, p);
                continue;
            end

            idx_keep = idx_keep(:);
            idx_keep = idx_keep(idx_keep >= 1 & idx_keep <= size(Fg,1));

            if isempty(idx_keep)
                data = set_empty_combined_plane(data, m, p);
                has_new_data_for_group = true;
                fprintf('[COMBINED] group=%d plane=%d | skipped (idx_keep invalid)\n', m, p);
                continue;
            end

            Fg = Fg(idx_keep, :);

            if isempty(Fg)
                data = set_empty_combined_plane(data, m, p);
                has_new_data_for_group = true;
                fprintf('[COMBINED] group=%d plane=%d | skipped (Fg empty after filtering)\n', m, p);
                continue;
            end

            if ~isempty(Mg)
                if ndims(Mg) == 3 && size(Mg,1) >= max(idx_keep)
                    Mg = Mg(idx_keep, :, :);
                else
                    Mg = [];
                end
            end

            Pg  = subset_cells_or_struct(Pg, idx_keep);
            Oxg = subset_cells_or_struct(Oxg, idx_keep);
            Oyg = subset_cells_or_struct(Oyg, idx_keep);

            if isempty(Mg) || isempty(Mb)
                data = set_empty_combined_plane(data, m, p);
                has_new_data_for_group = true;
                fprintf('[COMBINED] group=%d plane=%d | skipped (Mg or Mb empty)\n', m, p);
                continue;
            end

            if ndims(Mg) ~= 3 || ndims(Mb) ~= 3 || ...
               size(Mg,2) ~= size(Mb,2) || size(Mg,3) ~= size(Mb,3)
                data = set_empty_combined_plane(data, m, p);
                has_new_data_for_group = true;
                fprintf('[COMBINED] group=%d plane=%d | skipped (mask size mismatch: Mg=[%s], Mb=[%s])\n', ...
                    m, p, size_to_str(Mg), size_to_str(Mb));
                continue;
            end

            % -------- Concat --------
            F_combined  = cat(1, Fg, Fb);
            M_combined  = cat(1, Mg, Mb);
            P_combined  = concat_struct_or_empty(Pg, Pb);
            Ox_combined = concat_cell_or_empty(Oxg, Oxb);
            Oy_combined = concat_cell_or_empty(Oyg, Oyb);

            n_g = size(Fg,1);
            n_b = size(Fb,1);

            blue_idx = (n_g + 1):(n_g + n_b);

            % -------- Store --------
            data.combined_plane.F_combined_by_plane{m}{p}            = F_combined;
            data.combined_plane.mask_combined_by_plane{m}{p}         = M_combined;
            data.combined_plane.props_combined_by_plane{m}{p}        = P_combined;
            data.combined_plane.outlines_x_combined_by_plane{m}{p}   = Ox_combined;
            data.combined_plane.outlines_y_combined_by_plane{m}{p}   = Oy_combined;
            data.combined_plane.blue_indices_combined_by_plane{m}{p} = blue_idx(:);

            has_new_data_for_group = true;

            fprintf('[COMBINED] group=%d plane=%d | GCaMP=%d | blue=%d | total=%d\n', ...
                m, p, n_g, n_b, size(F_combined,1));
        end

        if has_new_data_for_group
            saveStruct = collect_combined_fields_for_save(data, m, fields_combined);

            if exist(filePath,'file') == 2
                save(filePath,'-struct','saveStruct','-append');
            else
                save(filePath,'-struct','saveStruct');
            end
        end
    end

    combined_plane = data.combined_plane;
end


function data = init_combined_plane_struct_if_needed(data, numFolders, fields_combined)
    if nargin < 1 || isempty(data)
        data = struct();
    end

    if ~isfield(data, 'combined_plane') || ~isstruct(data.combined_plane) || isempty(data.combined_plane)
        data.combined_plane = struct();
    end

    for f = 1:numel(fields_combined)
        fn = fields_combined{f};
        if ~isfield(data.combined_plane, fn) || ~iscell(data.combined_plane.(fn))
            tmp = cell(numFolders,1);
            [tmp{:}] = deal([]);
            data.combined_plane.(fn) = tmp;
        elseif numel(data.combined_plane.(fn)) < numFolders
            oldv = data.combined_plane.(fn);
            tmp = cell(numFolders,1);
            tmp(1:numel(oldv)) = oldv(:);
            data.combined_plane.(fn) = tmp;
        end
    end
end

function data = ensure_combined_plane_cell(data, fieldName, m, nPlanes)
    if ~isfield(data.combined_plane, fieldName)
        data.combined_plane.(fieldName) = cell(m,1);
    end

    if numel(data.combined_plane.(fieldName)) < m
        tmp = cell(m,1);
        tmp(1:numel(data.combined_plane.(fieldName))) = data.combined_plane.(fieldName)(:);
        data.combined_plane.(fieldName) = tmp;
    end

    if isempty(data.combined_plane.(fieldName){m}) || ~iscell(data.combined_plane.(fieldName){m})
        data.combined_plane.(fieldName){m} = cell(nPlanes,1);
    elseif numel(data.combined_plane.(fieldName){m}) ~= nPlanes
        old = data.combined_plane.(fieldName){m};
        new = cell(nPlanes,1);
        n = min(numel(old), nPlanes);
        new(1:n) = old(1:n);
        data.combined_plane.(fieldName){m} = new;
    end
end

function data = merge_loaded_combined_into_data(data, loaded, fields_combined, m, nPlanes)
    for f = 1:numel(fields_combined)
        fn = fields_combined{f};
        if ~isfield(loaded, fn)
            continue;
        end

        loaded_field = coerce_to_plane_cell_local(loaded.(fn), nPlanes);

        for p = 1:nPlanes
            if ~combined_plane_slot_exists(data, fn, m, p) || isempty(data.combined_plane.(fn){m}{p})
                if numel(loaded_field) >= p
                    data.combined_plane.(fn){m}{p} = loaded_field{p};
                end
            end
        end
    end
end

function tf = combined_plane_slot_exists(data, fieldName, m, p)
    tf = isfield(data, 'combined_plane') && ...
         isfield(data.combined_plane, fieldName) && ...
         numel(data.combined_plane.(fieldName)) >= m && ...
         ~isempty(data.combined_plane.(fieldName){m}) && ...
         iscell(data.combined_plane.(fieldName){m}) && ...
         numel(data.combined_plane.(fieldName){m}) >= p;
end

function tf = combined_plane_has_meaningful_content(data, m, p)
    tf = combined_plane_slot_exists(data, 'F_combined_by_plane', m, p) && ...
         combined_plane_slot_exists(data, 'mask_combined_by_plane', m, p) && ...
         combined_plane_slot_exists(data, 'props_combined_by_plane', m, p) && ...
         combined_plane_slot_exists(data, 'outlines_x_combined_by_plane', m, p) && ...
         combined_plane_slot_exists(data, 'outlines_y_combined_by_plane', m, p) && ...
         combined_plane_slot_exists(data, 'blue_indices_combined_by_plane', m, p) && ...
         ~isempty(data.combined_plane.F_combined_by_plane{m}{p}) && ...
         ~isempty(data.combined_plane.mask_combined_by_plane{m}{p}) && ...
         ~isempty(data.combined_plane.props_combined_by_plane{m}{p}) && ...
         ~isempty(data.combined_plane.outlines_x_combined_by_plane{m}{p}) && ...
         ~isempty(data.combined_plane.outlines_y_combined_by_plane{m}{p}) && ...
         ~isempty(data.combined_plane.blue_indices_combined_by_plane{m}{p});
end

function data = set_empty_combined_plane(data, m, p)
    data.combined_plane.F_combined_by_plane{m}{p}            = [];
    data.combined_plane.mask_combined_by_plane{m}{p}         = [];
    data.combined_plane.props_combined_by_plane{m}{p}        = struct([]);
    data.combined_plane.outlines_x_combined_by_plane{m}{p}   = {};
    data.combined_plane.outlines_y_combined_by_plane{m}{p}   = {};
    data.combined_plane.blue_indices_combined_by_plane{m}{p} = [];
end

function saveStruct = collect_combined_fields_for_save(data, m, fields_combined)
    saveStruct = struct();
    for f = 1:numel(fields_combined)
        fn = fields_combined{f};
        if isfield(data, 'combined_plane') && ...
           isfield(data.combined_plane, fn) && ...
           numel(data.combined_plane.(fn)) >= m
            saveStruct.(fn) = data.combined_plane.(fn){m};
        end
    end
end

function x = get_group_field_safe(data, branch, field, m)
    x = {};

    if ~isfield(data, branch) || ~isstruct(data.(branch))
        return;
    end

    if ~isfield(data.(branch), field) || numel(data.(branch).(field)) < m
        return;
    end

    if isempty(data.(branch).(field){m})
        return;
    end

    x = data.(branch).(field){m};
end

function x = get_plane(xcell, p)
    if isempty(xcell) || numel(xcell) < p
        x = [];
    else
        x = xcell{p};
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

function out = subset_cells_or_struct(x, keep_idx)
    if isempty(x)
        out = x;
        return;
    end

    if islogical(keep_idx)
        keep_idx = find(keep_idx);
    else
        keep_idx = keep_idx(:);
    end

    if iscell(x)
        keep_idx = keep_idx(keep_idx >= 1 & keep_idx <= numel(x));
        out = x(keep_idx);
    elseif isstruct(x)
        keep_idx = keep_idx(keep_idx >= 1 & keep_idx <= numel(x));
        out = x(keep_idx);
    else
        out = x;
    end
end

function out = concat_cell_or_empty(a, b)
    if isempty(a) && isempty(b)
        out = {};
    elseif isempty(a)
        out = b;
    elseif isempty(b)
        out = a;
    else
        out = [a(:); b(:)];
    end
end

function out = concat_struct_or_empty(a, b)
    if isempty(a) && isempty(b)
        out = struct([]);
    elseif isempty(a)
        out = b;
    elseif isempty(b)
        out = a;
    else
        out = [a(:); b(:)];
    end
end

function s = size_to_str(x)
    if isempty(x)
        s = 'empty';
        return;
    end

    sz = size(x);
    parts = arrayfun(@num2str, sz, 'UniformOutput', false);
    s = strjoin(parts, 'x');
end