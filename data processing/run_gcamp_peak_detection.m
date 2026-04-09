function data = run_gcamp_peak_detection( ...
    gcamp_output_folders, ...
    meta_tbl, ...
    sampling_rate_group, synchronous_frames_group, ...
    current_animal_group, current_ages_group, ...
    data, meanImgs_gcamp, ...
    current_gcamp_TSeries_path)

    numFolders = numel(gcamp_output_folders);

    % -------------------------------------------------
    % Champs de détection par branche
    % -------------------------------------------------
    fields_detect_gcamp = { ...
        'F0_gcamp_by_plane', 'noise_est_gcamp_by_plane', ...
        'valid_gcamp_cells_by_plane', 'DF_gcamp_by_plane', ...
        'Raster_gcamp_by_plane', 'Acttmp2_gcamp_by_plane', ...
        'StartEnd_gcamp_by_plane', 'MAct_gcamp_by_plane', ...
        'thresholds_gcamp_by_plane', 'bad_segs_gcamp_plane', ...
        'opts_detection_gcamp_by_plane', ...
        'isort1_gcamp_by_plane', 'isort2_gcamp_by_plane', 'Sm_gcamp_by_plane' ...
    };

    fields_detect_blue = { ...
        'F0_blue_by_plane', 'noise_est_blue_by_plane', 'SNR_blue_by_plane', ...
        'valid_blue_cells_by_plane', 'DF_blue_by_plane', ...
        'Raster_blue_by_plane', 'Acttmp2_blue_by_plane', ...
        'StartEnd_blue_by_plane', 'MAct_blue_by_plane', ...
        'thresholds_blue_by_plane', 'bad_segs_blue_plane', ...
        'opts_detection_blue_by_plane', ...
        'isort1_blue_by_plane', 'isort2_blue_by_plane', 'Sm_blue_by_plane' ...
    };

    fields_detect_combined = { ...
        'F0_combined_by_plane', 'noise_est_combined_by_plane', ...
        'valid_combined_cells_by_plane', 'DF_combined_by_plane', ...
        'Raster_combined_by_plane', 'Acttmp2_combined_by_plane', ...
        'StartEnd_combined_by_plane', 'MAct_combined_by_plane', ...
        'thresholds_combined_by_plane', 'bad_segs_combined_plane', ...
        'opts_detection_combined_by_plane', ...
        'isort1_combined_by_plane', 'isort2_combined_by_plane', 'Sm_combined_by_plane' ...
    };

    data = init_detection_branch_if_needed(data, 'gcamp_plane', numFolders, fields_detect_gcamp);
    data = init_detection_branch_if_needed(data, 'blue_plane', numFolders, fields_detect_blue);
    data = init_detection_branch_if_needed(data, 'combined_plane', numFolders, fields_detect_combined);

    % -------------------------------------------------
    % Boucle groupes
    % -------------------------------------------------
    for m = 1:numFolders

        has_new_gcamp_group    = false;
        has_new_blue_group     = false;
        has_new_combined_group = false;

        nPlanes = infer_nplanes_for_group_new(data, m);
        if nPlanes == 0
            fprintf('Group %d: no planes found, skipping.\n', m);
            continue;
        end

        for f = 1:numel(fields_detect_gcamp)
            data = ensure_branch_plane_cell(data, 'gcamp_plane', fields_detect_gcamp{f}, m, nPlanes);
        end
        for f = 1:numel(fields_detect_blue)
            data = ensure_branch_plane_cell(data, 'blue_plane', fields_detect_blue{f}, m, nPlanes);
        end
        for f = 1:numel(fields_detect_combined)
            data = ensure_branch_plane_cell(data, 'combined_plane', fields_detect_combined{f}, m, nPlanes);
        end

        if m <= numel(meanImgs_gcamp) && ~isempty(meanImgs_gcamp{m})
            meanImgs_m = meanImgs_gcamp{m};
        else
            meanImgs_m = cell(nPlanes,1);
        end

        if m <= numel(current_gcamp_TSeries_path) && ~isempty(current_gcamp_TSeries_path{m})
            TSeries_m = current_gcamp_TSeries_path{m};
        else
            TSeries_m = '';
        end

        % --- speed récupéré depuis data.movie ---
        if isfield(data, 'movie') && ...
           isfield(data.movie, 'speed_active_group') && ...
           numel(data.movie.speed_active_group) >= m
            speed_m = data.movie.speed_active_group{m};
        else
            speed_m = [];
        end

        outdir_m = fileparts(gcamp_output_folders{m}{1});
        filePath_gcamp    = fullfile(outdir_m, 'results_gcamp.mat');
        filePath_blue     = fullfile(outdir_m, 'results_blue.mat');
        filePath_combined = fullfile(outdir_m, 'results_combined.mat');

        if exist(filePath_gcamp, 'file') == 2
            loaded_gcamp = load(filePath_gcamp);
            data = merge_loaded_branch_into_data(data, 'gcamp_plane', loaded_gcamp, fields_detect_gcamp, m, nPlanes);
        end

        if exist(filePath_blue, 'file') == 2
            loaded_blue = load(filePath_blue);
            data = merge_loaded_branch_into_data(data, 'blue_plane', loaded_blue, fields_detect_blue, m, nPlanes);
        end

        if exist(filePath_combined, 'file') == 2
            loaded_combined = load(filePath_combined);
            data = merge_loaded_branch_into_data(data, 'combined_plane', loaded_combined, fields_detect_combined, m, nPlanes);
        end

        group_choice_state = struct();
        group_choice_state.mode = '';
        group_choice_state.ask_each_plane = false;
        group_choice_state.initialized = false;

        % -------------------------------------------------
        % Boucle plans
        % -------------------------------------------------
        for p = 1:nPlanes

            Fg = get_branch_plane_or_empty(data, 'gcamp_plane', 'F_gcamp_by_plane', m, p);
            Fb = get_branch_plane_or_empty(data, 'blue_plane', 'F_blue_by_plane', m, p);
            Fc = get_branch_plane_or_empty(data, 'combined_plane', 'F_combined_by_plane', m, p);

            has_gcamp    = ~isempty(Fg);
            has_blue     = ~isempty(Fb);
            has_combined = ~isempty(Fc);

            if ~has_gcamp && ~has_blue && ~has_combined
                fprintf('Group %d plane %d: no GCaMP, blue, or combined data.\n', m, p);
                continue;
            end

            if numel(meanImgs_m) >= p
                meanImg = meanImgs_m{p};
            else
                meanImg = [];
            end

            if ~isempty(TSeries_m)
                tiff_path = fullfile(TSeries_m, sprintf('plane%d', p-1), 'Concatenated.tif');
            else
                tiff_path = '';
            end

            [choice, group_choice_state] = choose_signal_mode_for_plane_groupwise( ...
                has_gcamp, has_blue, has_combined, m, p, group_choice_state);

            if isempty(choice)
                fprintf('Group %d plane %d: user cancelled.\n', m, p);
                continue;
            end

            blue_indices_in = [];
            masks_in        = [];

            switch choice
                case 'gcamp'
                    F_in        = Fg;
                    stat_in     = get_branch_plane_or_empty(data, 'gcamp_plane', 'stat_by_plane', m, p);
                    iscell_in   = get_branch_plane_or_empty(data, 'gcamp_plane', 'iscell_gcamp_by_plane', m, p);
                    ops_in      = get_branch_plane_or_empty(data, 'gcamp_plane', 'ops_suite2p_by_plane', m, p);
                    viewer_mode = has_existing_detection_new(data, 'gcamp_plane', 'DF_gcamp_by_plane', m, p);
                    cell_type   = 'gcamp';
                    family      = 'gcamp';
                    masks_in    = get_branch_plane_or_empty(data, 'gcamp_plane', 'gcamp_mask_by_plane', m, p);

                case 'blue'
                    F_in        = Fb;
                    stat_in     = [];
                    iscell_in   = [];
                    ops_in      = get_branch_plane_or_empty(data, 'blue_plane', 'ops_suite2p_blue_by_plane', m, p);
                    viewer_mode = has_existing_detection_new(data, 'blue_plane', 'DF_blue_by_plane', m, p);
                    cell_type   = 'electroporated';
                    family      = 'blue';
                    masks_in    = get_branch_plane_or_empty(data, 'blue_plane', 'mask_cellpose_by_plane', m, p);

                case 'combined'
                    F_in = get_branch_plane_or_empty(data, 'combined_plane', 'F_combined_by_plane', m, p);
                    blue_idx = get_branch_plane_or_empty(data, 'combined_plane', 'blue_indices_combined_by_plane', m, p);

                    if isempty(F_in)
                        fprintf('Group %d plane %d: combined signal empty.\n', m, p);
                        continue;
                    end

                    stat_in     = [];
                    iscell_in   = [];
                    ops_in      = get_branch_plane_or_empty(data, 'gcamp_plane', 'ops_suite2p_by_plane', m, p);
                    viewer_mode = has_existing_detection_new(data, 'combined_plane', 'DF_combined_by_plane', m, p);
                    cell_type   = 'combined';
                    family      = 'combined';
                    masks_in    = get_branch_plane_or_empty(data, 'combined_plane', 'mask_combined_by_plane', m, p);

                    if ~isempty(blue_idx)
                        blue_indices_in = blue_idx(:);
                    else
                        blue_indices_in = [];
                    end

                otherwise
                    continue;
            end

            if isempty(F_in)
                fprintf('Group %d plane %d: selected signal is empty.\n', m, p);
                continue;
            end

            if viewer_mode
                switch family
                    case 'gcamp'
                        valid_cells_prev = get_branch_plane_or_empty(data, 'gcamp_plane', 'valid_gcamp_cells_by_plane', m, p);
                    case 'blue'
                        valid_cells_prev = get_branch_plane_or_empty(data, 'blue_plane', 'valid_blue_cells_by_plane', m, p);
                    case 'combined'
                        valid_cells_prev = get_branch_plane_or_empty(data, 'combined_plane', 'valid_combined_cells_by_plane', m, p);
                    otherwise
                        valid_cells_prev = [];
                end

                if ~isempty(valid_cells_prev) && ...
                   all(valid_cells_prev >= 1) && ...
                   all(valid_cells_prev <= size(F_in,1))

                    F_view = F_in(valid_cells_prev, :);

                    if ~isempty(masks_in) && ndims(masks_in) >= 3 && size(masks_in,1) >= max(valid_cells_prev)
                        masks_in = masks_in(valid_cells_prev, :, :);
                    else
                        masks_in = [];
                    end

                    if strcmp(family, 'combined') && ~isempty(blue_indices_in)
                        map_old_to_new = nan(size(F_in,1),1);
                        map_old_to_new(valid_cells_prev) = 1:numel(valid_cells_prev);

                        blue_indices_in = blue_indices_in( ...
                            blue_indices_in >= 1 & blue_indices_in <= size(F_in,1));

                        blue_indices_in = map_old_to_new(blue_indices_in);
                        blue_indices_in = blue_indices_in(isfinite(blue_indices_in));
                        blue_indices_in = blue_indices_in(:);
                    end
                else
                    warning('Group %d plane %d: invalid previous valid_cells, fallback full signal.', m, p);
                    viewer_mode = false;
                    F_view = F_in;
                end
            else
                F_view = F_in;
            end

            if isempty(F_view)
                fprintf('Group %d plane %d: F_view empty.\n', m, p);
                continue;
            end

            [F0, noise_est, SNR, valid_cells, DF, Raster, ...
             Acttmp2, StartEnd, MAct, thresholds, bad_segs, ...
             opts_det, has_new] = ...
                peak_detection_tuner(F_view, ...
                    sampling_rate_group{m}, ...
                    synchronous_frames_group{m}, ...
                    'animal_group', current_animal_group, ...
                    'ages_group', current_ages_group{m}, ...
                    'viewer_mode', viewer_mode, ...
                    'cell_type', cell_type, ...
                    'ops', ops_in, ...
                    'iscell', iscell_in, ...
                    'stat', stat_in, ...
                    'masks', masks_in, ...
                    'blue_indices', blue_indices_in, ...
                    'meanImg', meanImg, ...
                    'gcamp_TSeries_path', tiff_path, ...
                    'speed', speed_m, ...
                    'meta_tbl', meta_tbl(m,:), ...
                    'gcamp_output_folder', gcamp_output_folders{m}{p});

            if ~has_new
                fprintf('Group %d plane %d: no new outputs for %s.\n', m, p, family);
                continue;
            end

            [isort1_plane, isort2_plane, Sm_plane] = ...
                compute_sort_outputs_from_df(DF, tiff_path, ops_in);

            switch family
                case 'gcamp'
                    has_new_gcamp_group = true;

                    data.gcamp_plane.F0_gcamp_by_plane{m}{p}             = F0;
                    data.gcamp_plane.noise_est_gcamp_by_plane{m}{p}      = noise_est;
                    data.gcamp_plane.valid_gcamp_cells_by_plane{m}{p}    = valid_cells;
                    data.gcamp_plane.DF_gcamp_by_plane{m}{p}             = DF;
                    data.gcamp_plane.Raster_gcamp_by_plane{m}{p}         = Raster;
                    data.gcamp_plane.Acttmp2_gcamp_by_plane{m}{p}        = Acttmp2;
                    data.gcamp_plane.StartEnd_gcamp_by_plane{m}{p}       = StartEnd;
                    data.gcamp_plane.MAct_gcamp_by_plane{m}{p}           = MAct;
                    data.gcamp_plane.thresholds_gcamp_by_plane{m}{p}     = thresholds;
                    data.gcamp_plane.bad_segs_gcamp_plane{m}{p}          = bad_segs;
                    data.gcamp_plane.opts_detection_gcamp_by_plane{m}{p} = opts_det;
                    data.gcamp_plane.isort1_gcamp_by_plane{m}{p}         = isort1_plane;
                    data.gcamp_plane.isort2_gcamp_by_plane{m}{p}         = isort2_plane;
                    data.gcamp_plane.Sm_gcamp_by_plane{m}{p}             = Sm_plane;

                case 'blue'
                    has_new_blue_group = true;

                    data.blue_plane.F0_blue_by_plane{m}{p}             = F0;
                    data.blue_plane.noise_est_blue_by_plane{m}{p}      = noise_est;
                    data.blue_plane.SNR_blue_by_plane{m}{p}            = SNR;
                    data.blue_plane.valid_blue_cells_by_plane{m}{p}    = valid_cells;
                    data.blue_plane.DF_blue_by_plane{m}{p}             = DF;
                    data.blue_plane.Raster_blue_by_plane{m}{p}         = Raster;
                    data.blue_plane.Acttmp2_blue_by_plane{m}{p}        = Acttmp2;
                    data.blue_plane.StartEnd_blue_by_plane{m}{p}       = StartEnd;
                    data.blue_plane.MAct_blue_by_plane{m}{p}           = MAct;
                    data.blue_plane.thresholds_blue_by_plane{m}{p}     = thresholds;
                    data.blue_plane.bad_segs_blue_plane{m}{p}          = bad_segs;
                    data.blue_plane.opts_detection_blue_by_plane{m}{p} = opts_det;
                    data.blue_plane.isort1_blue_by_plane{m}{p}         = isort1_plane;
                    data.blue_plane.isort2_blue_by_plane{m}{p}         = isort2_plane;
                    data.blue_plane.Sm_blue_by_plane{m}{p}             = Sm_plane;

                case 'combined'
                    has_new_combined_group = true;

                    data.combined_plane.F0_combined_by_plane{m}{p}             = F0;
                    data.combined_plane.noise_est_combined_by_plane{m}{p}      = noise_est;
                    data.combined_plane.valid_combined_cells_by_plane{m}{p}    = valid_cells;
                    data.combined_plane.DF_combined_by_plane{m}{p}             = DF;
                    data.combined_plane.Raster_combined_by_plane{m}{p}         = Raster;
                    data.combined_plane.Acttmp2_combined_by_plane{m}{p}        = Acttmp2;
                    data.combined_plane.StartEnd_combined_by_plane{m}{p}       = StartEnd;
                    data.combined_plane.MAct_combined_by_plane{m}{p}           = MAct;
                    data.combined_plane.thresholds_combined_by_plane{m}{p}     = thresholds;
                    data.combined_plane.bad_segs_combined_plane{m}{p}          = bad_segs;
                    data.combined_plane.opts_detection_combined_by_plane{m}{p} = opts_det;
                    data.combined_plane.isort1_combined_by_plane{m}{p}         = isort1_plane;
                    data.combined_plane.isort2_combined_by_plane{m}{p}         = isort2_plane;
                    data.combined_plane.Sm_combined_by_plane{m}{p}             = Sm_plane;

                    should_rebuild_gcamp = ...
                        ~has_existing_detection_new(data, 'gcamp_plane', 'DF_gcamp_by_plane', m, p) || ...
                        isempty(get_branch_plane_or_empty(data, 'gcamp_plane', 'valid_gcamp_cells_by_plane', m, p));

                    if should_rebuild_gcamp
                        [ok_gcamp, gcamp_from_combined] = ...
                            reconstruct_gcamp_from_combined_outputs( ...
                                valid_cells, F0, noise_est, DF, Raster, Acttmp2, StartEnd, ...
                                thresholds, bad_segs, opts_det, blue_indices_in, synchronous_frames_group{m});

                        if ok_gcamp
                            data.gcamp_plane.F0_gcamp_by_plane{m}{p}             = gcamp_from_combined.F0;
                            data.gcamp_plane.noise_est_gcamp_by_plane{m}{p}      = gcamp_from_combined.noise_est;
                            data.gcamp_plane.valid_gcamp_cells_by_plane{m}{p}    = gcamp_from_combined.valid_cells;
                            data.gcamp_plane.DF_gcamp_by_plane{m}{p}             = gcamp_from_combined.DF;
                            data.gcamp_plane.Raster_gcamp_by_plane{m}{p}         = gcamp_from_combined.Raster;
                            data.gcamp_plane.Acttmp2_gcamp_by_plane{m}{p}        = gcamp_from_combined.Acttmp2;
                            data.gcamp_plane.StartEnd_gcamp_by_plane{m}{p}       = gcamp_from_combined.StartEnd;
                            data.gcamp_plane.MAct_gcamp_by_plane{m}{p}           = gcamp_from_combined.MAct;
                            data.gcamp_plane.thresholds_gcamp_by_plane{m}{p}     = gcamp_from_combined.thresholds;
                            data.gcamp_plane.bad_segs_gcamp_plane{m}{p}          = gcamp_from_combined.bad_segs;
                            data.gcamp_plane.opts_detection_gcamp_by_plane{m}{p} = gcamp_from_combined.opts_det;

                            [isort1_tmp, isort2_tmp, Sm_tmp] = ...
                                compute_sort_outputs_from_df(gcamp_from_combined.DF, tiff_path, ops_in);

                            data.gcamp_plane.isort1_gcamp_by_plane{m}{p} = isort1_tmp;
                            data.gcamp_plane.isort2_gcamp_by_plane{m}{p} = isort2_tmp;
                            data.gcamp_plane.Sm_gcamp_by_plane{m}{p}     = Sm_tmp;

                            has_new_gcamp_group = true;
                            fprintf('Group %d plane %d: GCaMP detection rebuilt from combined outputs.\n', m, p);
                        end
                    end

                    should_rebuild_blue = ...
                        ~has_existing_detection_new(data, 'blue_plane', 'DF_blue_by_plane', m, p) || ...
                        isempty(get_branch_plane_or_empty(data, 'blue_plane', 'valid_blue_cells_by_plane', m, p));

                    if should_rebuild_blue
                        [ok_blue, blue_from_combined] = ...
                            reconstruct_blue_from_combined_outputs( ...
                                valid_cells, F0, noise_est, SNR, DF, Raster, Acttmp2, StartEnd, ...
                                thresholds, bad_segs, opts_det, blue_indices_in, synchronous_frames_group{m});

                        if ok_blue
                            data.blue_plane.F0_blue_by_plane{m}{p}             = blue_from_combined.F0;
                            data.blue_plane.noise_est_blue_by_plane{m}{p}      = blue_from_combined.noise_est;
                            data.blue_plane.SNR_blue_by_plane{m}{p}            = blue_from_combined.SNR;
                            data.blue_plane.valid_blue_cells_by_plane{m}{p}    = blue_from_combined.valid_cells;
                            data.blue_plane.DF_blue_by_plane{m}{p}             = blue_from_combined.DF;
                            data.blue_plane.Raster_blue_by_plane{m}{p}         = blue_from_combined.Raster;
                            data.blue_plane.Acttmp2_blue_by_plane{m}{p}        = blue_from_combined.Acttmp2;
                            data.blue_plane.StartEnd_blue_by_plane{m}{p}       = blue_from_combined.StartEnd;
                            data.blue_plane.MAct_blue_by_plane{m}{p}           = blue_from_combined.MAct;
                            data.blue_plane.thresholds_blue_by_plane{m}{p}     = blue_from_combined.thresholds;
                            data.blue_plane.bad_segs_blue_plane{m}{p}          = blue_from_combined.bad_segs;
                            data.blue_plane.opts_detection_blue_by_plane{m}{p} = blue_from_combined.opts_det;

                            [isort1_tmp, isort2_tmp, Sm_tmp] = ...
                                compute_sort_outputs_from_df(blue_from_combined.DF, tiff_path, ops_in);

                            data.blue_plane.isort1_blue_by_plane{m}{p} = isort1_tmp;
                            data.blue_plane.isort2_blue_by_plane{m}{p} = isort2_tmp;
                            data.blue_plane.Sm_blue_by_plane{m}{p}     = Sm_tmp;

                            has_new_blue_group = true;
                            fprintf('Group %d plane %d: BLUE detection rebuilt from combined outputs.\n', m, p);
                        end
                    end
            end
        end

        if has_new_gcamp_group
            save_branch_fields(filePath_gcamp, data, 'gcamp_plane', fields_detect_gcamp, m);
            fprintf('Group %d: gcamp detection fields updated in %s.\n', m, filePath_gcamp);
        end

        if has_new_blue_group
            save_branch_fields(filePath_blue, data, 'blue_plane', fields_detect_blue, m);
            fprintf('Group %d: blue detection fields updated in %s.\n', m, filePath_blue);
        end

        if has_new_combined_group
            save_branch_fields(filePath_combined, data, 'combined_plane', fields_detect_combined, m);
            fprintf('Group %d: combined detection fields updated in %s.\n', m, filePath_combined);
        end

        if ~has_new_gcamp_group && ~has_new_blue_group && ~has_new_combined_group
            fprintf('Group %d: no new detection data.\n', m);
        end
    end
