function results_analysis = compute_export_basic_metrics( ...
    current_animal_group, ...
    gcamp_root_folders, ...
    date_group_paths, ...
    synchronous_frames_group, ...
    data, ...
    metadata, ...
    include_blue_cells)

    nRec = numel(gcamp_root_folders);

    if nargin < 7 || isempty(include_blue_cells)
        include_blue_cells = '1';
    end
    
    include_blue_cells = char(string(include_blue_cells));
    process_blue_combined = ~strcmp(include_blue_cells, '1');

    results_analysis = init_empty_results_analysis(nRec);

    for m = 1:nRec

        [~, date_name] = fileparts(date_group_paths{m});

        try
            sampling_rate = get_metadata_value(metadata, 'SamplingRatePlane', m);
            sampling_rate = parse_numeric_vector(sampling_rate);

            if isempty(sampling_rate)
                error('SamplingRatePlane vide pour rec %d', m);
            end

            sampling_rate = sampling_rate(1);

            position = get_metadata_value(metadata, 'PositionZ', m);
            position = parse_numeric_vector(position);

            if isempty(position)
                error('PositionZ vide pour rec %d', m);
            end

            z_position_um = num2cell(position(:).');

            %======================================================
            % Basic metrics GCaMP
            %======================================================
            gcamp_metrics = compute_branch_metrics_by_plane( ...
                data, 'gcamp_plane', m, sampling_rate, ...
                'DF_gcamp_by_plane', ...
                'Raster_gcamp_by_plane');

            if ~gcamp_metrics.valid
                warning('Skipping rec %d (%s) — DF/Raster GCaMP vide.', ...
                    m, gcamp_root_folders{m});
                continue;
            end

            %======================================================
            % Basic metrics Blue
            %======================================================
            if process_blue_combined
                blue_metrics = compute_branch_metrics_by_plane( ...
                    data, 'blue_plane', m, sampling_rate, ...
                    'DF_blue_by_plane', ...
                    'Raster_blue_by_plane');
            else
                blue_metrics = empty_branch_metrics();
            end

            %======================================================
            % Pairwise correlation
            %======================================================
            corr_metrics = load_or_process_corr_for_session( ...
                gcamp_root_folders, data, m, include_blue_cells);

            %======================================================
            % SCEs
            %======================================================
            sce_metrics = load_or_process_sce_for_session( ...
                current_animal_group, ...
                date_group_paths, ...
                gcamp_root_folders, ...
                synchronous_frames_group, ...
                data, ...
                m, ...
                sampling_rate);

            %======================================================
            % General
            %======================================================
            results_analysis.general.DateName{m} = date_name;
            results_analysis.general.NumFrames{m} = gcamp_metrics.nFrames_by_plane;
            results_analysis.general.ZPosition_um{m} = z_position_um;

            %======================================================
            % GCaMP
            %======================================================
            results_analysis.gcamp_plane.ActiveCellsNumber{m} = ...
                gcamp_metrics.nCells_by_plane;

            results_analysis.gcamp_plane.FrequencyPerCell{m} = ...
                gcamp_metrics.freq_by_plane;

            results_analysis.gcamp_plane.InterEventIntervals_ms{m} = ...
                gcamp_metrics.intervals_ms_by_plane;

            results_analysis.gcamp_plane.BurstRate_per_min{m} = ...
                gcamp_metrics.burst_rate_by_plane;

            results_analysis.gcamp_plane.BurstFraction{m} = ...
                gcamp_metrics.burst_fraction_by_plane;

            results_analysis.gcamp_plane.BurstSize{m} = ...
                gcamp_metrics.burst_size_by_plane;

            %======================================================
            % Blue
            %======================================================
            results_analysis.blue_plane.ActiveCellsNumber{m} = ...
                blue_metrics.nCells_by_plane;

            results_analysis.blue_plane.FrequencyPerCell{m} = ...
                blue_metrics.freq_by_plane;

            results_analysis.blue_plane.InterEventIntervals_ms{m} = ...
                blue_metrics.intervals_ms_by_plane;

            results_analysis.blue_plane.BurstRate_per_min{m} = ...
                blue_metrics.burst_rate_by_plane;

            results_analysis.blue_plane.BurstFraction{m} = ...
                blue_metrics.burst_fraction_by_plane;

            results_analysis.blue_plane.BurstSize{m} = ...
                blue_metrics.burst_size_by_plane;

            %======================================================
            % Correlations
            %======================================================
            results_analysis.gcamp_plane.max_corr_gcamp_gcamp_by_plane{m} = ...
                corr_metrics.max_corr_gcamp_gcamp_by_plane;
            
            results_analysis.blue_plane.max_corr_gcamp_mtor_by_plane{m} = ...
                corr_metrics.max_corr_gcamp_mtor_by_plane;
            
            results_analysis.blue_plane.max_corr_mtor_mtor_by_plane{m} = ...
                corr_metrics.max_corr_mtor_mtor_by_plane;

            %======================================================
            % SCEs
            %======================================================
            results_analysis.SCEs.Race_gcamp{m} = ...
                sce_metrics.Race_gcamp;

            results_analysis.SCEs.TRace_gcamp{m} = ...
                sce_metrics.TRace_gcamp;

            results_analysis.SCEs.sces_distances_gcamp{m} = ...
                sce_metrics.sces_distances_gcamp;

            results_analysis.SCEs.RasterRace_gcamp{m} = ...
                sce_metrics.RasterRace_gcamp;

            results_analysis.SCEs.sce_n_cells_threshold{m} = ...
                sce_metrics.sce_n_cells_threshold;

            results_analysis.SCEs.Threshold{m} = ...
                sce_metrics.sce_n_cells_threshold;

            results_analysis.SCEs.Frequency{m} = ...
                sce_metrics.sce_frequency_per_min;

            results_analysis.SCEs.CellParticipation_percent{m} = ...
                sce_metrics.cell_participation_percent;

            results_analysis.SCEs.Duration_ms{m} = ...
                sce_metrics.duration_ms;

        catch ME
            fprintf('Error processing rec %d: %s\n', m, ME.message);
        end
    end
end

function results_analysis = init_empty_results_analysis(nRec)

    results_analysis = struct( ...
        'general', struct(), ...
        'gcamp_plane', struct(), ...
        'blue_plane', struct(), ...
        'SCEs', struct());

    results_analysis.general.DateName = cell(nRec, 1);
    results_analysis.general.NumFrames = cell(nRec, 1);
    results_analysis.general.ZPosition_um = cell(nRec, 1);

    results_analysis.gcamp_plane.ActiveCellsNumber = cell(nRec, 1);
    results_analysis.gcamp_plane.FrequencyPerCell = cell(nRec, 1);
    results_analysis.gcamp_plane.InterEventIntervals_ms = cell(nRec, 1);
    results_analysis.gcamp_plane.BurstRate_per_min = cell(nRec, 1);
    results_analysis.gcamp_plane.BurstFraction = cell(nRec, 1);
    results_analysis.gcamp_plane.BurstSize = cell(nRec, 1);
    results_analysis.gcamp_plane.max_corr_gcamp_gcamp_by_plane = cell(nRec, 1);


    results_analysis.blue_plane.ActiveCellsNumber = cell(nRec, 1);
    results_analysis.blue_plane.FrequencyPerCell = cell(nRec, 1);
    results_analysis.blue_plane.InterEventIntervals_ms = cell(nRec, 1);
    results_analysis.blue_plane.BurstRate_per_min = cell(nRec, 1);
    results_analysis.blue_plane.BurstFraction = cell(nRec, 1);
    results_analysis.blue_plane.BurstSize = cell(nRec, 1);
    results_analysis.blue_plane.max_corr_gcamp_mtor_by_plane = cell(nRec, 1);
    results_analysis.blue_plane.max_corr_mtor_mtor_by_plane = cell(nRec, 1);
    
    results_analysis.SCEs.Race_gcamp = cell(nRec, 1);
    results_analysis.SCEs.TRace_gcamp = cell(nRec, 1);
    results_analysis.SCEs.sces_distances_gcamp = cell(nRec, 1);
    results_analysis.SCEs.RasterRace_gcamp = cell(nRec, 1);
    results_analysis.SCEs.sce_n_cells_threshold = cell(nRec, 1);

    results_analysis.SCEs.Threshold = cell(nRec, 1);
    results_analysis.SCEs.Frequency = cell(nRec, 1);
    results_analysis.SCEs.CellParticipation_percent = cell(nRec, 1);
    results_analysis.SCEs.Duration_ms = cell(nRec, 1);
end

function corr_metrics = load_or_process_corr_for_session(gcamp_root_folders, data, m, include_blue_cells)
    
    if nargin < 4 || isempty(include_blue_cells)
        include_blue_cells = '1';
    end
    
    include_blue_cells = char(string(include_blue_cells));
    process_blue_combined = ~strcmp(include_blue_cells, '1');

    corr_metrics = struct( ...
        'max_corr_gcamp_gcamp_by_plane', {{}}, ...
        'max_corr_gcamp_mtor_by_plane', {{}}, ...
        'max_corr_mtor_mtor_by_plane', {{}});

    if isempty(gcamp_root_folders) || ...
       m > numel(gcamp_root_folders) || ...
       isempty(gcamp_root_folders{m})
        fprintf('Session %d: gcamp_root_folders vide, skip corr.\n', m);
        return;
    end

    filePath = fullfile(gcamp_root_folders{m}, 'results_corr.mat');

    DFg_planes = get_planes_or_error_nested(data, 'gcamp_plane', m, 'DF_gcamp_by_plane');
    nPlanes = numel(DFg_planes);

    mc_gg_planes = cell(1, nPlanes);
    mc_gm_planes = cell(1, nPlanes);
    mc_mm_planes = cell(1, nPlanes);
    
    if exist(filePath, 'file') == 2

        loaded = load(filePath);

        mc_gg_planes = getFieldOrDefault(loaded, 'max_corr_gcamp_gcamp_by_plane', mc_gg_planes);
        mc_gm_planes = getFieldOrDefault(loaded, 'max_corr_gcamp_mtor_by_plane', mc_gm_planes);
        mc_mm_planes = getFieldOrDefault(loaded, 'max_corr_mtor_mtor_by_plane', mc_mm_planes);

        mc_gg_planes = getFieldOrDefault(loaded, 'max_corr_gcamp_gcamp_by_plane_file', mc_gg_planes);
        mc_gm_planes = getFieldOrDefault(loaded, 'max_corr_gcamp_mtor_by_plane_file', mc_gm_planes);
        mc_mm_planes = getFieldOrDefault(loaded, 'max_corr_mtor_mtor_by_plane_file', mc_mm_planes);

        mc_gg_planes = getFieldOrDefault(loaded, 'max_corr_gcamp_gcamp_by_plane_s', mc_gg_planes);
        mc_gm_planes = getFieldOrDefault(loaded, 'max_corr_gcamp_mtor_by_plane_s', mc_gm_planes);
        mc_mm_planes = getFieldOrDefault(loaded, 'max_corr_mtor_mtor_by_plane_s', mc_mm_planes);

        mc_gg_planes = ensure_plane_cell(mc_gg_planes, nPlanes);
        mc_gm_planes = ensure_plane_cell(mc_gm_planes, nPlanes);
        mc_mm_planes = ensure_plane_cell(mc_mm_planes, nPlanes);

    else

        has_combined_by_plane = ...
            isfield(data, 'combined_plane') && ...
            isstruct(data.combined_plane) && ...
            isfield(data.combined_plane, 'DF_combined_by_plane') && ...
            numel(data.combined_plane.DF_combined_by_plane) >= m && ...
            ~isempty(data.combined_plane.DF_combined_by_plane{m});

        has_blue_indices = ...
            isfield(data, 'combined_plane') && ...
            isstruct(data.combined_plane) && ...
            isfield(data.combined_plane, 'blue_indices_combined_by_plane') && ...
            numel(data.combined_plane.blue_indices_combined_by_plane) >= m && ...
            ~isempty(data.combined_plane.blue_indices_combined_by_plane{m});
        
        use_combined = process_blue_combined && has_combined_by_plane && has_blue_indices;

        if use_combined

            DFc_planes = get_planes_or_error_nested( ...
                data, 'combined_plane', m, 'DF_combined_by_plane');
        
            blue_idx_planes = ...
                data.combined_plane.blue_indices_combined_by_plane{m};
        
            if ~iscell(blue_idx_planes)
                error('Session %d: blue_indices_combined_by_plane{%d} doit être une cell.', ...
                    m, m);
            end
        
            if numel(DFc_planes) ~= nPlanes
                error('Session %d: mismatch DF_gcamp (%d) vs DF_combined (%d).', ...
                    m, nPlanes, numel(DFc_planes));
            end
        
            if numel(blue_idx_planes) ~= nPlanes
                error('Session %d: mismatch DF_gcamp (%d) vs blue_indices (%d).', ...
                    m, nPlanes, numel(blue_idx_planes));
            end
        
        else
        
            DFc_planes = cell(1,nPlanes);
            blue_idx_planes = cell(1,nPlanes);
        
        end

        disp(['Computing pairwise correlations (BY PLANE) for folder ', num2str(m)]);

        for p = 1:nPlanes

            DFg = DFg_planes{p};

            if isempty(DFg)
                mc_gg_planes{p} = [];
                mc_gm_planes{p} = [];
                mc_mm_planes{p} = [];
                continue;
            end

            if use_combined
                DFc = DFc_planes{p};
                blue_idx = blue_idx_planes{p};

                [mc_gg, mc_gm, mc_mm] = compute_pairwise_corr( ...
                    DFg, gcamp_root_folders{m}, DFc, blue_idx);
            else
                [mc_gg, mc_gm, mc_mm] = compute_pairwise_corr( ...
                    DFg, gcamp_root_folders{m});
            end

            mc_gg_planes{p} = mc_gg;
            mc_gm_planes{p} = mc_gm;
            mc_mm_planes{p} = mc_mm;
        end

        saveStruct = struct();
        saveStruct.max_corr_gcamp_gcamp_by_plane = mc_gg_planes;
        saveStruct.max_corr_gcamp_mtor_by_plane = mc_gm_planes;
        saveStruct.max_corr_mtor_mtor_by_plane = mc_mm_planes;

        save(filePath, '-struct', 'saveStruct');
    end

    corr_metrics.max_corr_gcamp_gcamp_by_plane = mc_gg_planes;
    corr_metrics.max_corr_gcamp_mtor_by_plane = mc_gm_planes;
    corr_metrics.max_corr_mtor_mtor_by_plane = mc_mm_planes;
end

function sce_metrics = load_or_process_sce_for_session( ...
    current_animal_group, ...
    date_group_paths, ...
    gcamp_root_folders, ...
    synchronous_frames_group, ...
    data, ...
    m, ...
    sampling_rate)

    sce_metrics = struct( ...
        'Race_gcamp', [], ...
        'TRace_gcamp', [], ...
        'sces_distances_gcamp', [], ...
        'RasterRace_gcamp', [], ...
        'sce_n_cells_threshold', [], ...
        'sce_frequency_per_min', NaN, ...
        'cell_participation_percent', [], ...
        'duration_ms', []);

    if isempty(gcamp_root_folders) || ...
       m > numel(gcamp_root_folders) || ...
       isempty(gcamp_root_folders{m})
        fprintf('Session %d: gcamp_root_folders vide, skip SCEs.\n', m);
        return;
    end

    filePath = fullfile(gcamp_root_folders{m}, 'results_SCEs.mat');

    Raster_global_for_duration = concat_planes_local_nested( ...
    data, 'gcamp_plane', m, 'Raster_gcamp_by_plane', 'logical');

    if isempty(Raster_global_for_duration) || sampling_rate <= 0
        sce_metrics.recording_duration_min = NaN;
    else
        sce_metrics.recording_duration_min = ...
            size(Raster_global_for_duration, 2) / sampling_rate / 60;
    end

    if exist(filePath, 'file') == 2

        disp(['Loading existing SCE file: ', filePath]);

        loaded = load(filePath);

        sce_metrics.Race_gcamp = getFieldOrDefault(loaded, 'Race_gcamp', []);
        sce_metrics.TRace_gcamp = getFieldOrDefault(loaded, 'TRace_gcamp', []);
        sce_metrics.sces_distances_gcamp = getFieldOrDefault(loaded, 'sces_distances_gcamp', []);
        sce_metrics.RasterRace_gcamp = getFieldOrDefault(loaded, 'RasterRace_gcamp', []);
        sce_metrics.sce_n_cells_threshold = getFieldOrDefault(loaded, 'sce_n_cells_threshold', []);

    else

        DF_global = concat_planes_local_nested(data, 'gcamp_plane', m, 'DF_gcamp_by_plane', 'numeric');
        Raster_global = concat_planes_local_nested(data, 'gcamp_plane', m, 'Raster_gcamp_by_plane', 'logical');

        if isempty(DF_global) || isempty(Raster_global)
            warning('Skipping folder %s — DF/Raster global vide après concat.', gcamp_root_folders{m});
            return;
        end

        minFrames = min(size(DF_global, 2), size(Raster_global, 2));

        if minFrames == 0
            warning('Skipping folder %s — DF/Raster sans frames.', gcamp_root_folders{m});
            return;
        end

        DF_global = DF_global(:, 1:minFrames);
        Raster_global = Raster_global(:, 1:minFrames);

        Nz = size(DF_global, 2);

        if ~isfield(data, 'gcamp_plane') || ...
           ~isstruct(data.gcamp_plane) || ...
           ~isfield(data.gcamp_plane, 'MAct_gcamp_by_plane') || ...
           numel(data.gcamp_plane.MAct_gcamp_by_plane) < m || ...
           isempty(data.gcamp_plane.MAct_gcamp_by_plane{m})

            warning('Skipping folder %s — MAct_gcamp_by_plane manquant.', gcamp_root_folders{m});
            return;
        end

        MAct_global = merge_MAct_planes(data.gcamp_plane.MAct_gcamp_by_plane{m}, Nz);

        disp(['Processing SCEs (CONCAT ALL PLANES) for folder: ', gcamp_root_folders{m}]);

        MinPeakDistancesce = 5;
        WinActive = [];

        try
            synchronous_frames = synchronous_frames_group{m};
            [~, date] = fileparts(date_group_paths{m});

            [sce_n_cells_threshold, TRace_gcamp, Race_gcamp, sces_distances_gcamp, RasterRace_gcamp] = ...
                select_synchronies( ...
                    gcamp_root_folders{m}, ...
                    synchronous_frames, ...
                    WinActive, ...
                    MAct_global, ...
                    MinPeakDistancesce, ...
                    Raster_global, ...
                    current_animal_group, ...
                    date);

            sce_metrics.Race_gcamp = Race_gcamp;
            sce_metrics.TRace_gcamp = TRace_gcamp;
            sce_metrics.sces_distances_gcamp = sces_distances_gcamp;
            sce_metrics.RasterRace_gcamp = RasterRace_gcamp;
            sce_metrics.sce_n_cells_threshold = sce_n_cells_threshold;

            save(filePath, ...
                'sce_n_cells_threshold', ...
                'TRace_gcamp', ...
                'Race_gcamp', ...
                'sces_distances_gcamp', ...
                'RasterRace_gcamp');

            disp(['SCEs processed and saved for folder: ', gcamp_root_folders{m}]);

        catch ME
            warning(['Error processing SCEs for folder: ', gcamp_root_folders{m}]);
            warning(['Message: ', ME.message]);
            return;
        end
    end

    sce_metrics = compute_sce_summary_metrics(sce_metrics);
end

function sce_metrics = compute_sce_summary_metrics(sce_metrics)

    sce_metrics.sce_frequency_per_min = NaN;
    sce_metrics.cell_participation_percent = [];
    sce_metrics.duration_ms = [];

    TRace_gcamp = sce_metrics.TRace_gcamp;

    if ~isempty(TRace_gcamp)

        TRace_gcamp = TRace_gcamp(:);

        if isfield(sce_metrics,'recording_duration_min') && ...
                ~isempty(sce_metrics.recording_duration_min) && ...
                sce_metrics.recording_duration_min > 0

            sce_metrics.sce_frequency_per_min = ...
                numel(TRace_gcamp) / sce_metrics.recording_duration_min;

        end

    else
        return;
    end

    RasterRace_gcamp = sce_metrics.RasterRace_gcamp;

    if ~isempty(RasterRace_gcamp)
        NCell_sce = size(RasterRace_gcamp, 1);

        if NCell_sce > 0
            valid_TRace = TRace_gcamp( ...
                TRace_gcamp >= 1 & ...
                TRace_gcamp <= size(RasterRace_gcamp, 2));

            cell_participation_percent = nan(numel(valid_TRace), 1);

            for i = 1:numel(valid_TRace)
                nbActives = sum(RasterRace_gcamp(:, valid_TRace(i)) == 1);
                cell_participation_percent(i) = 100 * nbActives / NCell_sce;
            end

            sce_metrics.cell_participation_percent = cell_participation_percent;
        end
    end

    sces_distances_gcamp = sce_metrics.sces_distances_gcamp;

    if ~isempty(sces_distances_gcamp) && size(sces_distances_gcamp, 2) >= 2
        sce_metrics.duration_ms = sces_distances_gcamp(:, 2);
        sce_metrics.duration_ms = sce_metrics.duration_ms(:);
        sce_metrics.duration_ms = sce_metrics.duration_ms(isfinite(sce_metrics.duration_ms));
    end
end

function value = get_metadata_value(metadata, fieldName, m)

    value = [];

    if isempty(metadata) || ~isstruct(metadata) || ~isfield(metadata, fieldName)
        return;
    end

    x = metadata.(fieldName);

    if iscell(x)
        if numel(x) >= m
            value = x{m};
        end
    else
        value = x;
    end
end

function v = parse_numeric_vector(x)

    v = [];

    if isempty(x)
        return;
    end

    if isnumeric(x)
        v = double(x(:).');
        v = v(isfinite(v));
        return;
    end

    if isstring(x)
        x = cellstr(x);
    end

    if ischar(x)
        v = sscanf(x, '%f').';
        v = double(v(:).');
        v = v(isfinite(v));
        return;
    end

    if iscell(x)
        tmp = [];

        for i = 1:numel(x)
            vi = parse_numeric_vector(x{i});

            if ~isempty(vi)
                tmp = [tmp, vi]; 
            end
        end

        v = tmp;
        v = v(isfinite(v));
        return;
    end
end

function metrics = compute_branch_metrics_by_plane( ...
    data, branchName, m, sampling_rate, dfField, rasterField)

    metrics = struct( ...
        'valid', false, ...
        'nCells_by_plane', {{}}, ...
        'nFrames_by_plane', {{}}, ...
        'freq_by_plane', {{}}, ...
        'intervals_ms_by_plane', {{}}, ...
        'burst_rate_by_plane', {{}}, ...
        'burst_fraction_by_plane', {{}}, ...
        'burst_size_by_plane', {{}});

    has_data = has_nonempty_plane_field_nested(data, branchName, dfField, m) && ...
               has_nonempty_plane_field_nested(data, branchName, rasterField, m);

    if ~has_data
        return;
    end

    DF_planes = get_planes_nested(data, branchName, m, dfField);
    Raster_planes = get_planes_nested(data, branchName, m, rasterField);

    nPlanes = max(numel(DF_planes), numel(Raster_planes));

    metrics.nCells_by_plane = cell(1, nPlanes);
    metrics.nFrames_by_plane = cell(1, nPlanes);
    metrics.freq_by_plane = cell(1, nPlanes);
    metrics.intervals_ms_by_plane = cell(1, nPlanes);
    metrics.burst_rate_by_plane = cell(1, nPlanes);
    metrics.burst_fraction_by_plane = cell(1, nPlanes);
    metrics.burst_size_by_plane = cell(1, nPlanes);

    for p = 1:nPlanes

        DF = [];
        Raster = [];

        if p <= numel(DF_planes)
            DF = DF_planes{p};
        end

        if p <= numel(Raster_planes)
            Raster = Raster_planes{p};
        end

        if isempty(DF) || isempty(Raster)
            continue;
        end

        [DF, Raster] = align_data(DF, Raster);

        if isempty(DF) || isempty(Raster)
            continue;
        end

        metrics.valid = true;

        metrics.nCells_by_plane{p} = size(Raster, 1);
        metrics.nFrames_by_plane{p} = size(Raster, 2);

        metrics.freq_by_plane{p} = ...
            compute_frequency_from_raster(Raster, sampling_rate);

        metrics.intervals_ms_by_plane{p} = ...
            compute_inter_event_intervals_from_raster(Raster, sampling_rate);

        [burst_rate, burst_fraction, burst_size] = ...
            compute_burst_metrics_from_raster(Raster, sampling_rate);

        metrics.burst_rate_by_plane{p} = burst_rate;
        metrics.burst_fraction_by_plane{p} = burst_fraction;
        metrics.burst_size_by_plane{p} = burst_size;
    end
end

function tf = has_nonempty_plane_field_nested(data, branchName, fieldName, m)

    tf = false;

    if ~isfield(data, branchName) || ~isstruct(data.(branchName))
        return;
    end

    branch = data.(branchName);

    if ~isfield(branch, fieldName)
        return;
    end

    if numel(branch.(fieldName)) < m || isempty(branch.(fieldName){m})
        return;
    end

    planes = branch.(fieldName){m};

    if ~iscell(planes)
        tf = ~isempty(planes);
        return;
    end

    for p = 1:numel(planes)
        if ~isempty(planes{p})
            tf = true;
            return;
        end
    end
end

function planes = get_planes_nested(data, branchName, m, fieldName)

    planes = {};

    if ~isfield(data, branchName) || ~isstruct(data.(branchName))
        return;
    end

    branch = data.(branchName);

    if ~isfield(branch, fieldName) || ...
       numel(branch.(fieldName)) < m || ...
       isempty(branch.(fieldName){m})
        return;
    end

    planes = branch.(fieldName){m};

    if ~iscell(planes)
        planes = {planes};
    end
end

function planes = get_planes_or_error_nested(data, branchName, m, fieldName)

    if ~isfield(data, branchName) || ~isstruct(data.(branchName))
        error('Session %d: branche "%s" manquante.', m, branchName);
    end

    branch = data.(branchName);

    if ~isfield(branch, fieldName) || ...
       numel(branch.(fieldName)) < m || ...
       isempty(branch.(fieldName){m})

        error('Session %d: champ "%s.%s" manquant ou vide.', ...
            m, branchName, fieldName);
    end

    planes = branch.(fieldName){m};

    if ~iscell(planes) || isempty(planes)
        error('Session %d: "%s.%s{%d}" doit être une cell non vide de plans.', ...
            m, branchName, fieldName, m);
    end
end

function [DF, Raster] = align_data(DF, Raster)

    min_cells = min(size(DF, 1), size(Raster, 1));
    min_frames = min(size(DF, 2), size(Raster, 2));

    DF = DF(1:min_cells, 1:min_frames);
    Raster = Raster(1:min_cells, 1:min_frames);
end

function freq_per_cell_per_min = compute_frequency_from_raster(Raster, sampling_rate)

    if isempty(Raster) || sampling_rate <= 0
        freq_per_cell_per_min = [];
        return;
    end

    Raster = Raster ~= 0;
    [nCells, nFrames] = size(Raster);

    duration_min = (nFrames / sampling_rate) / 60;

    if duration_min <= 0
        freq_per_cell_per_min = nan(nCells, 1);
        return;
    end

    nEvents = sum(Raster, 2);
    freq_per_cell_per_min = nEvents ./ duration_min;
end

function intervals_ms = compute_inter_event_intervals_from_raster(Raster, sampling_rate)

    intervals_ms = [];

    if isempty(Raster) || sampling_rate <= 0
        return;
    end

    Raster = Raster ~= 0;
    nCells = size(Raster, 1);

    for c = 1:nCells

        event_frames = find(Raster(c, :) > 0);

        if numel(event_frames) < 2
            continue;
        end

        cell_intervals = diff(event_frames) ./ sampling_rate * 1000;
        intervals_ms = [intervals_ms; cell_intervals(:)]; 
    end

    intervals_ms = intervals_ms(isfinite(intervals_ms));
end

function [burst_rate_per_cell_per_min, burst_fraction_per_cell, burst_size_all] = ...
    compute_burst_metrics_from_raster(Raster, sampling_rate)

    burst_rate_per_cell_per_min = [];
    burst_fraction_per_cell = [];
    burst_size_all = [];

    if isempty(Raster) || sampling_rate <= 0
        return;
    end

    Raster = Raster ~= 0;

    max_iei_ms = 1000;
    min_events_per_burst = 3;

    max_iei_frames = round((max_iei_ms / 1000) * sampling_rate);

    [nCells, nFrames] = size(Raster);
    duration_min = (nFrames / sampling_rate) / 60;

    burst_rate_per_cell_per_min = nan(nCells, 1);
    burst_fraction_per_cell = nan(nCells, 1);

    for c = 1:nCells

        event_frames = find(Raster(c, :) > 0);
        nEvents = numel(event_frames);

        if nEvents < min_events_per_burst || duration_min <= 0
            burst_rate_per_cell_per_min(c) = 0;
            burst_fraction_per_cell(c) = 0;
            continue;
        end

        d = diff(event_frames);

        burst_sizes = [];
        current_size = 1;

        for i = 1:numel(d)

            if d(i) <= max_iei_frames
                current_size = current_size + 1;
            else
                if current_size >= min_events_per_burst
                    burst_sizes(end+1, 1) = current_size; 
                end

                current_size = 1;
            end
        end

        if current_size >= min_events_per_burst
            burst_sizes(end+1, 1) = current_size; 
        end

        nBursts = numel(burst_sizes);

        burst_rate_per_cell_per_min(c) = nBursts / duration_min;

        if nEvents > 0
            burst_fraction_per_cell(c) = sum(burst_sizes) / nEvents;
        else
            burst_fraction_per_cell(c) = NaN;
        end

        burst_size_all = [burst_size_all; burst_sizes(:)]; 
    end

    burst_size_all = burst_size_all(isfinite(burst_size_all));
end

function out = concat_planes_local_nested(data, branchName, m, fieldName, mode)

    out = [];

    if ~isfield(data, branchName) || ~isstruct(data.(branchName))
        return;
    end

    branch = data.(branchName);

    if ~isfield(branch, fieldName) || ...
       numel(branch.(fieldName)) < m || ...
       isempty(branch.(fieldName){m})
        return;
    end

    planes = branch.(fieldName){m};

    if ~iscell(planes)
        return;
    end

    for p = 1:numel(planes)

        X = planes{p};

        if isempty(X)
            continue;
        end

        switch lower(mode)

            case 'numeric'
                if ~(isnumeric(X) || islogical(X))
                    warning('Type non supporté pour %s.%s plan %d (%s).', ...
                        branchName, fieldName, p, class(X));
                    continue;
                end
                X = double(X);

            case 'logical'
                if ~(islogical(X) || isnumeric(X))
                    warning('Type non supporté pour %s.%s plan %d (%s).', ...
                        branchName, fieldName, p, class(X));
                    continue;
                end
                X = X ~= 0;

            otherwise
                error('Mode inconnu "%s".', mode);
        end

        if isempty(out)
            out = X;
        else
            minFrames = min(size(out, 2), size(X, 2));
            out = out(:, 1:minFrames);
            X = X(:, 1:minFrames);
            out = [out; X]; 
        end
    end
end

function MAct_sum = merge_MAct_planes(MAct_cell, Nz)

    MAct_sum = zeros(1, Nz);

    if isempty(MAct_cell)
        return;
    end

    for p = 1:numel(MAct_cell)

        M = MAct_cell{p};

        if isempty(M)
            continue;
        end

        M = resize_MAct(M, Nz);
        MAct_sum = MAct_sum + M;
    end
end

function MAct_out = resize_MAct(MAct_in, Nz)

    if isempty(MAct_in)
        MAct_out = zeros(1, Nz);
        return;
    end

    MAct_in = MAct_in(:)';

    if numel(MAct_in) > Nz
        MAct_out = MAct_in(1:Nz);
    elseif numel(MAct_in) < Nz
        MAct_out = [MAct_in, zeros(1, Nz - numel(MAct_in))];
    else
        MAct_out = MAct_in;
    end
end

function value = getFieldOrDefault(structure, fieldName, defaultValue)

    if isfield(structure, fieldName)
        value = structure.(fieldName);
    else
        value = defaultValue;
    end
end

function c = ensure_plane_cell(c, nPlanes)

    if isempty(c) || ~iscell(c)
        c = cell(1, nPlanes);
        return;
    end

    c = c(:).';

    if numel(c) > nPlanes
        c = c(1:nPlanes);
    elseif numel(c) < nPlanes
        c = [c, cell(1, nPlanes - numel(c))];
    end
end

function metrics = empty_branch_metrics()

    metrics = struct( ...
        'valid', false, ...
        'nCells_by_plane', {{}}, ...
        'nFrames_by_plane', {{}}, ...
        'freq_by_plane', {{}}, ...
        'intervals_ms_by_plane', {{}}, ...
        'burst_rate_by_plane', {{}}, ...
        'burst_fraction_by_plane', {{}}, ...
        'burst_size_by_plane', {{}});
end