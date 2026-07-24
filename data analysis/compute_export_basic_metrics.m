function [results_analysis, results_table] = compute_export_basic_metrics( ...
    current_type, ...
    current_animal_group, ...
    current_ages, ...
    gcamp_root_folders, ...
    date_group_paths, ...
    synchronous_frames_group, ...
    data, ...
    metadata, ...
    include_blue_cells)
% COMPUTE_EXPORT_BASIC_METRICS
% Calcule les métriques de chaque enregistrement et les ajoute directement
% à une table longue destinée aux figures et aux modèles statistiques.
%
% Une ligne correspond à une métrique résumée pour :
%   - un animal ;
%   - un âge ;
%   - une date/enregistrement ;
%   - un plan, lorsque la métrique est calculée par plan ;
%   - une branche et une métrique.
%
% Les vecteurs cellulaires, les intervalles, les bursts, les corrélations
% et les valeurs par SCE sont résumés par leur moyenne. La colonne N indique
% combien de valeurs finies ont servi à calculer cette moyenne.

    nRec = numel(gcamp_root_folders);

    if nargin < 9 || isempty(include_blue_cells)
        include_blue_cells = '1';
    end

    include_blue_cells = char(string(include_blue_cells));
    process_blue = strcmp(include_blue_cells, '1');

    current_type = string(current_type);
    current_animal_group = string(current_animal_group);

    results_analysis = init_empty_results_analysis(nRec);
    results_table = init_results_table();

    for m = 1:nRec

        date_name = get_date_name_from_path(date_group_paths, m);
        age_label = get_age_for_recording(current_ages, m);
        age_number = extract_age_number(age_label);
        session_id = current_animal_group + "_" + date_name + "_rec" + string(m);

        try
            sampling_rate = get_metadata_value(metadata, 'SamplingRatePlane', m);
            sampling_rate = parse_numeric_vector(sampling_rate);

            if isempty(sampling_rate)
                error('SamplingRatePlane vide pour rec %d', m);
            end

            sampling_rate = sampling_rate(1);


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
            % Basic metrics mTOR-electroporated cells
            %======================================================
            if process_blue
                blue_metrics = compute_branch_metrics_by_plane( ...
                    data, 'blue_plane', m, sampling_rate, ...
                    'DF_blue_by_plane', ...
                    'Raster_blue_by_plane');
            else
                blue_metrics = empty_branch_metrics();
            end

            %======================================================
            % Pairwise correlations
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
            % Detailed results structure
            %======================================================
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
            results_analysis.gcamp_plane.max_corr_gcamp_gcamp_by_plane{m} = ...
                corr_metrics.max_corr_gcamp_gcamp_by_plane;
            results_analysis.blue_plane.max_corr_gcamp_mtor_by_plane{m} = ...
                corr_metrics.max_corr_gcamp_mtor_by_plane;
            results_analysis.blue_plane.max_corr_mtor_mtor_by_plane{m} = ...
                corr_metrics.max_corr_mtor_mtor_by_plane;

            results_analysis.SCEs.Race_gcamp{m} = sce_metrics.Race_gcamp;
            results_analysis.SCEs.TRace_gcamp{m} = sce_metrics.TRace_gcamp;
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
            results_analysis.SCEs.Duration_ms{m} = sce_metrics.duration_ms;
            results_analysis.SCEs.Number{m} = sce_metrics.number;
            results_analysis.SCEs.RecordingDuration_min{m} = ...
                sce_metrics.recording_duration_min;
            results_analysis.SCEs.InterSCEIntervals_ms{m} = ...
                sce_metrics.inter_sce_intervals_ms;
            results_analysis.SCEs.MeanCellParticipation_percent{m} = ...
                sce_metrics.mean_cell_participation_percent;
            results_analysis.SCEs.MedianCellParticipation_percent{m} = ...
                sce_metrics.median_cell_participation_percent;
            results_analysis.SCEs.MeanDuration_ms{m} = ...
                sce_metrics.mean_duration_ms;
            results_analysis.SCEs.MedianDuration_ms{m} = ...
                sce_metrics.median_duration_ms;

            %======================================================
            % GCaMP metrics, one row per plane
            %======================================================
            results_table = append_values_by_plane( ...
                results_table, current_type, current_animal_group, ...
                age_label, age_number, date_name, session_id, m, ...
                "gcamp_plane", "ActiveCellsNumber", ...
                gcamp_metrics.nCells_by_plane, "cells");

            results_table = append_values_by_plane( ...
                results_table, current_type, current_animal_group, ...
                age_label, age_number, date_name, session_id, m, ...
                "gcamp_plane", "FrequencyPerCell", ...
                gcamp_metrics.freq_by_plane, "events/min");

            results_table = append_values_by_plane( ...
                results_table, current_type, current_animal_group, ...
                age_label, age_number, date_name, session_id, m, ...
                "gcamp_plane", "InterEventIntervals", ...
                gcamp_metrics.intervals_ms_by_plane, "ms");

            results_table = append_values_by_plane( ...
                results_table, current_type, current_animal_group, ...
                age_label, age_number, date_name, session_id, m, ...
                "gcamp_plane", "BurstRate", ...
                gcamp_metrics.burst_rate_by_plane, "bursts/min");

            results_table = append_values_by_plane( ...
                results_table, current_type, current_animal_group, ...
                age_label, age_number, date_name, session_id, m, ...
                "gcamp_plane", "BurstFraction", ...
                gcamp_metrics.burst_fraction_by_plane, "fraction");

            results_table = append_values_by_plane( ...
                results_table, current_type, current_animal_group, ...
                age_label, age_number, date_name, session_id, m, ...
                "gcamp_plane", "BurstSize", ...
                gcamp_metrics.burst_size_by_plane, "events/burst");

            results_table = append_values_by_plane( ...
                results_table, current_type, current_animal_group, ...
                age_label, age_number, date_name, session_id, m, ...
                "gcamp_plane", "PairwiseCorrelation_GCaMP_GCaMP", ...
                corr_metrics.max_corr_gcamp_gcamp_by_plane, "correlation");

            %======================================================
            % mTOR-electroporated-cell metrics, one row per plane
            %======================================================
            if process_blue && blue_metrics.valid
                results_table = append_values_by_plane( ...
                    results_table, current_type, current_animal_group, ...
                    age_label, age_number, date_name, session_id, m, ...
                    "blue_plane", "ActiveCellsNumber", ...
                    blue_metrics.nCells_by_plane, "cells");

                results_table = append_values_by_plane( ...
                    results_table, current_type, current_animal_group, ...
                    age_label, age_number, date_name, session_id, m, ...
                    "blue_plane", "FrequencyPerCell", ...
                    blue_metrics.freq_by_plane, "events/min");

                results_table = append_values_by_plane( ...
                    results_table, current_type, current_animal_group, ...
                    age_label, age_number, date_name, session_id, m, ...
                    "blue_plane", "InterEventIntervals", ...
                    blue_metrics.intervals_ms_by_plane, "ms");

                results_table = append_values_by_plane( ...
                    results_table, current_type, current_animal_group, ...
                    age_label, age_number, date_name, session_id, m, ...
                    "blue_plane", "BurstRate", ...
                    blue_metrics.burst_rate_by_plane, "bursts/min");

                results_table = append_values_by_plane( ...
                    results_table, current_type, current_animal_group, ...
                    age_label, age_number, date_name, session_id, m, ...
                    "blue_plane", "BurstFraction", ...
                    blue_metrics.burst_fraction_by_plane, "fraction");

                results_table = append_values_by_plane( ...
                    results_table, current_type, current_animal_group, ...
                    age_label, age_number, date_name, session_id, m, ...
                    "blue_plane", "BurstSize", ...
                    blue_metrics.burst_size_by_plane, "events/burst");
            end

            if process_blue
                results_table = append_values_by_plane( ...
                    results_table, current_type, current_animal_group, ...
                    age_label, age_number, date_name, session_id, m, ...
                    "blue_plane", "PairwiseCorrelation_GCaMP_mTOR", ...
                    corr_metrics.max_corr_gcamp_mtor_by_plane, "correlation");

                results_table = append_values_by_plane( ...
                    results_table, current_type, current_animal_group, ...
                    age_label, age_number, date_name, session_id, m, ...
                    "blue_plane", "PairwiseCorrelation_mTOR_mTOR", ...
                    corr_metrics.max_corr_mtor_mtor_by_plane, "correlation");
            end

            %======================================================
            % SCE metrics, one row per recording
            % Plane is NaN because SCEs are computed after concatenating
            % all GCaMP planes.
            %======================================================
            results_table = append_session_value( ...
                results_table, current_type, current_animal_group, ...
                age_label, age_number, date_name, session_id, m, ...
                "SCEs", "Frequency", ...
                sce_metrics.sce_frequency_per_min, "SCEs/min");

            results_table = append_session_value( ...
                results_table, current_type, current_animal_group, ...
                age_label, age_number, date_name, session_id, m, ...
                "SCEs", "CellParticipation", ...
                sce_metrics.cell_participation_percent, "%");

            results_table = append_session_value( ...
                results_table, current_type, current_animal_group, ...
                age_label, age_number, date_name, session_id, m, ...
                "SCEs", "Duration", ...
                sce_metrics.duration_ms, "ms");

            results_table = append_session_value( ...
                results_table, current_type, current_animal_group, ...
                age_label, age_number, date_name, session_id, m, ...
                "SCEs", "DetectionThreshold", ...
                sce_metrics.sce_n_cells_threshold, "cells");

        catch ME
            fprintf('Error processing rec %d: %s\n', m, ME.message);
        end
    end

    if ~isempty(results_table)
        results_table = sortrows(results_table, ...
            {'Type','Animal','AgeNumber','RecordingIndex', ...
             'Plane','Branch','Metric'});
    end
