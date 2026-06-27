function gcamp_plane = process_gcamp_cells( ...
    gcamp_output_folders, ...
    current_gcamp_folders_group, ...
    meanImgs_gcamp, ...
    data)

    numFolders = numel(gcamp_output_folders);

    fields_gcamp_saved = { ...
        'F_gcamp_by_plane', 'F_deconv_gcamp_by_plane', ...
        'stat_by_plane', 'iscell_gcamp_by_plane', 'iscell_idx_gcamp_by_plane', ...
        'stat_false_by_plane', 'iscell_false_by_plane', ...
        'outlines_gcampx_by_plane', 'outlines_gcampy_by_plane', ...
        'gcamp_mask_by_plane', 'gcamp_props_by_plane', ...
        'imageHeight_by_plane', 'imageWidth_by_plane', ...
        'outlines_gcampx_false_by_plane', 'outlines_gcampy_false_by_plane', ...
        'gcamp_mask_false_by_plane', 'gcamp_props_false_by_plane' ...
    };

    fields_gcamp_memory = { ...
        'ops_suite2p_by_plane', ...
        'gcamp_fall_path_by_plane' ...
    };

    fields_gcamp_all = [fields_gcamp_saved, fields_gcamp_memory];

    data = init_gcamp_plane_struct_if_needed(data, numFolders, fields_gcamp_all);

    for m = 1:numFolders

        if isempty(current_gcamp_folders_group) || m > numel(current_gcamp_folders_group)
            gcamp_planes = {};
        else
            gcamp_planes = current_gcamp_folders_group{m};
        end

        nPlanes = numel(gcamp_planes);

        for f = 1:numel(fields_gcamp_all)
            data = ensure_gcamp_plane_cell(data, fields_gcamp_all{f}, m, nPlanes);
        end

        for p = 1:nPlanes
            data.gcamp_plane.gcamp_fall_path_by_plane{m}{p} = char(gcamp_planes{p});
        end

        root_folder_m = extract_gcamp_root_folder(gcamp_output_folders, m);
        if isempty(root_folder_m)
            warning('process_gcamp_cells:noOutputFolder', ...
                'Impossible de déterminer le dossier de sortie pour m=%d.', m);
            continue;
        end

        filePath_gcamp = fullfile(root_folder_m, 'results_gcamp.mat');

        % -------------------------------------------------------------
        % Ne recharge results_gcamp.mat que si nécessaire
        % -------------------------------------------------------------
        [already_complete, missing] = gcamp_group_already_complete(data, m, nPlanes);

        if already_complete
        
            fprintf('Group %d: toutes les données GCaMP déjà présentes en mémoire.\n', m);
        
        else
        
            fprintf('Group %d: données incomplètes en mémoire.\n', m);
        
            for i = 1:numel(missing)
                fprintf('   - Plan %d : %s\n', ...
                    missing(i).plane, missing(i).field);
            end
        
            if exist(filePath_gcamp,'file') == 2
                fprintf('Group %d: chargement depuis results_gcamp.mat.\n', m);
        
                loaded = load(filePath_gcamp);
                data = merge_loaded_gcamp_into_data( ...
                    data, loaded, fields_gcamp_saved, m, nPlanes);
            end
        end

        has_new_data_for_group = false;

        for p = 1:nPlanes

            fall_path = gcamp_planes{p};
            if isempty(fall_path)
                continue;
            end

            fall_path = char(fall_path);
            data.gcamp_plane.gcamp_fall_path_by_plane{m}{p} = fall_path;

            already_has_raw = ...
                gcamp_field_has_value(data,'F_gcamp_by_plane',m,p) && ...
                gcamp_field_has_value(data,'stat_by_plane',m,p) && ...
                gcamp_field_has_value(data,'iscell_gcamp_by_plane',m,p) && ...
                gcamp_field_has_value(data,'iscell_idx_gcamp_by_plane',m,p);

            already_has_true_masks = ...
                gcamp_field_has_value(data, 'gcamp_props_by_plane', m, p) && ...
                gcamp_field_has_value(data, 'gcamp_mask_by_plane', m, p) && ...
                gcamp_field_has_value(data, 'outlines_gcampx_by_plane', m, p) && ...
                gcamp_field_has_value(data, 'outlines_gcampy_by_plane', m, p);

            false_stat_exists = gcamp_field_slot_exists(data, 'stat_false_by_plane', m, p) && ...
                                ~isempty(get_gcamp_plane_or_empty(data, 'stat_false_by_plane', m, p));

            already_has_false_masks = ...
                ~false_stat_exists || ...
                (gcamp_field_has_value(data, 'gcamp_props_false_by_plane', m, p) && ...
                 gcamp_field_has_value(data, 'gcamp_mask_false_by_plane', m, p) && ...
                 gcamp_field_has_value(data, 'outlines_gcampx_false_by_plane', m, p) && ...
                 gcamp_field_has_value(data, 'outlines_gcampy_false_by_plane', m, p));

            if already_has_raw && already_has_true_masks && already_has_false_masks

                if ~gcamp_field_slot_exists(data, 'ops_suite2p_by_plane', m, p) || ...
                        isempty(data.gcamp_plane.ops_suite2p_by_plane{m}{p})
                    data.gcamp_plane.ops_suite2p_by_plane{m}{p} = load_ops_only(fall_path);
                end

                fprintf('Group %d plane %d: toutes les variables de ce plan sont déjà présentes, aucun chargement ni recalcul.\n', m, p);
                continue;
            end

            if ~already_has_raw

                [~, F, F_deconv, ops, stat, iscell_cells, iscell_cells_idx, stat_false, iscell_false] = ...
                    load_data(fall_path);

                data.gcamp_plane.F_gcamp_by_plane{m}{p}        = F;
                data.gcamp_plane.F_deconv_gcamp_by_plane{m}{p} = F_deconv;
                data.gcamp_plane.stat_by_plane{m}{p}           = stat;
                data.gcamp_plane.iscell_gcamp_by_plane{m}{p}   = iscell_cells;
                data.gcamp_plane.iscell_idx_gcamp_by_plane{m}{p} = iscell_cells_idx;
                data.gcamp_plane.stat_false_by_plane{m}{p}     = stat_false;
                data.gcamp_plane.iscell_false_by_plane{m}{p}   = iscell_false;

                data.gcamp_plane.ops_suite2p_by_plane{m}{p}    = ops;

                has_new_data_for_group = true;

            else
                stat          = get_gcamp_plane_or_empty(data, 'stat_by_plane', m, p);
                iscell_cells  = get_gcamp_plane_or_empty(data, 'iscell_gcamp_by_plane', m, p);
                stat_false    = get_gcamp_plane_or_empty(data, 'stat_false_by_plane', m, p);
                iscell_false  = get_gcamp_plane_or_empty(data, 'iscell_false_by_plane', m, p);

                if ~gcamp_field_slot_exists(data, 'ops_suite2p_by_plane', m, p) || ...
                        isempty(data.gcamp_plane.ops_suite2p_by_plane{m}{p})
                    data.gcamp_plane.ops_suite2p_by_plane{m}{p} = load_ops_only(fall_path);
                end
            end

            meanImg_plane = [];
            if nargin >= 3 && ~isempty(meanImgs_gcamp) && ...
                    m <= numel(meanImgs_gcamp) && ~isempty(meanImgs_gcamp{m}) && ...
                    p <= numel(meanImgs_gcamp{m}) && ~isempty(meanImgs_gcamp{m}{p})
                meanImg_plane = meanImgs_gcamp{m}{p};
            end

            imgSize_ref = [];
            if ~isempty(meanImg_plane)
                imgSize_ref = size(meanImg_plane);
                imgSize_ref = imgSize_ref(1:2);

                if ~gcamp_field_has_value(data, 'imageHeight_by_plane', m, p)
                    data.gcamp_plane.imageHeight_by_plane{m}{p} = imgSize_ref(1);
                    has_new_data_for_group = true;
                end

                if ~gcamp_field_has_value(data, 'imageWidth_by_plane', m, p)
                    data.gcamp_plane.imageWidth_by_plane{m}{p} = imgSize_ref(2);
                    has_new_data_for_group = true;
                end
            end

            if ~already_has_true_masks
                if ~isempty(stat) && ~isempty(iscell_cells)
                    try
                        valid_cells = 1:size(iscell_cells, 1);

                        [~, outlines_gcampx_plane, outlines_gcampy_plane, ~, ~, ~, ...
                            gcamp_mask_plane, gcamp_props_plane] = ...
                            load_calcium_mask(iscell_cells, stat, valid_cells, imgSize_ref);

                        data.gcamp_plane.outlines_gcampx_by_plane{m}{p} = outlines_gcampx_plane;
                        data.gcamp_plane.outlines_gcampy_by_plane{m}{p} = outlines_gcampy_plane;
                        data.gcamp_plane.gcamp_mask_by_plane{m}{p}      = gcamp_mask_plane;
                        data.gcamp_plane.gcamp_props_by_plane{m}{p}     = gcamp_props_plane;

                        has_new_data_for_group = true;

                    catch ME
                        warning('process_gcamp_cells:mask_true', ...
                            'Group %d plane %d: impossible de construire les masques vrais (%s).', ...
                            m, p, ME.message);

                        data = assign_empty_true_gcamp_masks_if_missing(data, m, p);
                        has_new_data_for_group = true;
                    end
                else
                    data = assign_empty_true_gcamp_masks_if_missing(data, m, p);
                    has_new_data_for_group = true;
                end
            end

            if ~already_has_false_masks
                if ~isempty(stat_false) && ~isempty(iscell_false)
                    try
                        valid_cells_false = 1:size(iscell_false, 1);

                        [~, outlines_gcampx_false_plane, outlines_gcampy_false_plane, ~, ~, ~, ...
                            gcamp_mask_false_plane, gcamp_props_false_plane] = ...
                            load_calcium_mask(iscell_false, stat_false, valid_cells_false, imgSize_ref);

                        data.gcamp_plane.outlines_gcampx_false_by_plane{m}{p} = outlines_gcampx_false_plane;
                        data.gcamp_plane.outlines_gcampy_false_by_plane{m}{p} = outlines_gcampy_false_plane;
                        data.gcamp_plane.gcamp_mask_false_by_plane{m}{p}      = gcamp_mask_false_plane;
                        data.gcamp_plane.gcamp_props_false_by_plane{m}{p}     = gcamp_props_false_plane;

                        has_new_data_for_group = true;

                    catch ME
                        warning('process_gcamp_cells:mask_false', ...
                            'Group %d plane %d: impossible de construire les masques faux (%s).', ...
                            m, p, ME.message);

                        data = assign_empty_false_gcamp_masks_if_missing(data, m, p);
                        has_new_data_for_group = true;
                    end
                else
                    data = assign_empty_false_gcamp_masks_if_missing(data, m, p);
                    has_new_data_for_group = true;
                end
            end
        end

        save_gcamp_fields_if_needed(filePath_gcamp, data, fields_gcamp_saved, m, has_new_data_for_group);
    end

    gcamp_plane = data.gcamp_plane;
