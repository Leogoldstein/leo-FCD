function data = run_gcamp_peak_detection( ...
    gcamp_output_folders, ...
    metadata, ...
    sampling_rate_group, synchronous_frames_group, ...
    data, meanImgs_gcamp, ...
    current_gcamp_TSeries_path, ...
    current_animal_group, ...
    include_blue_cells)

    numFolders = numel(gcamp_output_folders);

    if nargin < 9 || isempty(include_blue_cells)
        include_blue_cells = '1';
    end

    include_blue_cells = char(string(include_blue_cells));

    % Selon la logique demandée :
    % include_blue_cells == '1' -> GCaMP uniquement
    % include_blue_cells ~= '1' -> blue/combined autorisés
    process_blue_combined = ~strcmp(include_blue_cells, '1');

    fields_detect_gcamp = { ...
        'F0_gcamp_by_plane', 'noise_est_gcamp_by_plane', ...
        'DF_gcamp_by_plane', 'DF_raw_gcamp_by_plane', ...
        'valid_gcamp_cells_by_plane', ...
        'Raster_gcamp_by_plane', 'Acttmp2_gcamp_by_plane', ...
        'MAct_gcamp_by_plane', ...
        'thresholds_gcamp_by_plane', 'bad_segs_gcamp_plane', ...
        'opts_detection_gcamp_by_plane', ...
        'isort1_gcamp_by_plane', 'isort2_gcamp_by_plane', 'Sm_gcamp_by_plane' ...
    };

    fields_detect_blue = { ...
        'F0_blue_by_plane', 'noise_est_blue_by_plane', ...
        'DF_blue_by_plane', 'DF_raw_blue_by_plane', ...
        'valid_blue_cells_by_plane', ...
        'Raster_blue_by_plane', 'Acttmp2_blue_by_plane', ...
        'MAct_blue_by_plane', ...
        'thresholds_blue_by_plane', 'bad_segs_blue_plane', ...
        'opts_detection_blue_by_plane', ...
        'isort1_blue_by_plane', 'isort2_blue_by_plane', 'Sm_blue_by_plane' ...
    };

    fields_detect_combined = { ...
        'F0_combined_by_plane', 'noise_est_combined_by_plane', ...
        'DF_combined_by_plane', 'DF_raw_combined_by_plane', ...
        'valid_combined_cells_by_plane', ...
        'Raster_combined_by_plane', 'Acttmp2_combined_by_plane', ...
        'MAct_combined_by_plane', ...
        'thresholds_combined_by_plane', 'bad_segs_combined_plane', ...
        'opts_detection_combined_by_plane', ...
        'isort1_combined_by_plane', 'isort2_combined_by_plane', 'Sm_combined_by_plane' ...
    };

    fields_motion_group = { ...
        'speed_active_group', ...
        'bad_frames_group', ...
        'bad_segs_group', ...
        'deviation_group', ...
        'focus_segs_group', ...
        'motion_energy_group' ...
    };

    % ------------------------------------------------------
    % Initialisation minimale
    % ------------------------------------------------------
    data = init_detection_branch_if_needed( ...
        data, 'gcamp_plane', numFolders, fields_detect_gcamp);

    if process_blue_combined
        data = init_detection_branch_if_needed( ...
            data, 'blue_plane', numFolders, fields_detect_blue);

        data = init_detection_branch_if_needed( ...
            data, 'combined_plane', numFolders, fields_detect_combined);
    end

    data = init_motion_group_if_needed(data, numFolders, fields_motion_group);

    processing_mode = ask_processing_mode();  

    global_existing_detection_action = '';
    global_existing_detection_action_initialized = false;
    global_choice_state = struct();
    global_choice_state.mode = '';
    global_choice_state.initialized = false;
    global_choice_state.ask_each_plane = false;

    for m = 1:numFolders

        has_new_gcamp_group    = false;
        has_new_blue_group     = false;
        has_new_combined_group = false;
        has_new_motion_group   = false;

        sampling_rate_m = sampling_rate_group{m};
        sync_frames_m   = synchronous_frames_group{m};
        metadata_m      = get_metadata_for_record(metadata, m);
        record_label_m  = make_record_label(current_animal_group, metadata_m, m);

        if ~isfield(metadata_m,'NumPlanes') || isempty(metadata_m.NumPlanes)
            error('Metadata missing NumPlanes for group %d.', m);
        end

        nPlanes = max(1, round(double(metadata_m.NumPlanes)));

        for f = 1:numel(fields_detect_gcamp)
            data = ensure_branch_plane_cell( ...
                data, 'gcamp_plane', fields_detect_gcamp{f}, m, nPlanes);
        end

        if process_blue_combined

            for f = 1:numel(fields_detect_blue)
                data = ensure_branch_plane_cell( ...
                    data, 'blue_plane', fields_detect_blue{f}, m, nPlanes);
            end

            for f = 1:numel(fields_detect_combined)
                data = ensure_branch_plane_cell( ...
                    data, 'combined_plane', fields_detect_combined{f}, m, nPlanes);
            end
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

        stim_frames_m = [];

        if isfield(data, 'stim') && ...
           isfield(data.stim, 'stim_frames_log_group') && ...
           isfield(data.stim, 'stim_protocol_group') && ...
           numel(data.stim.stim_frames_log_group) >= m && ...
           numel(data.stim.stim_protocol_group) >= m

            stim_frames_tmp   = data.stim.stim_frames_log_group{m};
            stim_protocol_tmp = data.stim.stim_protocol_group{m};

            if ~isempty(stim_frames_tmp) && ~isempty(stim_protocol_tmp)

                stim_frames_tmp   = stim_frames_tmp(:);
                stim_protocol_tmp = stim_protocol_tmp(:);

                n = min(numel(stim_frames_tmp), numel(stim_protocol_tmp));

                stim_frames_tmp   = stim_frames_tmp(1:n);
                stim_protocol_tmp = stim_protocol_tmp(1:n);

                stim_frames_m = stim_frames_tmp(stim_protocol_tmp == 0);
            end
        end

        outdir_m = fileparts(gcamp_output_folders{m}{1});

        filePath_gcamp    = fullfile(outdir_m, 'results_gcamp.mat');
        filePath_blue     = fullfile(outdir_m, 'results_blue.mat');
        filePath_combined = fullfile(outdir_m, 'results_combined.mat');
        filePath_motion   = fullfile(outdir_m, 'results_motion.mat');

        oldMotionPath = fullfile(outdir_m, 'results_movie.mat');

        if exist(oldMotionPath, 'file') == 2 && exist(filePath_motion, 'file') ~= 2
            movefile(oldMotionPath, filePath_motion);
            fprintf('%s: renamed results_movie.mat -> results_motion.mat\n', record_label_m);
        end

        % ------------------------------------------------------
        % Chargement des résultats déjà existants seulement si nécessaire
        % ------------------------------------------------------
        
        missing_gcamp = branch_has_missing_fields( ...
            data, 'gcamp_plane', fields_detect_gcamp, m, nPlanes);
        
        if missing_gcamp
            if exist(filePath_gcamp, 'file') == 2
                fprintf('%s : chargement de results_gcamp.mat (mémoire incomplète).\n', record_label_m);
        
                loaded_gcamp = load(filePath_gcamp);
                data = merge_loaded_branch_into_data( ...
                    data, 'gcamp_plane', loaded_gcamp, fields_detect_gcamp, m, nPlanes);
            else
                fprintf('%s : results_gcamp.mat absent.\n', record_label_m);
            end
        else
            fprintf('%s : données GCaMP déjà complètes en mémoire, pas de reload.\n', record_label_m);
        end
        
        
        if process_blue_combined
        
            missing_blue = branch_has_missing_fields( ...
                data, 'blue_plane', fields_detect_blue, m, nPlanes);
        
            if missing_blue
                if exist(filePath_blue, 'file') == 2
                    fprintf('%s : chargement de results_blue.mat (mémoire incomplète).\n', record_label_m);
        
                    loaded_blue = load(filePath_blue);
                    data = merge_loaded_branch_into_data( ...
                        data, 'blue_plane', loaded_blue, fields_detect_blue, m, nPlanes);
                else
                    fprintf('%s : results_blue.mat absent.\n', record_label_m);
                end
            else
                fprintf('%s : données blue déjà complètes en mémoire, pas de reload.\n', record_label_m);
            end
        
        
            missing_combined = branch_has_missing_fields( ...
                data, 'combined_plane', fields_detect_combined, m, nPlanes);
        
            if missing_combined
                if exist(filePath_combined, 'file') == 2
                    fprintf('%s : chargement de results_combined.mat (mémoire incomplète).\n', record_label_m);
        
                    loaded_combined = load(filePath_combined);
                    data = merge_loaded_branch_into_data( ...
                        data, 'combined_plane', loaded_combined, fields_detect_combined, m, nPlanes);
                else
                    fprintf('%s : results_combined.mat absent.\n', record_label_m);
                end
            else
                fprintf('%s : données combined déjà complètes en mémoire, pas de reload.\n', record_label_m);
            end
        end
        
        
        missing_motion = motion_group_has_missing_fields( ...
            data, fields_motion_group, m);
        
        if missing_motion
            if exist(filePath_motion, 'file') == 2
                fprintf('%s : chargement de results_motion.mat (mémoire incomplète).\n', record_label_m);
        
                loaded_motion = load(filePath_motion);
                data = merge_loaded_motion_group_into_data( ...
                    data, loaded_motion, fields_motion_group, m);
            else
                fprintf('%s : results_motion.mat absent.\n', record_label_m);
            end
        else
            fprintf('%s : données motion déjà complètes en mémoire, pas de reload.\n', record_label_m);
        end

        speed_active_group  = get_motion_group_or_empty(data, 'speed_active_group', m);
        bad_frames_group    = get_motion_group_or_empty(data, 'bad_frames_group', m);
        bad_segs_group      = get_motion_group_or_empty(data, 'bad_segs_group', m);
        deviation_group     = get_motion_group_or_empty(data, 'deviation_group', m);
        focus_segs_group    = get_motion_group_or_empty(data, 'focus_segs_group', m);
        motion_energy_group = get_motion_group_or_empty(data, 'motion_energy_group', m);

        ops_motion_ref = [];

        for pp = 1:nPlanes

            ops_motion_ref = get_branch_plane_or_empty( ...
                data, 'gcamp_plane', 'ops_suite2p_by_plane', m, pp);

            if process_blue_combined && isempty(ops_motion_ref)
                ops_motion_ref = get_branch_plane_or_empty( ...
                    data, 'blue_plane', 'ops_suite2p_blue_by_plane', m, pp);
            end

            if ~isempty(ops_motion_ref)
                break;
            end
        end

        motion_group_incomplete = ...
            isempty(bad_frames_group) || ...
            isempty(bad_segs_group) || ...
            isempty(deviation_group) || ...
            isempty(focus_segs_group) || ...
            isempty(motion_energy_group);

        if motion_group_incomplete

            if ~isempty(ops_motion_ref) && ...
               isfield(ops_motion_ref, 'corrXY') && ...
               ~isempty(ops_motion_ref.corrXY) && ...
               ~isempty(speed_active_group)

                corrXY = ops_motion_ref.corrXY(:);
                speed  = speed_active_group(:);

                N = min(numel(corrXY), numel(speed));

                corrXY = corrXY(1:N);
                speed  = speed(1:N);

                rolling_median = movmedian(corrXY, 300);
                deviation_group = corrXY - rolling_median;

                sigma_dev = std(deviation_group(deviation_group < 0), 'omitnan');
                seuil_bad = -3 * sigma_dev;

                bad_frames_logical = deviation_group < seuil_bad;
                bad_frames_logical = conv(double(bad_frames_logical), [1 1 1], 'same') > 0;

                bad_frames_group = find(bad_frames_logical);
                bad_frames_group = bad_frames_group(:).';

                bad_frames_no_movement   = bad_frames_logical & (speed < 1);
                bad_frames_with_movement = bad_frames_logical & (speed >= 1);

                bad_segs_group   = badframes_to_segments(bad_frames_group, N);
                focus_segs_group = bad_segs_group;

                deviation_group = deviation_group(:).';

                fprintf('Bad frames total : %d (%.2f%%)\n', ...
                    numel(bad_frames_group), 100*numel(bad_frames_group)/N);

                fprintf('Bad frames SANS mouvement (speed < 1) : %d (%.2f%%)\n', ...
                    sum(bad_frames_no_movement), 100*sum(bad_frames_no_movement)/N);

                fprintf('Bad frames AVEC mouvement (speed >= 1) : %d (%.2f%%)\n', ...
                    sum(bad_frames_with_movement), 100*sum(bad_frames_with_movement)/N);

                data.motion.bad_frames_group{m}    = bad_frames_group;
                data.motion.bad_segs_group{m}      = bad_segs_group;
                data.motion.deviation_group{m}     = deviation_group;
                data.motion.focus_segs_group{m}    = focus_segs_group;
                data.motion.motion_energy_group{m} = motion_energy_group;

                has_new_motion_group = true;

            else
                warning('%s: impossible de calculer motion group : corrXY ou speed_active_group manquant.', record_label_m);
            end
        end

        if strcmp(processing_mode, 'case_by_case')
            group_choice_state = struct();
            group_choice_state.mode = '';
            group_choice_state.initialized = false;
            group_choice_state.ask_each_plane = true;
        else
            group_choice_state = global_choice_state;
        end

        for p = 1:nPlanes

            Fg = get_branch_plane_or_empty( ...
                data, 'gcamp_plane', 'F_gcamp_by_plane', m, p);

            if process_blue_combined
                Fb = get_branch_plane_or_empty( ...
                    data, 'blue_plane', 'F_blue_by_plane', m, p);

                Fc = get_branch_plane_or_empty( ...
                    data, 'combined_plane', 'F_combined_by_plane', m, p);

                has_blue     = ~isempty(Fb);
                has_combined = ~isempty(Fc);
            else
                Fb = [];
                Fc = [];
                has_blue     = false;
                has_combined = false;
            end

            has_gcamp = ~isempty(Fg);

            viewer_mode_requested_plane = false;
            skip_plane = false;

            has_detection_plane = has_existing_detection_new( ...
                data, 'gcamp_plane', 'DF_gcamp_by_plane', m, p);

            if process_blue_combined
                has_detection_plane = has_detection_plane || ...
                    has_existing_detection_new(data, 'blue_plane', 'DF_blue_by_plane', m, p) || ...
                    has_existing_detection_new(data, 'combined_plane', 'DF_combined_by_plane', m, p);
            end

            if has_detection_plane

                if strcmp(processing_mode, 'global')
            
                    if ~global_existing_detection_action_initialized
            
                        global_existing_detection_action = ask_existing_detection_action_global( ...
                            record_label_m);
            
                        global_existing_detection_action_initialized = true;
                    end
            
                    switch global_existing_detection_action
            
                        case 'viewer'
                            viewer_mode_requested_plane = true;
                            skip_plane = false;
            
                        otherwise
                            viewer_mode_requested_plane = false;
                            skip_plane = true;
                    end
            
                else
            
                    [viewer_mode_requested_plane, skip_plane] = ...
                        ask_viewer(true, record_label_m, p, 'plane');
                end

                if skip_plane
                    fprintf('%s - plane %d: existing detection loaded only.\n', record_label_m, p);
                    continue;
                end
            end

            if ~has_gcamp && ~has_blue && ~has_combined
                fprintf('%s - plane %d: no signal data available.\n', record_label_m, p);
                continue;
            end

             if process_blue_combined
        
                [choice, group_choice_state] = ...
                    choose_signal_mode_for_plane_groupwise( ...
                        has_gcamp, has_blue, has_combined, ...
                        record_label_m, p, group_choice_state);
            
                if strcmp(processing_mode, 'global')
                    global_choice_state = group_choice_state;
                end
            
                if isempty(choice)
                    fprintf('%s - plane %d: user cancelled signal mode selection.\n', record_label_m, p);
                    continue;
                end
            
            else
                choice = 'gcamp';
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

            if strcmp(choice, 'combined') && ~has_combined
                fprintf('%s - plane %d: combined unavailable, skipping.\n', record_label_m, p);
                continue;
            elseif strcmp(choice, 'gcamp') && ~has_gcamp
                fprintf('%s - plane %d: gcamp unavailable, skipping.\n', record_label_m, p);
                continue;
            elseif strcmp(choice, 'blue') && ~has_blue
                fprintf('%s - plane %d: blue unavailable, skipping.\n', record_label_m, p);
                continue;
            end

            blue_indices_in = [];
            masks_in = [];

            switch choice

                case 'gcamp'

                    family      = 'gcamp';
                    cell_type   = 'gcamp';
                    F_in        = Fg;
                    stat_in     = get_branch_plane_or_empty(data, 'gcamp_plane', 'stat_by_plane', m, p);
                    iscell_idx  = get_branch_plane_or_empty(data, 'gcamp_plane', 'iscell_idx_gcamp_by_plane', m, p);
                    ops_in      = get_branch_plane_or_empty(data, 'gcamp_plane', 'ops_suite2p_by_plane', m, p);
                    masks_in    = get_branch_plane_or_empty(data, 'gcamp_plane', 'gcamp_mask_by_plane', m, p);

                    viewer_mode = viewer_mode_requested_plane && ...
                        has_existing_detection_new(data, 'gcamp_plane', 'DF_gcamp_by_plane', m, p);

                case 'blue'

                    family      = 'blue';
                    cell_type   = 'electroporated';
                    F_in        = Fb;
                    stat_in     = [];
                    iscell_idx  = [];
                    ops_in      = get_branch_plane_or_empty(data, 'blue_plane', 'ops_suite2p_blue_by_plane', m, p);
                    masks_in    = get_branch_plane_or_empty(data, 'blue_plane', 'mask_cellpose_by_plane', m, p);

                    viewer_mode = viewer_mode_requested_plane && ...
                        has_existing_detection_new(data, 'blue_plane', 'DF_blue_by_plane', m, p);

                case 'combined'

                    family      = 'combined';
                    cell_type   = 'combined';
                    F_in        = Fc;
                    stat_in     = [];
                    iscell_idx  = get_branch_plane_or_empty(data, 'gcamp_plane', 'iscell_idx_gcamp_by_plane', m, p);
                    ops_in      = get_branch_plane_or_empty(data, 'gcamp_plane', 'ops_suite2p_by_plane', m, p);
                    masks_in    = get_branch_plane_or_empty(data, 'combined_plane', 'mask_combined_by_plane', m, p);
                    blue_idx    = get_branch_plane_or_empty(data, 'combined_plane', 'blue_indices_combined_by_plane', m, p);

                    viewer_mode = viewer_mode_requested_plane && ...
                        has_existing_detection_new(data, 'combined_plane', 'DF_combined_by_plane', m, p);

                    if ~isempty(blue_idx)
                        blue_indices_in = blue_idx(:);
                    end
            end

            if isempty(F_in)
                fprintf('%s - plane %d: selected signal is empty.\n', record_label_m, p);
                continue;
            end

            Acttmp2_saved      = [];
            Raster_saved       = [];
            thresholds_saved   = [];
            valid_cells_saved  = [];
            DF_sg_saved        = [];
            DF_raw_saved       = [];
            F0_saved           = [];
            noise_est_saved    = [];

            bad_frames    = bad_frames_group;
            bad_segs      = bad_segs_group;
            deviation     = deviation_group;
            focus_segs    = focus_segs_group;
            motion_energy = motion_energy_group;

            if viewer_mode

                switch family

                    case 'gcamp'

                        valid_cells_saved = get_branch_plane_or_empty(data, 'gcamp_plane', 'valid_gcamp_cells_by_plane', m, p);
                        Acttmp2_saved     = get_branch_plane_or_empty(data, 'gcamp_plane', 'Acttmp2_gcamp_by_plane', m, p);
                        Raster_saved      = get_branch_plane_or_empty(data, 'gcamp_plane', 'Raster_gcamp_by_plane', m, p);
                        thresholds_saved  = get_branch_plane_or_empty(data, 'gcamp_plane', 'thresholds_gcamp_by_plane', m, p);
                        DF_sg_saved       = get_branch_plane_or_empty(data, 'gcamp_plane', 'DF_gcamp_by_plane', m, p);
                        DF_raw_saved      = get_branch_plane_or_empty(data, 'gcamp_plane', 'DF_raw_gcamp_by_plane', m, p);
                        F0_saved          = get_branch_plane_or_empty(data, 'gcamp_plane', 'F0_gcamp_by_plane', m, p);
                        noise_est_saved   = get_branch_plane_or_empty(data, 'gcamp_plane', 'noise_est_gcamp_by_plane', m, p);

                    case 'blue'

                        valid_cells_saved = get_branch_plane_or_empty(data, 'blue_plane', 'valid_blue_cells_by_plane', m, p);
                        Acttmp2_saved     = get_branch_plane_or_empty(data, 'blue_plane', 'Acttmp2_blue_by_plane', m, p);
                        Raster_saved      = get_branch_plane_or_empty(data, 'blue_plane', 'Raster_blue_by_plane', m, p);
                        thresholds_saved  = get_branch_plane_or_empty(data, 'blue_plane', 'thresholds_blue_by_plane', m, p);
                        DF_sg_saved       = get_branch_plane_or_empty(data, 'blue_plane', 'DF_blue_by_plane', m, p);
                        DF_raw_saved      = get_branch_plane_or_empty(data, 'blue_plane', 'DF_raw_blue_by_plane', m, p);
                        F0_saved          = get_branch_plane_or_empty(data, 'blue_plane', 'F0_blue_by_plane', m, p);
                        noise_est_saved   = get_branch_plane_or_empty(data, 'blue_plane', 'noise_est_blue_by_plane', m, p);

                    case 'combined'

                        valid_cells_saved = get_branch_plane_or_empty(data, 'combined_plane', 'valid_combined_cells_by_plane', m, p);
                        Acttmp2_saved     = get_branch_plane_or_empty(data, 'combined_plane', 'Acttmp2_combined_by_plane', m, p);
                        Raster_saved      = get_branch_plane_or_empty(data, 'combined_plane', 'Raster_combined_by_plane', m, p);
                        thresholds_saved  = get_branch_plane_or_empty(data, 'combined_plane', 'thresholds_combined_by_plane', m, p);
                        DF_sg_saved       = get_branch_plane_or_empty(data, 'combined_plane', 'DF_combined_by_plane', m, p);
                        DF_raw_saved      = get_branch_plane_or_empty(data, 'combined_plane', 'DF_raw_combined_by_plane', m, p);
                        F0_saved          = get_branch_plane_or_empty(data, 'combined_plane', 'F0_combined_by_plane', m, p);
                        noise_est_saved   = get_branch_plane_or_empty(data, 'combined_plane', 'noise_est_combined_by_plane', m, p);
                end

                valid_viewer_data = ...
                    ~isempty(valid_cells_saved) && ...
                    ~isempty(DF_sg_saved) && ...
                    size(DF_sg_saved,1) == numel(valid_cells_saved) && ...
                    all(valid_cells_saved >= 1) && ...
                    all(valid_cells_saved <= size(F_in,1));

                if valid_viewer_data

                    F_view = F_in(valid_cells_saved,:);

                    if ~isempty(masks_in) && ...
                       ndims(masks_in) >= 3 && ...
                       size(masks_in,1) >= max(valid_cells_saved)
                        masks_in = masks_in(valid_cells_saved,:,:);
                    else
                        masks_in = [];
                    end

                    if strcmp(family,'combined') && ~isempty(blue_indices_in)

                        map_old_to_new = nan(size(F_in,1),1);
                        map_old_to_new(valid_cells_saved) = 1:numel(valid_cells_saved);

                        blue_indices_in = blue_indices_in( ...
                            blue_indices_in >= 1 & ...
                            blue_indices_in <= size(F_in,1));

                        blue_indices_in = map_old_to_new(blue_indices_in);
                        blue_indices_in = blue_indices_in(isfinite(blue_indices_in));
                        blue_indices_in = blue_indices_in(:);
                    end

                else
                    warning(['%s - plane %d: viewer mode impossible ' ...
                             '(DF/valid_cells manquants). Recalcul normal.'], record_label_m, p);
                    viewer_mode = false;
                end
            end

            if ~viewer_mode

                F_nostims = F_in;

                first_stim_frame = [];

                if ~isempty(stim_frames_m)
                    stim_tmp = double(stim_frames_m(:));
                    stim_tmp = stim_tmp(isfinite(stim_tmp));

                    if ~isempty(stim_tmp)
                        first_stim_frame = min(stim_tmp);
                    end
                end

                if ~isempty(first_stim_frame) && isfinite(first_stim_frame)

                    first_stim_frame_global = round(first_stim_frame);
                    first_stim_frame_plane  = ceil(first_stim_frame_global / nPlanes);

                    if first_stim_frame_plane > 1 && first_stim_frame_plane <= size(F_in,2)
                        last_frame = first_stim_frame_plane - 1;
                        F_nostims = F_in(:, 1:last_frame);
                    end
                end

                nT = size(F_nostims, 2);

                bad_frames = bad_frames_group;
                bad_segs = bad_segs_group;
                deviation = deviation_group;
                focus_segs = focus_segs_group;
                motion_energy = motion_energy_group;

                if ~isempty(motion_energy)
                    motion_energy = motion_energy(1:min(nT, numel(motion_energy)));
                end

                if ~isempty(bad_frames)
                    bad_frames = bad_frames(:).';
                    bad_frames = bad_frames(bad_frames >= 1 & bad_frames <= nT);
                end

                if ~isempty(deviation)
                    deviation = deviation(:).';
                    deviation = deviation(1:min(numel(deviation), nT));
                end

                if ~isempty(bad_frames)
                    bad_segs = badframes_to_segments(bad_frames, nT);
                    focus_segs = bad_segs;
                else
                    bad_segs = [];
                    focus_segs = [];
                end

                if ~isempty(bad_frames)

                    F_clean = F_nostims;
                    F_clean(:, bad_frames) = NaN;
                    F_clean = fillmissing(F_clean, 'linear', 2, 'EndValues', 'nearest');
                    F_nostims = F_clean;
                end

                F_view = F_nostims;
            end

            if isempty(F_view)
                fprintf('%s - plane %d: F_view empty.\n', record_label_m, p);
                continue;
            end

            [F0, noise_est, valid_cells, DF_sg, DF_raw, Raster, ...
             Acttmp2, MAct, thresholds, bad_segs_det, opts_det, has_new, request_reprocess] = ...
                peak_detection_tuner(F_view, ...
                    sampling_rate_m, ...
                    sync_frames_m, ...
                    'viewer_mode', viewer_mode, ...
                    'DF_sg', DF_sg_saved, ...
                    'DF_raw', DF_raw_saved, ...
                    'F0', F0_saved, ...
                    'noise_est', noise_est_saved, ...
                    'Acttmp2', Acttmp2_saved, ...
                    'Raster', Raster_saved, ...
                    'thresholds', thresholds_saved, ...
                    'valid_cells', valid_cells_saved, ...
                    'cell_type', cell_type, ...
                    'ops', ops_in, ...
                    'iscell_idx', iscell_idx, ...
                    'stat', stat_in, ...
                    'masks', masks_in, ...
                    'blue_indices', blue_indices_in, ...
                    'meanImg', meanImg, ...
                    'gcamp_TSeries_path', tiff_path, ...
                    'deviation', deviation, ...
                    'bad_frames', bad_frames, ...
                    'focus_segs', focus_segs, ...
                    'motion_energy', motion_energy, ...
                    'metadata', metadata_m, ...
                    'stim_frames', stim_frames_m, ...
                    'gcamp_output_folder', gcamp_output_folders{m}{p});
            
            if request_reprocess

                if process_blue_combined
                    branches_to_clear = {'gcamp','blue','combined'};
                else
                    branches_to_clear = {'gcamp'};
                end
            
                data = clear_detection_outputs_for_plane_in_data( ...
                    data, m, p, branches_to_clear, ...
                    fields_detect_gcamp, fields_detect_blue, fields_detect_combined);
            
                has_new_gcamp_group = true;
                has_new_blue_group = process_blue_combined;
                has_new_combined_group = process_blue_combined;
            
                fprintf('%s - plane %d: résultats effacés. Relance DF_peak_detection pour recalculer.\n', ...
                    record_label_m, p);
            
                continue;
                        end

            if viewer_mode
                continue;
            end

            if ~has_new
                fprintf('%s - plane %d: no new outputs for %s.\n', record_label_m, p, family);
                continue;
            end

            [isort1_plane, isort2_plane, Sm_plane] = ...
                compute_sort_outputs_from_df(DF_sg, ops_in);

            switch family

                case 'gcamp'

                    has_new_gcamp_group = true;

                    data.gcamp_plane.F0_gcamp_by_plane{m}{p} = F0;
                    data.gcamp_plane.noise_est_gcamp_by_plane{m}{p} = noise_est;
                    data.gcamp_plane.valid_gcamp_cells_by_plane{m}{p} = valid_cells;
                    data.gcamp_plane.DF_gcamp_by_plane{m}{p} = DF_sg;
                    data.gcamp_plane.DF_raw_gcamp_by_plane{m}{p} = DF_raw;
                    data.gcamp_plane.Raster_gcamp_by_plane{m}{p} = Raster;
                    data.gcamp_plane.Acttmp2_gcamp_by_plane{m}{p} = Acttmp2;
                    data.gcamp_plane.MAct_gcamp_by_plane{m}{p} = MAct;
                    data.gcamp_plane.thresholds_gcamp_by_plane{m}{p} = thresholds;
                    data.gcamp_plane.bad_segs_gcamp_plane{m}{p} = bad_segs_det;
                    data.gcamp_plane.opts_detection_gcamp_by_plane{m}{p} = opts_det;
                    data.gcamp_plane.isort1_gcamp_by_plane{m}{p} = isort1_plane;
                    data.gcamp_plane.isort2_gcamp_by_plane{m}{p} = isort2_plane;
                    data.gcamp_plane.Sm_gcamp_by_plane{m}{p} = Sm_plane;

                case 'blue'

                    has_new_blue_group = true;

                    data.blue_plane.F0_blue_by_plane{m}{p} = F0;
                    data.blue_plane.noise_est_blue_by_plane{m}{p} = noise_est;
                    data.blue_plane.valid_blue_cells_by_plane{m}{p} = valid_cells;
                    data.blue_plane.DF_blue_by_plane{m}{p} = DF_sg;
                    data.blue_plane.DF_raw_blue_by_plane{m}{p} = DF_raw;
                    data.blue_plane.Raster_blue_by_plane{m}{p} = Raster;
                    data.blue_plane.Acttmp2_blue_by_plane{m}{p} = Acttmp2;
                    data.blue_plane.MAct_blue_by_plane{m}{p} = MAct;
                    data.blue_plane.thresholds_blue_by_plane{m}{p} = thresholds;
                    data.blue_plane.bad_segs_blue_plane{m}{p} = bad_segs_det;
                    data.blue_plane.opts_detection_blue_by_plane{m}{p} = opts_det;
                    data.blue_plane.isort1_blue_by_plane{m}{p} = isort1_plane;
                    data.blue_plane.isort2_blue_by_plane{m}{p} = isort2_plane;
                    data.blue_plane.Sm_blue_by_plane{m}{p} = Sm_plane;

                case 'combined'

                    has_new_combined_group = true;

                    data.combined_plane.F0_combined_by_plane{m}{p} = F0;
                    data.combined_plane.noise_est_combined_by_plane{m}{p} = noise_est;
                    data.combined_plane.valid_combined_cells_by_plane{m}{p} = valid_cells;
                    data.combined_plane.DF_combined_by_plane{m}{p} = DF_sg;
                    data.combined_plane.DF_raw_combined_by_plane{m}{p} = DF_raw;
                    data.combined_plane.Raster_combined_by_plane{m}{p} = Raster;
                    data.combined_plane.Acttmp2_combined_by_plane{m}{p} = Acttmp2;
                    data.combined_plane.MAct_combined_by_plane{m}{p} = MAct;
                    data.combined_plane.thresholds_combined_by_plane{m}{p} = thresholds;
                    data.combined_plane.bad_segs_combined_plane{m}{p} = bad_segs_det;
                    data.combined_plane.opts_detection_combined_by_plane{m}{p} = opts_det;
                    data.combined_plane.isort1_combined_by_plane{m}{p} = isort1_plane;
                    data.combined_plane.isort2_combined_by_plane{m}{p} = isort2_plane;
                    data.combined_plane.Sm_combined_by_plane{m}{p} = Sm_plane;

                    [data, has_new_gcamp_group, has_new_blue_group] = ...
                        reconstruct_gcamp_blue_from_combined_if_needed( ...
                            data, m, p, ...
                            valid_cells, F0, noise_est, ...
                            DF_sg, DF_raw, ...
                            Raster, Acttmp2, thresholds, ...
                            bad_segs_det, opts_det, ...
                            blue_indices_in, sync_frames_m, ops_in, ...
                            has_new_gcamp_group, has_new_blue_group);
            end
        end

        if has_new_gcamp_group
            save_branch_fields(filePath_gcamp, data, 'gcamp_plane', fields_detect_gcamp, m);
        end

        if process_blue_combined && has_new_blue_group
            save_branch_fields(filePath_blue, data, 'blue_plane', fields_detect_blue, m);
        end

        if process_blue_combined && has_new_combined_group
            save_branch_fields(filePath_combined, data, 'combined_plane', fields_detect_combined, m);
        end

        if has_new_motion_group
            save_motion_group_fields(filePath_motion, data, fields_motion_group, m);
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
function data = init_motion_group_if_needed(data, numFolders, fields_motion_group)

    if ~isfield(data,'motion') || ~isstruct(data.motion)
        data.motion = struct();
    end

    for f = 1:numel(fields_motion_group)
        fn = fields_motion_group{f};

        if ~isfield(data.motion, fn) || ~iscell(data.motion.(fn))
            data.motion.(fn) = cell(numFolders,1);

        elseif numel(data.motion.(fn)) < numFolders
            old = data.motion.(fn);
            tmp = cell(numFolders,1);
            tmp(1:numel(old)) = old(:);
            data.motion.(fn) = tmp;
        end
    end
