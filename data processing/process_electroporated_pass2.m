function [blue_plane, data] = process_electroporated_pass2( ...
        processing_cache, gcamp_output_folders, meanImgs_gcamp, data)

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
        'blue_match_mask_by_plane', ...
        'roi_extraction_completed_by_plane', ...
        'roi_extraction_npy_signature_by_plane'};

    numFolders = numel(processing_cache);

    fprintf('\n');
    fprintf('============================================================\n');
    fprintf('ELECTROPORATED-CELL ROI EXTRACTION\n');
    fprintf('============================================================\n');

    % ==========================================================
    % Initialiser blue_plane si nécessaire
    % ==========================================================
    if ~isfield(data, 'blue_plane') || ...
            isempty(data.blue_plane) || ...
            ~isstruct(data.blue_plane)

        data.blue_plane = struct();
    end

    % ==========================================================
    % Boucle sur les acquisitions
    % ==========================================================
    for m = 1:numFolders

        cache = processing_cache{m};

        if isempty(cache)
            continue;
        end

        if ~isfield(cache, 'skip_group') || ...
                ~isfield(cache, 'valid_group')
            continue;
        end

        if cache.skip_group || ~cache.valid_group
            continue;
        end

        if ~isfield(cache, 'has_new_blue_data')
            cache.has_new_blue_data = false;
        end

        fprintf('\n');
        fprintf('------------------------------------------------------------\n');
        fprintf('Acquisition %d/%d\n', m, numFolders);
        fprintf('Planes      : %d\n', cache.nPlanes);
        fprintf('------------------------------------------------------------\n');

        % ======================================================
        % Boucle sur les plans
        % ======================================================
        for p = 1:cache.nPlanes

            if p > numel(cache.planes) || ...
                    isempty(cache.planes{p}) || ...
                    ~isfield(cache.planes{p}, 'process_plane') || ...
                    ~cache.planes{p}.process_plane

                continue;
            end

            npy_file_path = cache.planes{p}.npy_file_path;

            % ==================================================
            % Vérifier la présence du fichier NPY
            % ==================================================
            if isempty(npy_file_path) || ...
                    ~(ischar(npy_file_path) || isstring(npy_file_path)) || ...
                    ~isfile(npy_file_path)

                fprintf('\n');
                fprintf('  ----------------------------------------------------------\n');
                fprintf('  Plane %d/%d\n', p, cache.nPlanes);
                fprintf('  Status: no valid Cellpose NPY file\n');
                fprintf('  ----------------------------------------------------------\n');

                data = set_empty_blue_plane(data, m, p);
                data = set_blue_extraction_status( ...
                    data, m, p, false, []);

                cache.has_new_blue_data = true;
                continue;
            end

            npy_file_path = char(npy_file_path);

            % ==================================================
            % Vérifier si l’extraction est déjà à jour
            % ==================================================
            extraction_is_current = ...
                is_blue_roi_extraction_current( ...
                    data, m, p, npy_file_path);

            fprintf('\n');
            fprintf('  ----------------------------------------------------------\n');
            fprintf('  Plane %d/%d\n', p, cache.nPlanes);
            fprintf('  ----------------------------------------------------------\n');

            if extraction_is_current

                fprintf('  Status: ROI extraction already completed\n');
                fprintf('  Action: existing results retained\n');
                fprintf('  NPY   : %s\n', npy_file_path);

                continue;
            end

            fprintf('  Status: ROI extraction required\n');
            fprintf('  NPY   : %s\n', npy_file_path);

            meanImg_channels = ...
                cache.planes{p}.meanImg_channels;

            aligned_image_plane = ...
                cache.planes{p}.aligned_image;

            F_gcamp_plane = ...
                cache.F_gcamp_by_plane{p};

            gcamp_mask_plane = ...
                get_plane_value( ...
                    cache.gcamp_mask_by_plane, p);

            iscell_gcamp_plane = ...
                get_plane_value( ...
                    cache.iscell_gcamp_by_plane, p);

            gcamp_mask_false_plane = ...
                get_plane_value( ...
                    cache.gcamp_mask_false_by_plane, p);

            % ==================================================
            % Image moyenne GCaMP du plan
            % ==================================================
            meanImg_plane = [];

            if m <= numel(meanImgs_gcamp) && ...
                    ~isempty(meanImgs_gcamp{m}) && ...
                    p <= numel(meanImgs_gcamp{m})

                meanImg_plane = meanImgs_gcamp{m}{p};
            end

            % ==================================================
            % Charger les données Cellpose
            % ==================================================
            try

                [~, mask_cellpose_raw_p, ...
                    props_cellpose_raw_p, ...
                    outlines_x_raw_p, ...
                    outlines_y_raw_p] = ...
                    load_or_process_cellpose_data( ...
                        npy_file_path);

            catch ME

                warning( ...
                    'process_blue_cells_pass2:LoadCellposeFailed', ...
                    'Acquisition %d plane %d failed: %s', ...
                    m, p, ME.message);

                data = set_empty_blue_plane(data, m, p);
                data = set_blue_extraction_status( ...
                    data, m, p, false, []);

                cache.has_new_blue_data = true;
                continue;
            end

            % ==================================================
            % Convertir les masques en stack
            % ==================================================
            try

                mask_cellpose_raw_p = ...
                    cell_mask_list_to_stack( ...
                        mask_cellpose_raw_p);

            catch ME

                warning( ...
                    'process_blue_cells_pass2:MaskConversionFailed', ...
                    'Acquisition %d plane %d failed: %s', ...
                    m, p, ME.message);

                data = set_empty_blue_plane(data, m, p);
                data = set_blue_extraction_status( ...
                    data, m, p, false, []);

                cache.has_new_blue_data = true;
                continue;
            end

            % ==================================================
            % Vérifier les données Cellpose
            % ==================================================
            if isempty(props_cellpose_raw_p) || ...
                    isempty(meanImg_channels)

                fprintf('  Status: empty Cellpose data\n');

                data = set_empty_blue_plane(data, m, p);
                data = set_blue_extraction_status( ...
                    data, m, p, false, []);

                cache.has_new_blue_data = true;
                continue;
            end

            % ==================================================
            % Matching entre Suite2p et Cellpose
            % ==================================================
            try

                [matched_gcamp_idx_p, ...
                    matched_cellpose_idx_p, ...
                    ~, ...
                    matched_cellpose_false_idx_p, ...
                    gcamp_unmatched_idx_p, ...
                    cellpose_unmatched_idx_p, ...
                    ~, ...
                    IoU_matrix_p] = ...
                    match_gcamp_cellpose_masks_iou( ...
                        iscell_gcamp_plane, ...
                        gcamp_mask_plane, ...
                        gcamp_mask_false_plane, ...
                        mask_cellpose_raw_p, ...
                        0.05);

            catch ME

                warning( ...
                    'process_blue_cells_pass2:MatchFailed', ...
                    'Acquisition %d plane %d failed: %s', ...
                    m, p, ME.message);

                data = set_empty_blue_plane(data, m, p);
                data = set_blue_extraction_status( ...
                    data, m, p, false, []);

                cache.has_new_blue_data = true;
                continue;
            end

            % ==================================================
            % Valeurs IoU des correspondances
            % ==================================================
            matched_iou_values_p = ...
                nan(numel(matched_gcamp_idx_p), 1);

            for kk = 1:numel(matched_gcamp_idx_p)

                gi = matched_gcamp_idx_p(kk);
                cj = matched_cellpose_idx_p(kk);

                if gi >= 1 && ...
                        gi <= size(IoU_matrix_p, 1) && ...
                        cj >= 1 && ...
                        cj <= size(IoU_matrix_p, 2)

                    matched_iou_values_p(kk) = ...
                        IoU_matrix_p(gi, cj);
                end
            end

            cellpose_unmatched_or_false_idx_p = ...
                unique( ...
                    [cellpose_unmatched_idx_p(:); ...
                     matched_cellpose_false_idx_p(:)], ...
                    'stable');

            % ==================================================
            % Figure de vérification
            % ==================================================
            try

                show_masks_and_overlaps( ...
                    meanImg_plane, ...
                    aligned_image_plane, ...
                    gcamp_mask_plane, ...
                    mask_cellpose_raw_p, ...
                    matched_gcamp_idx_p, ...
                    matched_cellpose_idx_p, ...
                    cellpose_unmatched_or_false_idx_p, ...
                    matched_iou_values_p, ...
                    gcamp_output_folders{m}{p}, ...
                    sprintf( ...
                        'GCaMP_vs_Cellpose_group_%d_plane_%d', ...
                        m, p));

            catch ME

                fprintf( ...
                    '  Visualization failed: %s\n', ...
                    ME.message);
            end

            % ==================================================
            % Sauvegarder les correspondances
            % ==================================================
            data.blue_plane. ...
                matched_gcamp_idx_by_plane{m}{p} = ...
                matched_gcamp_idx_p(:);

            data.blue_plane. ...
                matched_cellpose_idx_by_plane{m}{p} = ...
                matched_cellpose_idx_p(:);

            data.blue_plane. ...
                gcamp_unmatched_idx_by_plane{m}{p} = ...
                gcamp_unmatched_idx_p(:);

            data.blue_plane. ...
                cellpose_unmatched_idx_by_plane{m}{p} = ...
                cellpose_unmatched_or_false_idx_p(:);

            % ==================================================
            % Toutes les cellules Cellpose sont conservées
            % ==================================================
            nCellpose = size(mask_cellpose_raw_p, 1);

            cellpose_blue_idx_p = ...
                (1:nCellpose)';

            mask_blue_final_p = ...
                subset_mask_stack( ...
                    mask_cellpose_raw_p, ...
                    cellpose_blue_idx_p);

            props_blue_final_p = ...
                subset_cells_or_struct( ...
                    props_cellpose_raw_p, ...
                    cellpose_blue_idx_p);

            outlines_x_blue_final_p = ...
                subset_cells_or_struct( ...
                    outlines_x_raw_p, ...
                    cellpose_blue_idx_p);

            outlines_y_blue_final_p = ...
                subset_cells_or_struct( ...
                    outlines_y_raw_p, ...
                    cellpose_blue_idx_p);

            % ==================================================
            % Extraction des traces fluorescentes
            % ==================================================
            try

                F_blue_final_p = ...
                    get_blue_cells_rois( ...
                        F_gcamp_plane, ...
                        [], ...
                        numel(cellpose_blue_idx_p), ...
                        mask_blue_final_p, ...
                        props_blue_final_p, ...
                        outlines_x_blue_final_p, ...
                        outlines_y_blue_final_p, ...
                        cache.gcamp_planes{p}, ...
                        "all");

            catch ME

                warning( ...
                    'process_blue_cells_pass2:GetROIsFailed', ...
                    'Acquisition %d plane %d failed: %s', ...
                    m, p, ME.message);

                data = set_empty_blue_plane(data, m, p);
                data = set_blue_extraction_status( ...
                    data, m, p, false, []);

                cache.has_new_blue_data = true;
                continue;
            end

            if ~isempty(F_blue_final_p)
                F_blue_final_p = double(F_blue_final_p);
            end

            % ==================================================
            % Identifier les cellules correspondant à Suite2p
            % ==================================================
            valid_matched_cellpose_idx = ...
                matched_cellpose_idx_p(:);

            valid_matched_cellpose_idx = ...
                valid_matched_cellpose_idx( ...
                    isfinite(valid_matched_cellpose_idx));

            valid_matched_cellpose_idx = ...
                unique( ...
                    round(valid_matched_cellpose_idx));

            blue_from_matched_gcamp_mask_p = ...
                ismember( ...
                    cellpose_blue_idx_p(:), ...
                    valid_matched_cellpose_idx);

            % ==================================================
            % Enregistrer les résultats du plan
            % ==================================================
            data.blue_plane. ...
                F_blue_by_plane{m}{p} = ...
                F_blue_final_p;

            data.blue_plane. ...
                mask_cellpose_by_plane{m}{p} = ...
                mask_blue_final_p;

            data.blue_plane. ...
                props_cellpose_by_plane{m}{p} = ...
                props_blue_final_p;

            data.blue_plane. ...
                outlines_x_cellpose_by_plane{m}{p} = ...
                outlines_x_blue_final_p;

            data.blue_plane. ...
                outlines_y_cellpose_by_plane{m}{p} = ...
                outlines_y_blue_final_p;

            data.blue_plane. ...
                num_cells_mask_by_plane{m}{p} = ...
                size(F_blue_final_p, 1);

            data.blue_plane. ...
                blue_match_mask_by_plane{m}{p} = ...
                blue_from_matched_gcamp_mask_p(:);

            % ==================================================
            % Marquer l’extraction comme terminée
            % ==================================================
            current_signature = ...
                get_npy_file_signature( ...
                    npy_file_path);

            data = set_blue_extraction_status( ...
                data, ...
                m, ...
                p, ...
                true, ...
                current_signature);

            cache.has_new_blue_data = true;

            fprintf('  Status: ROI extraction completed\n');
            fprintf('  Cells : %d\n', size(F_blue_final_p, 1));
        end

        % ======================================================
        % Sauvegarder les résultats de l’acquisition
        % ======================================================
        if cache.has_new_blue_data

            saveStruct_blue = ...
                collect_blue_fields_for_save( ...
                    data, ...
                    m, ...
                    fields_blue_saved);

            if exist(cache.filePath_blue, 'file') == 2

                save( ...
                    cache.filePath_blue, ...
                    '-struct', ...
                    'saveStruct_blue', ...
                    '-append');

            else

                save( ...
                    cache.filePath_blue, ...
                    '-struct', ...
                    'saveStruct_blue');
            end

            fprintf('\n');
            fprintf('Results saved:\n');
            fprintf('%s\n', cache.filePath_blue);
        else

            fprintf('\n');
            fprintf('No new ROI extraction for acquisition %d.\n', m);
        end

        processing_cache{m} = cache;
    end

    blue_plane = data.blue_plane;
