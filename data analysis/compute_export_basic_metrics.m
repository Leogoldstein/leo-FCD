function results_analysis = compute_export_basic_metrics(gcamp_output_folders, data, sampling_rate_group, current_env_group)

    nRec = numel(gcamp_output_folders);

    % -------------------------------
    % results_analysis: full distributions
    % -------------------------------
    field_order = { ...
        'NumFrames', ...
        'ZPosition_um', ...
        'ActiveCellsNumber', ...
        'ActiveCellsNumberBlue', ...
        'FrequencyPerCell_gcamp', ...
        'FrequencyPerCell_blue', ...
        'DurationPerCell_gcamp_s', ...
        'DurationPerCell_blue_s', ...
        'AmplitudePerCell_gcamp', ...
        'AmplitudePerCell_blue', ...
        'SCEsThreshold', ...
        'SCEsNumber', ...
        'SCEsCellParticipation_percent', ...
        'SCEsduration_ms' ...
        };

    results_analysis = repmat( ...
        cell2struct(repmat({[]}, 1, numel(field_order)), field_order, 2), ...
        nRec, 1);

    for m = 1:nRec
        try
            sampling_rate = sampling_rate_group{m};

            % ==========================================================
            % 0) Z position
            % ==========================================================
            z_position_um = NaN;

            try
                [~, ~, ~, ~, position, ~, ~, ~] = find_key_value(current_env_group{m});

                if ~isempty(position)
                    if isscalar(position)
                        z_position_um = position;
                    elseif isnumeric(position)
                        position = position(:);
                        position = position(isfinite(position));
                        if ~isempty(position)
                            z_position_um = mean(position, 'omitnan');
                        end
                    end
                end
            catch
                z_position_um = NaN;
            end

            % ==========================================================
            % 1) GCaMP
            % ==========================================================
            gcamp_metrics = compute_branch_metrics( ...
                data, 'gcamp_plane', m, sampling_rate, ...
                'DF_gcamp_by_plane', ...
                'Raster_gcamp_by_plane', ...
                'Acttmp2_gcamp_by_plane', ...
                'StartEnd_gcamp_by_plane');

            if ~gcamp_metrics.valid
                warning('Skipping rec %d (%s) — DF/Raster GCaMP vide.', m, gcamp_output_folders{m});
                continue;
            end

            % ==========================================================
            % 2) BLUE
            % ==========================================================
            blue_metrics = compute_branch_metrics( ...
                data, 'blue_plane', m, sampling_rate, ...
                'DF_blue_by_plane', ...
                'Raster_blue_by_plane', ...
                'Acttmp2_blue_by_plane', ...
                'StartEnd_blue_by_plane');

            % ==========================================================
            % 3) SCE metrics — distributions complètes
            % ==========================================================
            sce_threshold = NaN;
            num_sces = NaN;
            sce_cell_participation_percent = [];
            sces_duration_ms = [];

            try
                if isfield(data, 'SCEs') && isstruct(data.SCEs)

                    if isfield(data.SCEs, 'sce_n_cells_threshold') && ...
                       numel(data.SCEs.sce_n_cells_threshold) >= m && ...
                       ~isempty(data.SCEs.sce_n_cells_threshold{m})
                        sce_threshold = data.SCEs.sce_n_cells_threshold{m};
                    end

                    if isfield(data.SCEs, 'TRace_gcamp') && ...
                       numel(data.SCEs.TRace_gcamp) >= m && ...
                       ~isempty(data.SCEs.TRace_gcamp{m})

                        TRace_gcamp = data.SCEs.TRace_gcamp{m};
                        TRace_gcamp = TRace_gcamp(:);
                        num_sces = numel(TRace_gcamp);

                        if isfield(data.SCEs, 'RasterRace_gcamp') && ...
                           numel(data.SCEs.RasterRace_gcamp) >= m && ...
                           ~isempty(data.SCEs.RasterRace_gcamp{m})

                            RasterRace_gcamp = data.SCEs.RasterRace_gcamp{m};
                            NCell_sce = size(RasterRace_gcamp,1);

                            if NCell_sce > 0 && ~isempty(TRace_gcamp)
                                valid_TRace = TRace_gcamp(TRace_gcamp >= 1 & TRace_gcamp <= size(RasterRace_gcamp,2));
                                sce_cell_participation_percent = nan(numel(valid_TRace),1);

                                for i = 1:numel(valid_TRace)
                                    nbActives = sum(RasterRace_gcamp(:, valid_TRace(i)) == 1);
                                    sce_cell_participation_percent(i) = 100 * nbActives / NCell_sce;
                                end
                            end
                        end

                        if isfield(data.SCEs, 'sces_distances_gcamp') && ...
                           numel(data.SCEs.sces_distances_gcamp) >= m && ...
                           ~isempty(data.SCEs.sces_distances_gcamp{m})

                            sces_distances_gcamp = data.SCEs.sces_distances_gcamp{m};

                            if size(sces_distances_gcamp,2) >= 2
                                frame_duration_ms = 1000 / sampling_rate;
                                sces_duration_ms = sces_distances_gcamp(:,2) * frame_duration_ms;
                                sces_duration_ms = sces_duration_ms(:);
                                sces_duration_ms = sces_duration_ms(isfinite(sces_duration_ms));
                            end
                        end
                    end
                end
            catch
                fprintf('SCEs data missing for rec %d\n', m);
            end

            % ==========================================================
            % 4) Store
            % ==========================================================
            results_analysis(m).NumFrames             = gcamp_metrics.nFrames;
            results_analysis(m).ZPosition_um          = z_position_um;
            results_analysis(m).ActiveCellsNumber     = gcamp_metrics.nCells;
            results_analysis(m).ActiveCellsNumberBlue = blue_metrics.nCells;

            results_analysis(m).FrequencyPerCell_gcamp  = gcamp_metrics.freq(:);
            results_analysis(m).AmplitudePerCell_gcamp  = gcamp_metrics.amp(:);
            results_analysis(m).DurationPerCell_gcamp_s = gcamp_metrics.dur;

            results_analysis(m).FrequencyPerCell_blue   = blue_metrics.freq(:);
            results_analysis(m).AmplitudePerCell_blue   = blue_metrics.amp(:);
            results_analysis(m).DurationPerCell_blue_s  = blue_metrics.dur;

            results_analysis(m).SCEsThreshold                 = sce_threshold;
            results_analysis(m).SCEsNumber                    = num_sces;
            results_analysis(m).SCEsCellParticipation_percent = sce_cell_participation_percent;
            results_analysis(m).SCEsduration_ms               = sces_duration_ms;

        catch ME
            fprintf('Error processing rec %d: %s\n', m, ME.message);
        end
    end