end

% =========================================================
% ==================== UTILITAIRES ========================
% =========================================================

function data = init_detection_branch_if_needed(data, branchName, numFolders, fields)
    if ~isfield(data, branchName) || ~isstruct(data.(branchName)) || isempty(data.(branchName))
        data.(branchName) = struct();
    end

    for f = 1:numel(fields)
        fieldName = fields{f};
        if ~isfield(data.(branchName), fieldName) || ~iscell(data.(branchName).(fieldName))
            tmp = cell(numFolders,1);
            [tmp{:}] = deal([]);
            data.(branchName).(fieldName) = tmp;
        elseif numel(data.(branchName).(fieldName)) < numFolders
            old = data.(branchName).(fieldName);
            tmp = cell(numFolders,1);
            tmp(1:numel(old)) = old(:);
            data.(branchName).(fieldName) = tmp;
        end
    end
end

function data = ensure_branch_plane_cell(data, branchName, fieldName, m, nPlanes)
    if ~isfield(data.(branchName), fieldName)
        data.(branchName).(fieldName) = cell(m,1);
    end
    if numel(data.(branchName).(fieldName)) < m
        tmp = cell(m,1);
        tmp(1:numel(data.(branchName).(fieldName))) = data.(branchName).(fieldName)(:);
        data.(branchName).(fieldName) = tmp;
    end
    if isempty(data.(branchName).(fieldName){m}) || ~iscell(data.(branchName).(fieldName){m})
        data.(branchName).(fieldName){m} = cell(nPlanes,1);
    elseif numel(data.(branchName).(fieldName){m}) ~= nPlanes
        old = data.(branchName).(fieldName){m};
        new = cell(nPlanes,1);
        n = min(numel(old), nPlanes);
        new(1:n) = old(1:n);
        data.(branchName).(fieldName){m} = new;
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