end


% =========================================================================
% Vérifier si l’extraction des ROIs est déjà à jour
% =========================================================================
function extraction_is_current = ...
        is_blue_roi_extraction_current( ...
            data, m, p, npy_file_path)

    extraction_is_current = false;

    if ~isfield(data, 'blue_plane') || ...
            isempty(data.blue_plane) || ...
            ~isstruct(data.blue_plane)

        return;
    end

    blue_plane = data.blue_plane;

    % ==========================================================
    % Vérifier le marqueur d’extraction terminée
    % ==========================================================
    if ~isfield( ...
            blue_plane, ...
            'roi_extraction_completed_by_plane')

        return;
    end

    completed_value = get_nested_plane_value( ...
        blue_plane.roi_extraction_completed_by_plane, ...
        m, p);

    if isempty(completed_value) || ...
            ~islogical_or_numeric_true(completed_value)

        return;
    end

    % ==========================================================
    % Vérifier que les principaux résultats existent
    % ==========================================================
    required_fields = { ...
        'F_blue_by_plane', ...
        'mask_cellpose_by_plane', ...
        'props_cellpose_by_plane', ...
        'num_cells_mask_by_plane', ...
        'blue_match_mask_by_plane'};

    for k = 1:numel(required_fields)

        field_name = required_fields{k};

        if ~isfield(blue_plane, field_name)
            return;
        end

        if ~nested_plane_entry_exists( ...
                blue_plane.(field_name), m, p)

            return;
        end
    end

    % ==========================================================
    % Vérifier la signature du fichier NPY
    % ==========================================================
    if ~isfield( ...
            blue_plane, ...
            'roi_extraction_npy_signature_by_plane')

        return;
    end

    saved_signature = get_nested_plane_value( ...
        blue_plane.roi_extraction_npy_signature_by_plane, ...
        m, p);

    current_signature = ...
        get_npy_file_signature(npy_file_path);

    if isempty(saved_signature) || ...
            isempty(current_signature)

        return;
    end

    extraction_is_current = ...
        compare_npy_signatures( ...
            saved_signature, ...
            current_signature);