end

function results_analysis = init_empty_results_analysis(nRec)

    results_analysis = struct( ...
        'gcamp_plane', struct(), ...
        'blue_plane', struct(), ...
        'SCEs', struct());

    % GCaMP metrics retained at recording level, with one entry per plane.
    results_analysis.gcamp_plane.FrequencyPerCell = cell(nRec, 1);
    results_analysis.gcamp_plane.InterEventIntervals_ms = cell(nRec, 1);
    results_analysis.gcamp_plane.BurstRate_per_min = cell(nRec, 1);
    results_analysis.gcamp_plane.BurstFraction = cell(nRec, 1);
    results_analysis.gcamp_plane.BurstSize = cell(nRec, 1);
    results_analysis.gcamp_plane.max_corr_gcamp_gcamp_by_plane = cell(nRec, 1);

    % mTOR-electroporated-cell metrics retained at recording level.y
    results_analysis.blue_plane.FrequencyPerCell = cell(nRec, 1);
    results_analysis.blue_plane.InterEventIntervals_ms = cell(nRec, 1);
    results_analysis.blue_plane.BurstRate_per_min = cell(nRec, 1);
    results_analysis.blue_plane.BurstFraction = cell(nRec, 1);
    results_analysis.blue_plane.BurstSize = cell(nRec, 1);
    results_analysis.blue_plane.max_corr_gcamp_mtor_by_plane = cell(nRec, 1);
    results_analysis.blue_plane.max_corr_mtor_mtor_by_plane = cell(nRec, 1);


    % Detailed and summarized SCE outputs.
    results_analysis.SCEs.Race_gcamp = cell(nRec, 1);
    results_analysis.SCEs.TRace_gcamp = cell(nRec, 1);
    results_analysis.SCEs.sces_distances_gcamp = cell(nRec, 1);
    results_analysis.SCEs.RasterRace_gcamp = cell(nRec, 1);
    results_analysis.SCEs.sce_n_cells_threshold = cell(nRec, 1);
    results_analysis.SCEs.Threshold = cell(nRec, 1);
    results_analysis.SCEs.Frequency = cell(nRec, 1);
    results_analysis.SCEs.CellParticipation_percent = cell(nRec, 1);
    results_analysis.SCEs.Duration_ms = cell(nRec, 1);
    results_analysis.SCEs.Number = cell(nRec, 1);
    results_analysis.SCEs.RecordingDuration_min = cell(nRec, 1);
    results_analysis.SCEs.InterSCEIntervals_ms = cell(nRec, 1);
    results_analysis.SCEs.MeanCellParticipation_percent = cell(nRec, 1);
    results_analysis.SCEs.MedianCellParticipation_percent = cell(nRec, 1);
    results_analysis.SCEs.MeanDuration_ms = cell(nRec, 1);
    results_analysis.SCEs.MedianDuration_ms = cell(nRec, 1);