function nPlanes = infer_nplanes_for_group_new(data, m)
    nPlanes = 0;

    candidates = { ...
        {'gcamp_plane','F_gcamp_by_plane'}, ...
        {'blue_plane','F_blue_by_plane'}, ...
        {'combined_plane','F_combined_by_plane'}, ...
        {'gcamp_plane','gcamp_mask_by_plane'}, ...
        {'blue_plane','mask_cellpose_by_plane'}, ...
        {'combined_plane','mask_combined_by_plane'} ...
    };

    for i = 1:numel(candidates)
        br = candidates{i}{1};
        fn = candidates{i}{2};
        if isfield(data, br) && isfield(data.(br), fn) && ...
           numel(data.(br).(fn)) >= m && ~isempty(data.(br).(fn){m})
            nPlanes = max(nPlanes, numel(data.(br).(fn){m}));
        end
    end
end

function v = get_branch_plane_or_empty(data, branchName, fieldName, m, p)
    v = [];
    if isfield(data, branchName) && isfield(data.(branchName), fieldName) && ...
       numel(data.(branchName).(fieldName)) >= m && ...
       ~isempty(data.(branchName).(fieldName){m}) && iscell(data.(branchName).(fieldName){m}) && ...
       numel(data.(branchName).(fieldName){m}) >= p
        v = data.(branchName).(fieldName){m}{p};
    end