end


% =========================================================================
% Enregistrer le statut de l’extraction
% =========================================================================
function data = set_blue_extraction_status( ...
        data, m, p, completed, signature)

    if ~isfield(data, 'blue_plane') || ...
            isempty(data.blue_plane) || ...
            ~isstruct(data.blue_plane)

        data.blue_plane = struct();
    end

    data.blue_plane. ...
        roi_extraction_completed_by_plane{m}{p} = ...
        logical(completed);

    if completed && ~isempty(signature)

        data.blue_plane. ...
            roi_extraction_npy_signature_by_plane{m}{p} = ...
            signature;

    else

        data.blue_plane. ...
            roi_extraction_npy_signature_by_plane{m}{p} = ...
            struct( ...
                'path', '', ...
                'bytes', [], ...
                'datenum', []);
    end
end


% =========================================================================
% Obtenir la signature du fichier NPY
% =========================================================================
function signature = get_npy_file_signature(npy_file_path)

    signature = [];

    if isempty(npy_file_path) || ...
            ~(ischar(npy_file_path) || isstring(npy_file_path))

        return;
    end

    npy_file_path = char(npy_file_path);

    if ~isfile(npy_file_path)
        return;
    end

    file_info = dir(npy_file_path);

    if isempty(file_info)
        return;
    end

    signature = struct();

    signature.path = npy_file_path;
    signature.bytes = file_info(1).bytes;
    signature.datenum = file_info(1).datenum;