end

function results_table = init_results_table()

    results_table = table( ...
        string.empty(0,1), ... % Type
        string.empty(0,1), ... % Animal
        string.empty(0,1), ... % Age
        nan(0,1), ...          % AgeNumber
        string.empty(0,1), ... % Date
        string.empty(0,1), ... % SessionID
        nan(0,1), ...          % RecordingIndex
        nan(0,1), ...          % Plane
        string.empty(0,1), ... % Branch
        string.empty(0,1), ... % Metric
        nan(0,1), ...          % Value
        nan(0,1), ...          % N
        string.empty(0,1), ... % Unit
        'VariableNames', { ...
            'Type', ...
            'Animal', ...
            'Age', ...
            'AgeNumber', ...
            'Date', ...
            'SessionID', ...
            'RecordingIndex', ...
            'Plane', ...
            'Branch', ...
            'Metric', ...
            'Value', ...
            'N', ...
            'Unit'});
end

function results_table = append_values_by_plane( ...
    results_table, current_type, animal_id, age_label, age_number, ...
    date_name, session_id, recording_index, branch_name, metric_name, ...
    values_by_plane, unit_name)

    values_by_plane = normalize_values_by_plane(values_by_plane);

    for p = 1:numel(values_by_plane)
        [metric_value, n_values] = summarize_numeric_values(values_by_plane{p});

        if ~isfinite(metric_value)
            continue;
        end

        row = make_results_row( ...
            current_type, animal_id, age_label, age_number, ...
            date_name, session_id, recording_index, p, ...
            branch_name, metric_name, metric_value, n_values, unit_name);

        results_table = [results_table; row]; %#ok<AGROW>
    end