end

function tf = has_existing_detection_new(data, branchName, fieldName, m, p)
    tf = false;
    if isfield(data, branchName) && isfield(data.(branchName), fieldName) && ...
       numel(data.(branchName).(fieldName)) >= m && ...
       ~isempty(data.(branchName).(fieldName){m}) && iscell(data.(branchName).(fieldName){m}) && ...
       numel(data.(branchName).(fieldName){m}) >= p && ...
       ~isempty(data.(branchName).(fieldName){m}{p})
        tf = true;
    end
end

function data = merge_loaded_branch_into_data(data, branchName, loaded, fieldsToLoad, m, nPlanes)
    for k = 1:numel(fieldsToLoad)
        fn = fieldsToLoad{k};
        if ~isfield(loaded, fn)
            continue;
        end

        loadedField = coerce_to_plane_cell(loaded.(fn), nPlanes);
        data = ensure_branch_plane_cell(data, branchName, fn, m, nPlanes);

        for p = 1:nPlanes
            if numel(loadedField) >= p
                if isempty(data.(branchName).(fn){m}{p})
                    data.(branchName).(fn){m}{p} = loadedField{p};
                end
            end
        end
    end
end

function save_branch_fields(filePath, data, branchName, saveFields, m)
    saveStruct = struct();
    for k = 1:numel(saveFields)
        fieldName = saveFields{k};
        if isfield(data, branchName) && isfield(data.(branchName), fieldName) && ...
           numel(data.(branchName).(fieldName)) >= m
            saveStruct.(fieldName) = data.(branchName).(fieldName){m};
        end
    end

    outdir = fileparts(filePath);
    if ~exist(outdir, 'dir')
        mkdir(outdir);
    end

    if exist(filePath, 'file') == 2
        save(filePath, '-struct', 'saveStruct', '-append');
    else
        save(filePath, '-struct', 'saveStruct');
    end