end


% =========================================================================
% Comparer deux signatures NPY
% =========================================================================
function signatures_match = ...
        compare_npy_signatures( ...
            saved_signature, current_signature)

    signatures_match = false;

    if ~isstruct(saved_signature) || ...
            ~isstruct(current_signature)

        return;
    end

    required_fields = { ...
        'path', ...
        'bytes', ...
        'datenum'};

    for k = 1:numel(required_fields)

        field_name = required_fields{k};

        if ~isfield(saved_signature, field_name) || ...
                ~isfield(current_signature, field_name)

            return;
        end
    end

    saved_path = char(string(saved_signature.path));
    current_path = char(string(current_signature.path));

    same_path = strcmpi( ...
        saved_path, ...
        current_path);

    same_size = isequal( ...
        double(saved_signature.bytes), ...
        double(current_signature.bytes));

    saved_date = double(saved_signature.datenum);
    current_date = double(current_signature.datenum);

    same_date = ...
        isfinite(saved_date) && ...
        isfinite(current_date) && ...
        abs(saved_date - current_date) < 1e-10;

    signatures_match = ...
        same_path && ...
        same_size && ...
        same_date;
end


% =========================================================================
% Vérifier qu’une entrée m/p existe, même lorsqu’elle est vide
% =========================================================================
function entry_exists = ...
        nested_plane_entry_exists(values, m, p)

    entry_exists = false;

    if ~iscell(values) || ...
            m < 1 || ...
            m > numel(values)

        return;
    end

    acquisition_values = values{m};

    if ~iscell(acquisition_values) || ...
            p < 1 || ...
            p > numel(acquisition_values)

        return;
    end

    entry_exists = true;