end

function data = merge_loaded_motion_group_into_data(data, loaded, fields_motion_group, m)

    for f = 1:numel(fields_motion_group)

        fn = fields_motion_group{f};

        if ~isfield(loaded, fn)
            continue;
        end

        if ~isfield(data.motion, fn) || numel(data.motion.(fn)) < m
            data.motion.(fn) = cell(m,1);
        end

        if isempty(data.motion.(fn){m})
            data.motion.(fn){m} = loaded.(fn);
        end
    end
end

function v = get_motion_group_or_empty(data, fieldName, m)

    v = [];

    if isfield(data,'motion') && ...
       isfield(data.motion, fieldName) && ...
       numel(data.motion.(fieldName)) >= m

        v = data.motion.(fieldName){m};
    end
end

function save_motion_group_fields(filePath_motion, data, fields_motion_group, m)

    saveStruct = struct();

    for f = 1:numel(fields_motion_group)
        fn = fields_motion_group{f};

        if isfield(data,'motion') && ...
           isfield(data.motion, fn) && ...
           numel(data.motion.(fn)) >= m

            saveStruct.(fn) = data.motion.(fn){m};
        end
    end

    outdir = fileparts(filePath_motion);
    if ~exist(outdir,'dir')
        mkdir(outdir);
    end

    if exist(filePath_motion,'file') == 2
        save(filePath_motion, '-struct', 'saveStruct', '-append');
    else
        save(filePath_motion, '-struct', 'saveStruct');
    end