end

% =====================================================================
% HELPERS
% =====================================================================

function metrics = compute_branch_metrics(data, branchName, m, sampling_rate, dfField, rasterField, actField, startEndField)

    metrics = struct( ...
        'valid', false, ...
        'DF', [], ...
        'Raster', [], ...
        'Acttmp2', {{}}, ...
        'StartEnd', {{}}, ...
        'nCells', NaN, ...
        'nFrames', NaN, ...
        'freq', [], ...
        'amp', [], ...
        'dur', {{} });

    has_data = has_nonempty_plane_field_nested(data, branchName, dfField, m) && ...
               has_nonempty_plane_field_nested(data, branchName, rasterField, m);

    if ~has_data
        return;
    end

    DF       = concat_planes_nested(data, branchName, m, dfField);
    Raster   = concat_planes_nested(data, branchName, m, rasterField);
    Acttmp2  = concat_acttmp2_planes_nested(data, branchName, m, actField);
    StartEnd = concat_startend_planes_nested(data, branchName, m, startEndField);

    if isempty(DF) || isempty(Raster)
        return;
    end

    [DF, Raster] = align_data(DF, Raster);

    metrics.valid    = true;
    metrics.DF       = DF;
    metrics.Raster   = Raster;
    metrics.Acttmp2  = Acttmp2;
    metrics.StartEnd = StartEnd;
    metrics.nCells   = size(Raster, 1);
    metrics.nFrames  = size(Raster, 2);

    metrics.freq = compute_frequency_from_raster(Raster, sampling_rate);
    metrics.amp  = compute_normalized_amplitude_per_cell(DF, Acttmp2);
    metrics.dur  = extract_event_durations_per_cell(StartEnd, sampling_rate);
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
    if numel(branch.(fieldName)) < m
        return;
    end
    if isempty(branch.(fieldName){m})
        return;
    end
    if ~iscell(branch.(fieldName){m})
        tf = ~isempty(branch.(fieldName){m});
        return;
    end

    planes = branch.(fieldName){m};
    for p = 1:numel(planes)
        if ~isempty(planes{p})
            tf = true;
            return;
        end
    end