end


% =====================================================================
% Helpers
% =====================================================================
function [tf, missing] = gcamp_group_already_complete(data, m, nPlanes)

    required_fields = { ...
        'F_gcamp_by_plane', ...
        'stat_by_plane', ...
        'iscell_gcamp_by_plane', ...
        'iscell_idx_gcamp_by_plane', ...
        'gcamp_props_by_plane', ...
        'gcamp_mask_by_plane', ...
        'outlines_gcampx_by_plane', ...
        'outlines_gcampy_by_plane' ...
    };

    tf = true;
    missing = struct('plane',{},'field',{});

    if nPlanes == 0
        tf = false;
        return;
    end

    for p = 1:nPlanes

        for i = 1:numel(required_fields)

            fieldName = required_fields{i};

            if ~gcamp_field_has_value(data, fieldName, m, p)

                tf = false;

                missing(end+1).plane = p;
                missing(end).field = fieldName;

            end
        end
    end
end


function data = init_gcamp_plane_struct_if_needed(data, numFolders, fields)

    if nargin < 1 || isempty(data)
        data = struct();
    end

    if ~isfield(data, 'gcamp_plane') || ~isstruct(data.gcamp_plane) || isempty(data.gcamp_plane)
        data.gcamp_plane = struct();
    end

    for f = 1:numel(fields)
        fieldName = fields{f};

        if ~isfield(data.gcamp_plane, fieldName) || ~iscell(data.gcamp_plane.(fieldName))
            data.gcamp_plane.(fieldName) = cell(numFolders,1);

        elseif numel(data.gcamp_plane.(fieldName)) < numFolders
            oldv = data.gcamp_plane.(fieldName);
            tmp = cell(numFolders,1);
            tmp(1:numel(oldv)) = oldv(:);
            data.gcamp_plane.(fieldName) = tmp;
        end
    end