end

function results_table = append_session_value( ...
    results_table, current_type, animal_id, age_label, age_number, ...
    date_name, session_id, recording_index, branch_name, metric_name, ...
    values, unit_name)

    [metric_value, n_values] = summarize_numeric_values(values);

    if ~isfinite(metric_value)
        return;
    end

    row = make_results_row( ...
        current_type, animal_id, age_label, age_number, ...
        date_name, session_id, recording_index, NaN, ...
        branch_name, metric_name, metric_value, n_values, unit_name);

    results_table = [results_table; row];
end

function row = make_results_row( ...
    current_type, animal_id, age_label, age_number, date_name, ...
    session_id, recording_index, plane_number, branch_name, ...
    metric_name, metric_value, n_values, unit_name)

    row = table( ...
        string(current_type), ...
        string(animal_id), ...
        string(age_label), ...
        double(age_number), ...
        string(date_name), ...
        string(session_id), ...
        double(recording_index), ...
        double(plane_number), ...
        string(branch_name), ...
        string(metric_name), ...
        double(metric_value), ...
        double(n_values), ...
        string(unit_name), ...
        'VariableNames', { ...
            'Type', ...
            'Animal', ...
            'Age', ...
            'AgeNumber', ...
            'Date', ...
            'SessionID', ...
            'RecordingIndex', ...
            'Plane', ...
            'Branch', ...
            'Metric', ...
            'Value', ...
            'N', ...
            'Unit'});
end