end


% =========================================================================
% Récupérer une valeur imbriquée {m}{p}
% =========================================================================
function value = ...
        get_nested_plane_value(values, m, p)

    value = [];

    if ~nested_plane_entry_exists(values, m, p)
        return;
    end

    value = values{m}{p};
end


% =========================================================================
% Tester un marqueur logique ou numérique
% =========================================================================
function tf = islogical_or_numeric_true(value)

    tf = false;

    if isempty(value) || numel(value) ~= 1
        return;
    end

    if islogical(value)
        tf = value;
        return;
    end

    if isnumeric(value)
        tf = isfinite(value) && value ~= 0;
    end
end


% =========================================================================
% Obtenir la valeur d’un plan
% =========================================================================
function value = get_plane_value(values, p)

    value = [];

    if iscell(values) && ...
            p >= 1 && ...
            p <= numel(values)

        value = values{p};
    end
end


% =========================================================================
% Sous-sélectionner des cellules ou des structures
% =========================================================================
function out = subset_cells_or_struct(x, keep_mask)

    if isempty(x)
        out = x;
        return;
    end

    if iscell(x) || isstruct(x)

        if islogical(keep_mask)

            if numel(x) == numel(keep_mask)
                out = x(keep_mask);
            else
                out = x;
            end

        else

            idx = keep_mask(:);

            idx = idx( ...
                idx >= 1 & ...
                idx <= numel(x));

            out = x(idx);
        end

    else

        out = x;
    end