end


function data = ensure_gcamp_plane_cell(data, fieldName, m, nPlanes)

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


function out = coerce_to_plane_cell(val, nPlanes)

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


function tf = gcamp_field_slot_exists(data, fieldName, m, p)

    tf = isfield(data, 'gcamp_plane') && ...
         isfield(data.gcamp_plane, fieldName) && ...
         numel(data.gcamp_plane.(fieldName)) >= m && ...
         ~isempty(data.gcamp_plane.(fieldName){m}) && ...
         iscell(data.gcamp_plane.(fieldName){m}) && ...
         numel(data.gcamp_plane.(fieldName){m}) >= p;
end


function tf = gcamp_field_has_value(data, fieldName, m, p)

    tf = gcamp_field_slot_exists(data, fieldName, m, p) && ...
         ~isempty(data.gcamp_plane.(fieldName){m}{p});
end


function v = get_gcamp_plane_or_empty(data, fieldName, m, p)

    v = [];

    if gcamp_field_slot_exists(data, fieldName, m, p)
        v = data.gcamp_plane.(fieldName){m}{p};
    end
end


function data = merge_loaded_gcamp_into_data(data, loaded, fields_gcamp, m, nPlanes)

    for f = 1:numel(fields_gcamp)

        fieldName = fields_gcamp{f};

        if ~isfield(loaded, fieldName)
            continue;
        end

        loaded_field = coerce_to_plane_cell(loaded.(fieldName), nPlanes);

        if ~isfield(data.gcamp_plane, fieldName) || ...
                numel(data.gcamp_plane.(fieldName)) < m || ...
                isempty(data.gcamp_plane.(fieldName){m}) || ...
                ~iscell(data.gcamp_plane.(fieldName){m})

            data.gcamp_plane.(fieldName){m} = loaded_field;
            continue;
        end

        for p = 1:nPlanes
            if ~gcamp_field_slot_exists(data, fieldName, m, p) || ...
                    isempty(data.gcamp_plane.(fieldName){m}{p})

                if numel(loaded_field) >= p
                    data.gcamp_plane.(fieldName){m}{p} = loaded_field{p};
                end
            end
        end
    end