end

function [choice, state] = choose_signal_mode_for_plane_groupwise( ...
    has_gcamp, has_blue, has_combined, m, p, state)

    choice = '';

    nAvail = double(has_gcamp) + double(has_blue) + double(has_combined);

    if nAvail == 0
        return;
    elseif nAvail == 1
        if has_gcamp
            choice = 'gcamp';
        elseif has_blue
            choice = 'blue';
        else
            choice = 'combined';
        end
        return;
    end

    if state.initialized && ~state.ask_each_plane && ~isempty(state.mode)
        choice = state.mode;
        return;
    end

    if state.initialized && state.ask_each_plane
        choice = choose_signal_mode_single_plane(has_gcamp, has_blue, has_combined, m, p);
        return;
    end

    default_button = default_signal_button(has_gcamp, has_blue, has_combined);

    answer = questdlg( ...
        sprintf(['Group %d - plane %d\nChoose signal to analyze.\n' ...
                 'This choice can be applied to all ambiguous planes of the group.'], m, p), ...
        'Select signal for group', ...
        'gcamp only', 'blue only', 'both / combined', ...
        default_button);

    switch answer
        case 'gcamp only'
            state.mode = 'gcamp';
            state.ask_each_plane = false;
            state.initialized = true;
            choice = 'gcamp';

        case 'blue only'
            state.mode = 'blue';
            state.ask_each_plane = false;
            state.initialized = true;
            choice = 'blue';

        case 'both / combined'
            state.mode = 'combined';
            state.ask_each_plane = false;
            state.initialized = true;
            choice = 'combined';

        otherwise
            answer2 = questdlg( ...
                sprintf('Group %d\nDo you want to choose signal mode plane by plane?', m), ...
                'Apply mode', ...
                'ask each plane', 'cancel', 'ask each plane');

            switch answer2
                case 'ask each plane'
                    state.mode = '';
                    state.ask_each_plane = true;
                    state.initialized = true;
                    choice = choose_signal_mode_single_plane(has_gcamp, has_blue, has_combined, m, p);
                otherwise
                    choice = '';
            end
    end