function values_by_plane = normalize_values_by_plane(values)

    if isempty(values)
        values_by_plane = {};
    elseif iscell(values)
        values_by_plane = values(:).';
    elseif isnumeric(values) || islogical(values)
        if isvector(values) && numel(values) > 1
            values_by_plane = num2cell(values(:).');
        else
            values_by_plane = {values};
        end
    else
        values_by_plane = {};
    end
end

function [mean_value, n_values] = summarize_numeric_values(values)

    mean_value = NaN;
    n_values = 0;

    if isempty(values)
        return;
    end

    if iscell(values)
        combined = [];

        for i = 1:numel(values)
            current = values{i};

            if isnumeric(current) || islogical(current)
                combined = [combined; double(current(:))]; %#ok<AGROW>
            end
        end

        values = combined;
    end

    if ~(isnumeric(values) || islogical(values))
        return;
    end

    values = double(values(:));
    values = values(isfinite(values));
    n_values = numel(values);

    if n_values > 0
        mean_value = mean(values, 'omitnan');
    end
end

function date_name = get_date_name_from_path(date_group_paths, m)

    date_name = "";

    if isempty(date_group_paths) || ...
       numel(date_group_paths) < m || ...
       isempty(date_group_paths{m})
        return;
    end

    [~, current_date] = fileparts(date_group_paths{m});
    date_name = string(current_date);
end

function age_label = get_age_for_recording(current_ages, m)

    age_label = "";

    if isempty(current_ages)
        return;
    end

    if iscell(current_ages)
        if numel(current_ages) >= m
            age_label = string(current_ages{m});
        end
    elseif isstring(current_ages)
        if numel(current_ages) >= m
            age_label = current_ages(m);
        elseif isscalar(current_ages)
            age_label = current_ages;
        end
    elseif ischar(current_ages)
        age_label = string(current_ages);
    elseif isnumeric(current_ages)
        if numel(current_ages) >= m
            age_label = "P" + string(current_ages(m));
        elseif isscalar(current_ages)
            age_label = "P" + string(current_ages);
        end
    end
end

function age_number = extract_age_number(age_label)

    age_number = NaN;

    if strlength(string(age_label)) == 0
        return;
    end

    token = regexp(char(string(age_label)), ...
        '[-+]?\d*\.?\d+', 'match', 'once');

    if ~isempty(token)
        age_number = str2double(token);
    end
end

function corr_metrics = load_or_process_corr_for_session(gcamp_root_folders, data, m, include_blue_cells)
    
    if nargin < 4 || isempty(include_blue_cells)
        include_blue_cells = '1';
    end
    
    include_blue_cells = char(string(include_blue_cells));
    process_blue_combined = strcmp(include_blue_cells, '1');

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
        'duration_ms', [], ...
        'number', 0, ...
        'recording_duration_min', NaN, ...
        'inter_sce_intervals_ms', [], ...
        'mean_cell_participation_percent', NaN, ...
        'median_cell_participation_percent', NaN, ...
        'mean_duration_ms', NaN, ...
        'median_duration_ms', NaN);

    if isempty(gcamp_root_folders) || ...
       m > numel(gcamp_root_folders) || ...
       isempty(gcamp_root_folders{m})
        fprintf('Session %d: gcamp_root_folders vide, skip SCEs.\n', m);
        return;
    end

    filePath = fullfile(gcamp_root_folders{m}, 'results_SCEs.mat');

    Raster_global_for_duration = concat_planes_local_nested( ...
    data, 'gcamp_plane', m, 'Raster_gcamp_by_plane', 'logical');

    if isempty(Raster_global_for_duration) || ...
       ~isfinite(sampling_rate) || ...
       sampling_rate <= 0
    
        sce_metrics.recording_duration_min = NaN;
    
    else
    
        nFrames = size(Raster_global_for_duration, 2);
    
        bad_frame_mask = get_bad_frame_mask( ...
            data, m, nFrames);
    
        nBadFrames = nnz(bad_frame_mask);
        nValidFrames = nFrames - nBadFrames;
    
        sce_metrics.recording_duration_min = ...
            nValidFrames / sampling_rate / 60;
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

    sce_metrics = compute_sce_summary_metrics(sce_metrics, sampling_rate);
end