end

function segs = badframes_to_segments(bad_frames, T)
    if isempty(bad_frames) || T<=0
        segs = zeros(0,2);
        return;
    end

    if islogical(bad_frames)
        bf = bad_frames(:).';
        if numel(bf) ~= T
            bf = bf(1:min(end,T));
            if numel(bf) < T, bf(end+1:T) = false; end
        end
        idx = find(bf);
    else
        idx = bad_frames(:).';
        idx = idx(isfinite(idx));
        idx = unique(round(idx));
        idx = idx(idx>=1 & idx<=T);
    end

    if isempty(idx)
        segs = zeros(0,2);
        return;
    end

    d = diff(idx);
    cuts = [1 find(d>1)+1 numel(idx)+1];

    segs = zeros(numel(cuts)-1,2);
    for k = 1:numel(cuts)-1
        a = idx(cuts(k));
        b = idx(cuts(k+1)-1);
        segs(k,:) = [a b];
    end
end

function [choice, state] = choose_signal_mode_for_plane_groupwise( ...
    has_gcamp, has_blue, has_combined, ...
    record_label, p, state)

    choice = '';

    nAvail = double(has_gcamp) + ...
             double(has_blue) + ...
             double(has_combined);

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

        state.mode = choice;
        state.ask_each_plane = false;
        state.initialized = true;
        return;
    end

    if state.initialized && ...
       ~state.ask_each_plane && ...
       ~isempty(state.mode)

        choice = state.mode;
        return;
    end

    if nargin < 4 || isempty(record_label)
        record_label = 'record';
    end

    default_button = default_signal_button( ...
        has_gcamp, has_blue, has_combined);

    if p == 0

        msg = sprintf([ ...
            '%s\n\n' ...
            'Choose signal to analyze.\n' ...
            'This choice will be applied to all planes.'], ...
            record_label);

    else

        msg = sprintf([ ...
            '%s - plane %d\n\n' ...
            'Choose signal to analyze.'], ...
            record_label, p);
    end

    answer = questdlg( ...
        msg, ...
        'Select signal', ...
        'gcamp only', ...
        'blue only', ...
        'both / combined', ...
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
            return;
    end

    state.mode = choice;
    state.ask_each_plane = false;
    state.initialized = true;
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

function [user_segs, user_frames] = enter_observed_deviations(tifPath, T)

    if nargin < 1
        error('Usage: [user_segs,user_frames] = enter_observed_deviations(tifPath,T)');
    end
    if nargin < 2, T = []; end

    if ~exist(tifPath,'file')
        error('TIFF introuvable : %s', tifPath);
    end

    fprintf('\n=== OUVRIR MANUELLEMENT DANS FIJI ===\n');
    fprintf('Fichier TIFF :\n%s\n\n', tifPath);
    fprintf('Ouvre ce fichier dans Fiji, observe les déviations,\n');
    fprintf('puis reviens ici pour entrer les frames correspondantes.\n\n');

    fprintf('Entrée attendue (FRAMES uniquement) :\n');
    fprintf('  ex: 120:140\n');
    fprintf('      [120:140 300:320]\n');
    fprintf('[] si aucune déviation.\n\n');

    x = input('Frames observées = ');

    if isempty(x)
        fprintf('Aucune déviation saisie.\n');
        user_segs = zeros(0,2);
        user_frames = [];
        return;
    end

    if ~isnumeric(x) || ~isvector(x)
        error('Entrée invalide: entrer UNIQUEMENT un vecteur de frames.');
    end

    fr = round(x(:).');
    fr = fr(isfinite(fr));

    if ~isempty(T)
        fr = fr(fr>=1 & fr<=T);
    else
        fr = fr(fr>=1);
    end

    fr = unique(fr);

    user_segs = frames_to_segments(fr);
    user_frames = fr;

    fprintf('\n=== Enregistré ===\n');
    fprintf('Segments détectés: %d\n', size(user_segs,1));
    if ~isempty(user_segs)
        disp(user_segs);
    end
end

function segs = frames_to_segments(fr)
    if isempty(fr)
        segs = zeros(0,2);
        return;
    end
    d = diff(fr);
    cuts = [1 find(d>1)+1 numel(fr)+1];
    segs = zeros(numel(cuts)-1,2);
    for k = 1:numel(cuts)-1
        segs(k,:) = [fr(cuts(k)) fr(cuts(k+1)-1)];
    end
end

function segTable = sort_segments_by_deviation(bad_segs, deviation)

    if nargin < 2
        error('Usage: segTable = sort_segments_by_deviation(bad_segs, deviation)');
    end

    deviation = deviation(:).';
    T = numel(deviation);

    if isempty(bad_segs)
        segTable = table([], [], [], [], ...
            'VariableNames', {'StartFrame','EndFrame','FrameExtent','ValMaxDeviation'});
        disp(segTable);
        return;
    end

    if size(bad_segs,2) ~= 2
        error('bad_segs doit être une matrice Nx2 [start end].');
    end

    N = size(bad_segs,1);

    startF = nan(N,1);
    endF   = nan(N,1);
    extent = nan(N,1);
    valMax = nan(N,1);

    for k = 1:N
        a = round(bad_segs(k,1));
        b = round(bad_segs(k,2));

        if a > b
            tmp = a; a = b; b = tmp;
        end

        a = max(1, min(T, a));
        b = max(1, min(T, b));

        startF(k) = a;
        endF(k)   = b;
        extent(k) = b - a + 1;

        segVals = deviation(a:b);
        segVals = segVals(isfinite(segVals));

        if isempty(segVals)
            valMax(k) = NaN;
        else
            valMax(k) = min(segVals);
        end
    end

    segTable = table(startF, endF, extent, valMax, ...
        'VariableNames', {'StartFrame','EndFrame','FrameExtent','ValMaxDeviation'});

    segTable = sortrows(segTable, 'ValMaxDeviation', 'ascend');
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

function [data, has_new_gcamp_group, has_new_blue_group] = ...
    reconstruct_gcamp_blue_from_combined_if_needed( ...
        data, m, p, ...
        valid_cells, F0, noise_est, ...
        DF_sg, DF_raw, ...
        Raster, Acttmp2, thresholds, ...
        bad_segs_det, opts_det, ...
        blue_indices_combined, synchronous_frames, ops_in, ...
        has_new_gcamp_group, has_new_blue_group)

    % ============================================================
    % Reconstruction GCaMP
    % ============================================================

    [ok_gcamp, out_gcamp] = reconstruct_gcamp_from_combined_outputs( ...
        valid_cells, F0, noise_est, ...
        DF_sg, DF_raw, ...
        Raster, Acttmp2, thresholds, ...
        bad_segs_det, opts_det, ...
        blue_indices_combined, synchronous_frames);

    if ok_gcamp

        [isort1, isort2, Sm] = ...
            compute_sort_outputs_from_df(out_gcamp.DF_sg, ops_in);

        data.gcamp_plane.F0_gcamp_by_plane{m}{p}            = out_gcamp.F0;
        data.gcamp_plane.noise_est_gcamp_by_plane{m}{p}     = out_gcamp.noise_est;
        data.gcamp_plane.valid_gcamp_cells_by_plane{m}{p}   = out_gcamp.valid_cells;
        data.gcamp_plane.DF_gcamp_by_plane{m}{p}            = out_gcamp.DF_sg;
        data.gcamp_plane.DF_raw_gcamp_by_plane{m}{p}        = out_gcamp.DF_raw;
        data.gcamp_plane.Raster_gcamp_by_plane{m}{p}        = out_gcamp.Raster;
        data.gcamp_plane.Acttmp2_gcamp_by_plane{m}{p}       = out_gcamp.Acttmp2;
        data.gcamp_plane.MAct_gcamp_by_plane{m}{p}          = out_gcamp.MAct;
        data.gcamp_plane.thresholds_gcamp_by_plane{m}{p}    = out_gcamp.thresholds;
        data.gcamp_plane.bad_segs_gcamp_plane{m}{p}         = out_gcamp.bad_segs;
        data.gcamp_plane.opts_detection_gcamp_by_plane{m}{p}= out_gcamp.opts_det;
        data.gcamp_plane.isort1_gcamp_by_plane{m}{p}        = isort1;
        data.gcamp_plane.isort2_gcamp_by_plane{m}{p}        = isort2;
        data.gcamp_plane.Sm_gcamp_by_plane{m}{p}            = Sm;

        has_new_gcamp_group = true;
    end


    % ============================================================
    % Reconstruction Blue
    % ============================================================

    [ok_blue, out_blue] = reconstruct_blue_from_combined_outputs( ...
        valid_cells, F0, noise_est, ...
        DF_sg, DF_raw, ...
        Raster, Acttmp2, thresholds, ...
        bad_segs_det, opts_det, ...
        blue_indices_combined, synchronous_frames);

    if ok_blue

        [isort1, isort2, Sm] = ...
            compute_sort_outputs_from_df(out_blue.DF_sg, ops_in);

        data.blue_plane.F0_blue_by_plane{m}{p}            = out_blue.F0;
        data.blue_plane.noise_est_blue_by_plane{m}{p}     = out_blue.noise_est;
        data.blue_plane.valid_blue_cells_by_plane{m}{p}   = out_blue.valid_cells;
        data.blue_plane.DF_blue_by_plane{m}{p}            = out_blue.DF_sg;
        data.blue_plane.DF_raw_blue_by_plane{m}{p}        = out_blue.DF_raw;
        data.blue_plane.Raster_blue_by_plane{m}{p}        = out_blue.Raster;
        data.blue_plane.Acttmp2_blue_by_plane{m}{p}       = out_blue.Acttmp2;
        data.blue_plane.MAct_blue_by_plane{m}{p}          = out_blue.MAct;
        data.blue_plane.thresholds_blue_by_plane{m}{p}    = out_blue.thresholds;
        data.blue_plane.bad_segs_blue_plane{m}{p}         = out_blue.bad_segs;
        data.blue_plane.opts_detection_blue_by_plane{m}{p}= out_blue.opts_det;
        data.blue_plane.isort1_blue_by_plane{m}{p}        = isort1;
        data.blue_plane.isort2_blue_by_plane{m}{p}        = isort2;
        data.blue_plane.Sm_blue_by_plane{m}{p}            = Sm;

        has_new_blue_group = true;
    end
end

function [ok, out] = reconstruct_gcamp_from_combined_outputs( ...
    valid_combined, F0_combined, noise_est_combined, ...
    DF_sg_combined, DF_raw_combined, ...
    Raster_combined, Acttmp2_combined, thresholds_combined, ...
    bad_segs_combined, opts_det_combined, ...
    blue_indices_combined, synchronous_frames)

    ok = false;

    out = struct( ...
        'F0', [], ...
        'noise_est', [], ...
        'valid_cells', [], ...
        'DF_sg', [], ...
        'DF_raw', [], ...
        'Raster', [], ...
        'Acttmp2', {{}}, ...
        'MAct', [], ...
        'thresholds', [], ...
        'bad_segs', [], ...
        'opts_det', []);

    if isempty(valid_combined)
        return;
    end

    valid_combined = valid_combined(:);

    if isempty(blue_indices_combined)
        blue_indices_combined = [];
    else
        blue_indices_combined = blue_indices_combined(:);
    end

    is_gcamp_valid = ~ismember(valid_combined, blue_indices_combined);

    if ~any(is_gcamp_valid)
        return;
    end

    row_keep = find(is_gcamp_valid);
    valid_gcamp = valid_combined(row_keep);

    out.valid_cells = valid_gcamp(:);
    out.F0 = safe_take_rows(F0_combined, row_keep);
    out.noise_est = safe_take_rows(noise_est_combined, row_keep);

    out.DF_sg = safe_take_rows(DF_sg_combined, row_keep);
    out.DF_raw = safe_take_rows(DF_raw_combined, row_keep);

    out.Raster = safe_take_rows(Raster_combined, row_keep);
    out.Acttmp2 = safe_take_cells(Acttmp2_combined, row_keep);
    out.thresholds = safe_take_rows(thresholds_combined, row_keep);

    out.bad_segs = bad_segs_combined;
    out.opts_det = opts_det_combined;
    out.MAct = recompute_mact_from_raster(out.Raster, synchronous_frames);

    ok = true;
end

function [ok, out] = reconstruct_blue_from_combined_outputs( ...
    valid_combined, F0_combined, noise_est_combined, ...
    DF_sg_combined, DF_raw_combined, ...
    Raster_combined, Acttmp2_combined, thresholds_combined, ...
    bad_segs_combined, opts_det_combined, ...
    blue_indices_combined, synchronous_frames)

    ok = false;

    out = struct( ...
        'F0', [], ...
        'noise_est', [], ...
        'valid_cells', [], ...
        'valid_cells_combined', [], ...
        'DF_sg', [], ...
        'DF_raw', [], ...
        'Raster', [], ...
        'Acttmp2', {{}}, ...
        'MAct', [], ...
        'thresholds', [], ...
        'bad_segs', [], ...
        'opts_det', []);

    if isempty(valid_combined) || isempty(blue_indices_combined)
        return;
    end

    valid_combined = valid_combined(:);
    blue_indices_combined = blue_indices_combined(:);

    is_blue_valid = ismember(valid_combined, blue_indices_combined);

    if ~any(is_blue_valid)
        return;
    end

    row_keep = find(is_blue_valid);
    valid_blue_combined = valid_combined(row_keep);

    [tf_map, loc_blue] = ismember(valid_blue_combined, blue_indices_combined);
    valid_blue_local = loc_blue(tf_map);

    out.valid_cells = valid_blue_local(:);
    out.valid_cells_combined = valid_blue_combined(:);

    out.F0 = safe_take_rows(F0_combined, row_keep);
    out.noise_est = safe_take_rows(noise_est_combined, row_keep);

    out.DF_sg = safe_take_rows(DF_sg_combined, row_keep);
    out.DF_raw = safe_take_rows(DF_raw_combined, row_keep);

    out.Raster = safe_take_rows(Raster_combined, row_keep);
    out.Acttmp2 = safe_take_cells(Acttmp2_combined, row_keep);
    out.thresholds = safe_take_rows(thresholds_combined, row_keep);

    out.bad_segs = bad_segs_combined;
    out.opts_det = opts_det_combined;
    out.MAct = recompute_mact_from_raster(out.Raster, synchronous_frames);

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

function [isort1_out, isort2_out, Sm_out] = compute_sort_outputs_from_df(DF_in, ops_in)
    isort1_out = [];
    isort2_out = [];
    Sm_out     = [];

    if isempty(DF_in)
        return;
    end

    try
        [isort1_out, isort2_out, Sm_out] = ...
            raster_processing(double(DF_in), ops_in);
    catch ME
        warning('compute_sort_outputs_from_df:raster_processing', ...
            'raster_processing failed (%s).', ME.message);
        isort1_out = [];
        isort2_out = [];
        Sm_out     = [];
    end
end

function label = make_record_label(current_animal_group, metadata_m, m)

    animal_name = char(string(current_animal_group));
    date_name = '';

    if isfield(metadata_m, 'DateName') && ~isempty(metadata_m.DateName)
        date_name = char(string(metadata_m.DateName));
    end

    if ~isempty(animal_name) && ~isempty(date_name)
        label = sprintf('%s - %s', animal_name, date_name);
    elseif ~isempty(animal_name)
        label = animal_name;
    elseif ~isempty(date_name)
        label = date_name;
    else
        label = sprintf('Record %d', m);
    end
end

function [viewer_mode, skip_plane] = ask_viewer(has_detection, record_label, p, cell_type)

    viewer_mode = false;
    skip_plane  = false;

    if ~has_detection
        return;
    end

    if nargin < 2 || isempty(record_label)
        record_label = 'record';
    end

    if nargin < 3 || isempty(p)
        p = 0;
    end

    if nargin < 4 || isempty(cell_type)
        cell_type = 'plane';
    end

    plane_label = sprintf('plane %d', p);

    msg = sprintf(['%s - %s\n\n' ...
                   'Existing %s detection found.\n\n' ...
                   'What do you want to do?'], ...
                   record_label, plane_label, cell_type);

    answer = questdlg( ...
        msg, ...
        'Existing detection', ...
        'Viewer', ...
        'Load only', ...
        'Load only');

    switch answer
        case 'Viewer'
            viewer_mode = true;
            skip_plane  = false;

        otherwise
            viewer_mode = false;
            skip_plane  = true;
    end
end

function action = ask_existing_detection_action_global(record_label)

    if nargin < 1 || isempty(record_label)
        record_label = 'record';
    end

    msg = sprintf([ ...
        '%s\n\n' ...
        'Existing peak detection was found.\n\n' ...
        'What do you want to do for all existing detections?'], ...
        record_label);

    answer = questdlg( ...
        msg, ...
        'Existing detection - global mode', ...
        'Viewer', ...
        'Load only', ...
        'Load only');

    switch answer
        case 'Viewer'
            action = 'viewer';

        otherwise
            action = 'load_only';
    end
end

function metadata_m = get_metadata_for_record(metadata, idx)

    metadata_m = struct();

    if isempty(metadata) || ~isstruct(metadata)
        return;
    end

    fields = fieldnames(metadata);

    for f = 1:numel(fields)

        field = fields{f};
        value = metadata.(field);

        if iscell(value)

            if numel(value) >= idx
                metadata_m.(field) = value{idx};
            else
                metadata_m.(field) = [];
            end

        else
            metadata_m.(field) = value;
        end
    end
end

function mode = ask_processing_mode()

    answer = questdlg( ...
        ['Choose processing mode:' newline newline ...
         'Global processing: same signal choice reused automatically.' newline ...
         'Case by case: choose independently for each plane.'], ...
        'Processing mode', ...
        'global processing', ...
        'case by case', ...
        'case by case');

    switch answer
        case 'global processing'
            mode = 'global';
        otherwise
            mode = 'case_by_case';
    end
end

function tf = branch_has_missing_fields(data, branchName, fieldsToCheck, m, nPlanes)

    tf = true;

    if ~isfield(data, branchName) || ~isstruct(data.(branchName))
        return;
    end

    for f = 1:numel(fieldsToCheck)

        fieldName = fieldsToCheck{f};

        if ~isfield(data.(branchName), fieldName) || ...
                numel(data.(branchName).(fieldName)) < m || ...
                isempty(data.(branchName).(fieldName){m}) || ...
                ~iscell(data.(branchName).(fieldName){m})

            return;
        end

        for p = 1:nPlanes
            if numel(data.(branchName).(fieldName){m}) < p || ...
                    isempty(data.(branchName).(fieldName){m}{p})
                return;
            end
        end
    end

    tf = false;
end


function tf = motion_group_has_missing_fields(data, fields_motion_group, m)

    tf = true;

    if ~isfield(data, 'motion') || ~isstruct(data.motion)
        return;
    end

    for f = 1:numel(fields_motion_group)

        fn = fields_motion_group{f};

        if ~isfield(data.motion, fn) || ...
                numel(data.motion.(fn)) < m || ...
                isempty(data.motion.(fn){m})

            return;
        end
    end

    tf = false;
end

function data = clear_detection_outputs_for_plane_in_data( ...
    data, m, p, branches_to_clear, ...
    fields_detect_gcamp, fields_detect_blue, fields_detect_combined)

    for b = 1:numel(branches_to_clear)

        switch branches_to_clear{b}
            case 'gcamp'
                branchName = 'gcamp_plane';
                fields = fields_detect_gcamp;
            case 'blue'
                branchName = 'blue_plane';
                fields = fields_detect_blue;
            case 'combined'
                branchName = 'combined_plane';
                fields = fields_detect_combined;
            otherwise
                continue;
        end

        for f = 1:numel(fields)
            fn = fields{f};

            if isfield(data, branchName) && ...
               isfield(data.(branchName), fn) && ...
               numel(data.(branchName).(fn)) >= m && ...
               iscell(data.(branchName).(fn){m}) && ...
               numel(data.(branchName).(fn){m}) >= p

                data.(branchName).(fn){m}{p} = [];
            end
        end
    end
end