end

function choice = choose_signal_mode_single_plane(has_gcamp, has_blue, has_combined, m, p)
    choice = '';

    default_button = default_signal_button(has_gcamp, has_blue, has_combined);

    answer = questdlg( ...
        sprintf('Group %d - plane %d\nChoose signal to analyze:', m, p), ...
        'Select signal', ...
        'gcamp only', 'blue only', 'both / combined', ...
        default_button);

    switch answer
        case 'gcamp only'
            choice = 'gcamp';
        case 'blue only'
            choice = 'blue';
        case 'both / combined'
            choice = 'combined';
        otherwise
            choice = '';
    end
end

function btn = default_signal_button(has_gcamp, has_blue, has_combined)
    if has_combined
        btn = 'both / combined';
    elseif has_gcamp
        btn = 'gcamp only';
    elseif has_blue
        btn = 'blue only';
    else
        btn = 'gcamp only';
    end
end

function [ok, out] = reconstruct_gcamp_from_combined_outputs( ...
    valid_combined, F0_combined, noise_est_combined, DF_combined, Raster_combined, ...
    Acttmp2_combined, StartEnd_combined, thresholds_combined, bad_segs_combined, ...
    opts_det_combined, blue_indices_combined, synchronous_frames)

    ok = false;
    out = struct( ...
        'F0', [], 'noise_est', [], 'valid_cells', [], 'DF', [], 'Raster', [], ...
        'Acttmp2', {{}}, 'StartEnd', {{}}, 'MAct', [], 'thresholds', [], ...
        'bad_segs', [], 'opts_det', []);

    if isempty(valid_combined)
        return;
    end

    valid_combined = valid_combined(:);
    blue_indices_combined = blue_indices_combined(:);

    is_gcamp_valid = ~ismember(valid_combined, blue_indices_combined);
    if ~any(is_gcamp_valid)
        return;
    end

    valid_gcamp = valid_combined(is_gcamp_valid);
    row_keep = find(is_gcamp_valid);

    out.valid_cells = valid_gcamp(:);
    out.F0         = safe_take_rows(F0_combined, row_keep);
    out.noise_est  = safe_take_rows(noise_est_combined, row_keep);
    out.DF         = safe_take_rows(DF_combined, row_keep);
    out.Raster     = safe_take_rows(Raster_combined, row_keep);
    out.Acttmp2    = safe_take_cells(Acttmp2_combined, row_keep);
    out.StartEnd   = safe_take_cells(StartEnd_combined, row_keep);
    out.thresholds = safe_take_rows(thresholds_combined, row_keep);
    out.bad_segs   = bad_segs_combined;
    out.opts_det   = opts_det_combined;
    out.MAct       = recompute_mact_from_raster(out.Raster, synchronous_frames);

    ok = true;