function sce_metrics = compute_sce_summary_metrics(sce_metrics, sampling_rate)

    sce_metrics.sce_frequency_per_min = NaN;
    sce_metrics.cell_participation_percent = [];
    sce_metrics.duration_ms = [];
    sce_metrics.number = 0;
    sce_metrics.inter_sce_intervals_ms = [];
    sce_metrics.mean_cell_participation_percent = NaN;
    sce_metrics.median_cell_participation_percent = NaN;
    sce_metrics.mean_duration_ms = NaN;
    sce_metrics.median_duration_ms = NaN;

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

    sce_metrics.number = numel(TRace_gcamp);

    if numel(TRace_gcamp) >= 2 && isfinite(sampling_rate) && sampling_rate > 0
        sce_metrics.inter_sce_intervals_ms = ...
            diff(double(TRace_gcamp(:))) ./ sampling_rate .* 1000;
    end

    finite_participation = sce_metrics.cell_participation_percent;
    finite_participation = finite_participation(isfinite(finite_participation));

    if ~isempty(finite_participation)
        sce_metrics.mean_cell_participation_percent = ...
            mean(finite_participation, 'omitnan');
        sce_metrics.median_cell_participation_percent = ...
            median(finite_participation, 'omitnan');
    end

    finite_duration = sce_metrics.duration_ms;
    finite_duration = finite_duration(isfinite(finite_duration));

    if ~isempty(finite_duration)
        sce_metrics.mean_duration_ms = mean(finite_duration, 'omitnan');
        sce_metrics.median_duration_ms = median(finite_duration, 'omitnan');
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
        'nValidFrames_by_plane', {{}}, ...
        'nBadFrames_by_plane', {{}}, ...
        'duration_min_by_plane', {{}}, ...
        'freq_by_plane', {{}}, ...
        'intervals_ms_by_plane', {{}}, ...
        'burst_rate_by_plane', {{}}, ...
        'burst_fraction_by_plane', {{}}, ...
        'burst_size_by_plane', {{}});

    has_data = ...
        has_nonempty_plane_field_nested(data, branchName, dfField, m) && ...
        has_nonempty_plane_field_nested(data, branchName, rasterField, m);

    if ~has_data
        return;
    end

    DF_planes = get_planes_nested(data, branchName, m, dfField);
    Raster_planes = get_planes_nested(data, branchName, m, rasterField);

    nPlanes = max(numel(DF_planes), numel(Raster_planes));

    metrics.nCells_by_plane = cell(1, nPlanes);
    metrics.nFrames_by_plane = cell(1, nPlanes);
    metrics.nValidFrames_by_plane = cell(1, nPlanes);
    metrics.nBadFrames_by_plane = cell(1, nPlanes);
    metrics.duration_min_by_plane = cell(1, nPlanes);
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

        nFrames = size(Raster, 2);

        bad_frame_mask = get_bad_frame_mask(data, m, nFrames);
        nBadFrames = nnz(bad_frame_mask);
        nValidFrames = nFrames - nBadFrames;

        if isfinite(sampling_rate) && sampling_rate > 0
            duration_min = nValidFrames / sampling_rate / 60;
        else
            duration_min = NaN;
        end

        metrics.nCells_by_plane{p} = size(Raster, 1);
        metrics.nFrames_by_plane{p} = nFrames;
        metrics.nBadFrames_by_plane{p} = nBadFrames;
        metrics.nValidFrames_by_plane{p} = nValidFrames;
        metrics.duration_min_by_plane{p} = duration_min;

        metrics.freq_by_plane{p} = ...
            compute_frequency_from_raster( ...
                Raster, sampling_rate, bad_frame_mask);

        metrics.intervals_ms_by_plane{p} = ...
            compute_inter_event_intervals_from_raster( ...
                Raster, sampling_rate);

        [burst_rate, burst_fraction, burst_size] = ...
            compute_burst_metrics_from_raster( ...
                Raster, sampling_rate, bad_frame_mask);

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