end


% =========================================================================
% Sous-sélectionner un stack de masques
% =========================================================================
function out = subset_mask_stack( ...
        mask_stack, keep_idx_or_mask)

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

        out = false( ...
            0, ...
            size(mask_stack, 2), ...
            size(mask_stack, 3));

    else

        out = mask_stack(keep_idx, :, :);
    end
end


% =========================================================================
% Convertir une liste Cellpose en stack de masques
% =========================================================================
function stack = ...
        cell_mask_list_to_stack(mask_cellpose)

    if isempty(mask_cellpose)

        stack = false(0, 0, 0);
        return;
    end

    if ~iscell(mask_cellpose)

        if islogical(mask_cellpose) || ...
                isnumeric(mask_cellpose)

            stack = logical(mask_cellpose);
            return;
        end

        error( ...
            'cell_mask_list_to_stack:InvalidType', ...
            ['Cellpose masks must be a cell array ' ...
             'or numeric stack.']);
    end

    N = numel(mask_cellpose);

    firstMask = mask_cellpose{1};

    if isempty(firstMask) || ...
            ~ismatrix(firstMask)

        error( ...
            'cell_mask_list_to_stack:InvalidFirstMask', ...
            'First Cellpose mask is empty or not 2D.');
    end

    H = size(firstMask, 1);
    W = size(firstMask, 2);

    stack = false(N, H, W);

    for k = 1:N

        Mk = mask_cellpose{k};

        if isempty(Mk)
            continue;
        end

        if ~ismatrix(Mk) || ...
                size(Mk, 1) ~= H || ...
                size(Mk, 2) ~= W

            error( ...
                'cell_mask_list_to_stack:SizeMismatch', ...
                ['Cellpose mask %d has inconsistent ' ...
                 'dimensions.'], ...
                k);
        end

        stack(k, :, :) = logical(Mk);
    end
end


% =========================================================================
% Enregistrer un résultat vide après un échec
% =========================================================================
function data = set_empty_blue_plane(data, m, p)

    if ~isfield(data, 'blue_plane') || ...
            isempty(data.blue_plane) || ...
            ~isstruct(data.blue_plane)

        data.blue_plane = struct();
    end

    data.blue_plane. ...
        matched_gcamp_idx_by_plane{m}{p} = [];

    data.blue_plane. ...
        matched_cellpose_idx_by_plane{m}{p} = [];

    data.blue_plane. ...
        gcamp_unmatched_idx_by_plane{m}{p} = [];

    data.blue_plane. ...
        cellpose_unmatched_idx_by_plane{m}{p} = [];

    data.blue_plane. ...
        num_cells_mask_by_plane{m}{p} = 0;

    data.blue_plane. ...
        mask_cellpose_by_plane{m}{p} = ...
        false(0, 0, 0);

    data.blue_plane. ...
        props_cellpose_by_plane{m}{p} = ...
        struct([]);

    data.blue_plane. ...
        outlines_x_cellpose_by_plane{m}{p} = {};

    data.blue_plane. ...
        outlines_y_cellpose_by_plane{m}{p} = {};

    data.blue_plane. ...
        F_blue_by_plane{m}{p} = [];

    data.blue_plane. ...
        blue_match_mask_by_plane{m}{p} = ...
        false(0, 1);

    data.blue_plane. ...
        ops_suite2p_blue_by_plane{m}{p} = [];
end


% =========================================================================
% Préparer les champs à sauvegarder
% =========================================================================
function saveStruct_blue = ...
        collect_blue_fields_for_save( ...
            data, m, fields)

    saveStruct_blue = struct();

    for f = 1:numel(fields)

        name = fields{f};

        if isfield(data, 'blue_plane') && ...
                isfield(data.blue_plane, name) && ...
                numel(data.blue_plane.(name)) >= m

            saveStruct_blue.(name) = ...
                data.blue_plane.(name){m};
        end
    end
end