end

function [ok, out] = reconstruct_blue_from_combined_outputs( ...
    valid_combined, F0_combined, noise_est_combined, SNR_combined, DF_combined, Raster_combined, ...
    Acttmp2_combined, StartEnd_combined, thresholds_combined, bad_segs_combined, ...
    opts_det_combined, blue_indices_combined, synchronous_frames)

    ok = false;
    out = struct( ...
        'F0', [], 'noise_est', [], 'SNR', [], ...
        'valid_cells', [], ...
        'valid_cells_combined', [], ...
        'DF', [], 'Raster', [], ...
        'Acttmp2', {{}}, 'StartEnd', {{}}, 'MAct', [], ...
        'thresholds', [], 'bad_segs', [], 'opts_det', []);

    if isempty(valid_combined) || isempty(blue_indices_combined)
        return;
    end

    valid_combined = valid_combined(:);
    blue_indices_combined = blue_indices_combined(:);

    is_blue_valid = ismember(valid_combined, blue_indices_combined);
    if ~any(is_blue_valid)
        return;
    end

    valid_blue_combined = valid_combined(is_blue_valid);
    row_keep = find(is_blue_valid);

    [tf_map, loc_blue] = ismember(valid_blue_combined, blue_indices_combined);
    valid_blue_local = loc_blue(tf_map);

    out.valid_cells = valid_blue_local(:);
    out.valid_cells_combined = valid_blue_combined(:);
    out.F0         = safe_take_rows(F0_combined, row_keep);
    out.noise_est  = safe_take_rows(noise_est_combined, row_keep);

    if ~isempty(SNR_combined)
        out.SNR = safe_take_rows(SNR_combined, row_keep);
    else
        out.SNR = [];
    end

    out.DF         = safe_take_rows(DF_combined, row_keep);
    out.Raster     = safe_take_rows(Raster_combined, row_keep);
    out.Acttmp2    = safe_take_cells(Acttmp2_combined, row_keep);
    out.StartEnd   = safe_take_cells(StartEnd_combined, row_keep);
    out.thresholds = safe_take_rows(thresholds_combined, row_keep);
    out.bad_segs   = bad_segs_combined;
    out.opts_det   = opts_det_combined;
    out.MAct       = recompute_mact_from_raster(out.Raster, synchronous_frames);

    ok = true;