end

function Act_all = concat_acttmp2_planes_nested(data, branchName, m, fieldName)
    Act_all = {};

    if ~isfield(data, branchName) || ~isstruct(data.(branchName))
        return;
    end

    branch = data.(branchName);

    if ~isfield(branch, fieldName) || numel(branch.(fieldName)) < m || isempty(branch.(fieldName){m})
        return;
    end

    planes = branch.(fieldName){m};
    for p = 1:numel(planes)
        A = planes{p};
        if isempty(A), continue; end

        if ~iscell(A)
            A = num2cell(A, 2);
        end

        Act_all = [Act_all; A(:)]; %#ok<AGROW>
    end
end

function SE_all = concat_startend_planes_nested(data, branchName, m, fieldName)
    SE_all = {};

    if ~isfield(data, branchName) || ~isstruct(data.(branchName))
        return;
    end

    branch = data.(branchName);

    if ~isfield(branch, fieldName) || numel(branch.(fieldName)) < m || isempty(branch.(fieldName){m})
        return;
    end

    planes = branch.(fieldName){m};
    for p = 1:numel(planes)
        SE = planes{p};
        if isempty(SE), continue; end
        if ~iscell(SE)
            error('StartEnd attendu en cell array (plan %d)', p);
        end
        SE_all = [SE_all; SE(:)]; %#ok<AGROW>
    end
end

function out = concat_planes_nested(data, branchName, m, fieldName)
    out = [];

    if ~isfield(data, branchName) || ~isstruct(data.(branchName))
        return;
    end

    branch = data.(branchName);

    if ~isfield(branch, fieldName) || numel(branch.(fieldName)) < m || isempty(branch.(fieldName){m})
        return;
    end

    planes = branch.(fieldName){m};
    if isempty(planes)
        return;
    end

    for p = 1:numel(planes)
        if ~isempty(planes{p})
            out = [out; planes{p}]; %#ok<AGROW>
        end
    end
end

function [DF, Raster] = align_data(DF, Raster)
    min_cells  = min(size(DF,1), size(Raster,1));
    min_frames = min(size(DF,2), size(Raster,2));
    DF     = DF(1:min_cells, 1:min_frames);
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
        freq_per_cell_per_min = nan(nCells,1);
        return;
    end

    nEvents = sum(Raster, 2);
    freq_per_cell_per_min = nEvents ./ duration_min;
end

function amp = compute_normalized_amplitude_per_cell(DF, Acttmp2)
    if isempty(DF) || isempty(Acttmp2)
        amp = NaN(size(DF,1),1);
        return;
    end

    [nCells, nFrames] = size(DF);
    amp = nan(nCells,1);

    for c = 1:nCells
        if c > numel(Acttmp2)
            continue;
        end

        if iscell(Acttmp2)
            frames = Acttmp2{c};
        elseif isnumeric(Acttmp2) && size(Acttmp2,2) == nFrames
            frames = find(Acttmp2(c,:) > 0);
        else
            frames = [];
        end

        if isempty(frames)
            continue;
        end

        frames = frames(:);
        frames = frames(frames >= 1 & frames <= nFrames);

        if isempty(frames)
            continue;
        end

        amp(c) = mean(DF(c,frames), 'omitnan');
    end
end

function durations_per_cell = extract_event_durations_per_cell(StartEnd, sampling_rate)

    if isempty(StartEnd)
        durations_per_cell = {};
        return;
    end

    durations_per_cell = cell(numel(StartEnd),1);

    for c = 1:numel(StartEnd)
        intervals = StartEnd{c};
        if isempty(intervals)
            durations_per_cell{c} = [];
            continue;
        end

        d = (intervals(:,2) - intervals(:,1)) / sampling_rate * 1000; % → ms;
        d = d(:);
        d = d(isfinite(d));
        durations_per_cell{c} = d;
    end
end