function freq_per_cell_per_min = compute_frequency_from_raster( ...
    Raster, sampling_rate, bad_frame_mask)

    if isempty(Raster) || ...
       ~isfinite(sampling_rate) || ...
       sampling_rate <= 0

        freq_per_cell_per_min = [];
        return;
    end

    Raster = Raster ~= 0;

    [nCells, nFrames] = size(Raster);

    if nargin < 3 || isempty(bad_frame_mask)
        bad_frame_mask = false(1, nFrames);
    else
        bad_frame_mask = logical(bad_frame_mask(:).');

        if numel(bad_frame_mask) < nFrames
            bad_frame_mask(end + 1:nFrames) = false;
        elseif numel(bad_frame_mask) > nFrames
            bad_frame_mask = bad_frame_mask(1:nFrames);
        end
    end

    nValidFrames = nFrames - nnz(bad_frame_mask);
    duration_min = nValidFrames / sampling_rate / 60;

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

function [burst_rate_per_cell_per_min, ...
          burst_fraction_per_cell, ...
          burst_size_all] = ...
    compute_burst_metrics_from_raster( ...
        Raster, sampling_rate, bad_frame_mask)

    burst_rate_per_cell_per_min = [];
    burst_fraction_per_cell = [];
    burst_size_all = [];

    if isempty(Raster) || ...
       ~isfinite(sampling_rate) || ...
       sampling_rate <= 0
        return;
    end

    Raster = Raster ~= 0;

    max_iei_ms = 1000;
    min_events_per_burst = 3;

    max_iei_frames = round( ...
        (max_iei_ms / 1000) * sampling_rate);

    [nCells, nFrames] = size(Raster);

    if nargin < 3 || isempty(bad_frame_mask)
        bad_frame_mask = false(1, nFrames);
    else
        bad_frame_mask = logical(bad_frame_mask(:).');

        if numel(bad_frame_mask) < nFrames
            bad_frame_mask(end + 1:nFrames) = false;
        elseif numel(bad_frame_mask) > nFrames
            bad_frame_mask = bad_frame_mask(1:nFrames);
        end
    end

    nValidFrames = nFrames - nnz(bad_frame_mask);
    duration_min = nValidFrames / sampling_rate / 60;
    
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
                    burst_sizes(end + 1, 1) = current_size; %#ok<AGROW>
                end

                current_size = 1;
            end
        end

        if current_size >= min_events_per_burst
            burst_sizes(end + 1, 1) = current_size; %#ok<AGROW>
        end

        nBursts = numel(burst_sizes);

        burst_rate_per_cell_per_min(c) = ...
            nBursts / duration_min;

        if nEvents > 0
            burst_fraction_per_cell(c) = ...
                sum(burst_sizes) / nEvents;
        else
            burst_fraction_per_cell(c) = NaN;
        end

        burst_size_all = [ ...
            burst_size_all; ...
            burst_sizes(:)]; %#ok<AGROW>
    end

    burst_size_all = ...
        burst_size_all(isfinite(burst_size_all));
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

function bad_frame_mask = get_bad_frame_mask(data, m, nFrames)
%GET_BAD_FRAME_MASK
% Retourne un masque logique 1 x nFrames.
%
% Formats acceptés dans data.motion.bad_frames_group{m} :
%   - masque logique ;
%   - vecteur numérique de 0 et 1 ;
%   - liste d'indices de frames ;
%   - cellule contenant un ou plusieurs de ces formats.

    bad_frame_mask = false(1, nFrames);

    if nargin < 3 || isempty(nFrames) || nFrames <= 0
        return;
    end

    if ~isstruct(data) || ...
       ~isfield(data, 'motion') || ...
       ~isstruct(data.motion) || ...
       ~isfield(data.motion, 'bad_frames_group') || ...
       isempty(data.motion.bad_frames_group) || ...
       numel(data.motion.bad_frames_group) < m

        return;
    end

    bad_frames = data.motion.bad_frames_group{m};

    if isempty(bad_frames)
        return;
    end

    bad_frame_mask = convert_bad_frames_to_mask( ...
        bad_frames, nFrames);
end

function bad_frame_mask = convert_bad_frames_to_mask( ...
    bad_frames, nFrames)

    bad_frame_mask = false(1, nFrames);

    if isempty(bad_frames)
        return;
    end

    if iscell(bad_frames)

        for i = 1:numel(bad_frames)
            current_mask = convert_bad_frames_to_mask( ...
                bad_frames{i}, nFrames);

            bad_frame_mask = ...
                bad_frame_mask | current_mask;
        end

        return;
    end

    if islogical(bad_frames)

        bad_frames = bad_frames(:).';

        nCopy = min(numel(bad_frames), nFrames);

        bad_frame_mask(1:nCopy) = ...
            bad_frames(1:nCopy);

        return;
    end

    if ~isnumeric(bad_frames)
        return;
    end

    bad_frames = double(bad_frames(:).');
    bad_frames = bad_frames(isfinite(bad_frames));

    if isempty(bad_frames)
        return;
    end

    % Un vecteur de même longueur constitué uniquement de 0 et 1
    % est interprété comme un masque.
    is_binary_mask = ...
        numel(bad_frames) == nFrames && ...
        all(bad_frames == 0 | bad_frames == 1);

    if is_binary_mask
        bad_frame_mask = logical(bad_frames);
        return;
    end

    % Sinon, les valeurs sont interprétées comme des indices MATLAB.
    bad_indices = unique(round(bad_frames));
    bad_indices = bad_indices( ...
        bad_indices >= 1 & ...
        bad_indices <= nFrames);

    bad_frame_mask(bad_indices) = true;
end