end

function MAct = recompute_mact_from_raster(Raster, synchronous_frames)
    if isempty(Raster)
        MAct = zeros(1,0);
        return;
    end

    Nz = size(Raster, 2);
    if Nz > synchronous_frames
        MAct = zeros(1, Nz - synchronous_frames);
        for i = 1:(Nz - synchronous_frames)
            MAct(i) = sum(max(Raster(:, i:i+synchronous_frames), [], 2));
        end
    else
        MAct = zeros(1,0);
    end
end

function out = safe_take_rows(x, idx)
    if isempty(x)
        out = x;
        return;
    end
    if isvector(x)
        out = x(idx);
    else
        out = x(idx, :);
    end
end

function out = safe_take_cells(x, idx)
    if isempty(x)
        out = {};
        return;
    end
    if ~iscell(x)
        out = {};
        return;
    end
    out = x(idx);
end

function [isort1_out, isort2_out, Sm_out] = compute_sort_outputs_from_df(DF_in, fall_path, ops_in)
    isort1_out = [];
    isort2_out = [];
    Sm_out     = [];

    if isempty(DF_in)
        return;
    end

    try
        [isort1_out, isort2_out, Sm_out] = ...
            raster_processing(double(DF_in), fall_path, ops_in);
    catch ME
        warning('compute_sort_outputs_from_df:raster_processing', ...
            'raster_processing failed (%s).', ME.message);
        isort1_out = [];
        isort2_out = [];
        Sm_out     = [];
    end
end