end


function root_folder_m = extract_gcamp_root_folder(gcamp_output_folders, m)

    root_folder_m = '';

    if isempty(gcamp_output_folders) || ...
            m > numel(gcamp_output_folders) || ...
            isempty(gcamp_output_folders{m})
        return;
    end

    this_entry = gcamp_output_folders{m};

    if iscell(this_entry)
        if ~isempty(this_entry{1})
            root_folder_m = fileparts(this_entry{1});
        end

    elseif ischar(this_entry) || isstring(this_entry)
        root_folder_m = char(this_entry);
    end
end


function data = assign_empty_true_gcamp_masks_if_missing(data, m, p)

    fields = { ...
        'outlines_gcampx_by_plane', ...
        'outlines_gcampy_by_plane', ...
        'gcamp_mask_by_plane', ...
        'gcamp_props_by_plane' ...
    };

    for i = 1:numel(fields)
        fn = fields{i};

        if ~gcamp_field_slot_exists(data, fn, m, p) || isempty(data.gcamp_plane.(fn){m}{p})
            data.gcamp_plane.(fn){m}{p} = [];
        end
    end
end


function data = assign_empty_false_gcamp_masks_if_missing(data, m, p)

    fields = { ...
        'outlines_gcampx_false_by_plane', ...
        'outlines_gcampy_false_by_plane', ...
        'gcamp_mask_false_by_plane', ...
        'gcamp_props_false_by_plane' ...
    };

    for i = 1:numel(fields)
        fn = fields{i};

        if ~gcamp_field_slot_exists(data, fn, m, p) || isempty(data.gcamp_plane.(fn){m}{p})
            data.gcamp_plane.(fn){m}{p} = [];
        end
    end
end


function save_gcamp_fields_if_needed(filePath_gcamp, data, fields_gcamp, m, has_new_data_for_group)

    if ~has_new_data_for_group
        fprintf('Group %d: no new gcamp data, results_gcamp.mat not modified.\n', m);
        return;
    end

    saveStruct = struct();

    for f = 1:numel(fields_gcamp)

        fieldName = fields_gcamp{f};

        if isfield(data, 'gcamp_plane') && ...
                isfield(data.gcamp_plane, fieldName) && ...
                numel(data.gcamp_plane.(fieldName)) >= m

            saveStruct.(fieldName) = data.gcamp_plane.(fieldName){m};
        end
    end

    if exist(filePath_gcamp, 'file') == 2
        save(filePath_gcamp, '-struct', 'saveStruct', '-append');
    else
        save(filePath_gcamp, '-struct', 'saveStruct');
    end

    fprintf('Group %d: gcamp fields updated in results_gcamp.mat.\n', m);
end