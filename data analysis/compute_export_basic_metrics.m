function results_analysis = compute_export_basic_metrics( ...
    gcamp_output_folders, date_group_paths, data, sampling_rate_group, current_env_group)

    nRec = numel(gcamp_output_folders);

    field_order = { ...
        'NumFrames', ...
        'ZPosition_um', ...
        'ActiveCellsNumber', ...
        'ActiveCellsNumberBlue', ...
        'FrequencyPerCell_gcamp', ...
        'FrequencyPerCell_blue', ...
        'InterEventIntervals_gcamp_ms', ...
        'InterEventIntervals_blue_ms', ...
        'SCEsThreshold', ...
        'SCEsNumber', ...
        'SCEsCellParticipation_percent', ...
        'SCEsduration_ms' ...
        };

    results_analysis = repmat( ...
        cell2struct(repmat({[]}, 1, numel(field_order)), field_order, 2), ...
        nRec, 1);

    for m = 1:nRec

        % Nom de la date
        [~, date_name] = fileparts(date_group_paths{m});

        try
            sampling_rate = sampling_rate_group{m};

            % ==========================================================
            % 0) Z position par plan
            % ==========================================================
            z_position_um = {};

            try
                [~, ~, ~, ~, ~, position, ~, ~, ~] = find_key_value(current_env_group{m});

                if ~isempty(position)
                    position = position(:);
                    position = position(isfinite(position));

                    for p = 1:numel(position)
                        z_position_um{p} = position(p);
                    end
                end
            catch
                z_position_um = {};
            end

            % ==========================================================
            % 1) GCaMP par plan
            % ==========================================================
            first_stim_frame = [];

            if isfield(data, 'stim') && ...
               isfield(data.stim, 'stim_frames_log_group') && ...
               numel(data.stim.stim_frames_log_group) >= m && ...
               ~isempty(data.stim.stim_frames_log_group{m})
            
                stim_frames = data.stim.stim_frames_log_group{m};
                stim_frames = double(stim_frames(:));
                stim_frames = stim_frames(isfinite(stim_frames));
            
                if ~isempty(stim_frames)
                    first_stim_frame = min(stim_frames);
                end
            end

            gcamp_metrics = compute_branch_metrics_by_plane( ...
                data, 'gcamp_plane', m, sampling_rate, ...
                'DF_gcamp_by_plane', ...
                'Raster_gcamp_by_plane', ...
                first_stim_frame, ...
                date_name);

            if ~gcamp_metrics.valid
                warning('Skipping rec %d (%s) — DF/Raster GCaMP vide.', ...
                    m, gcamp_output_folders{m});
                continue;
            end

            % ==========================================================
            % 2) BLUE par plan
            % ==========================================================
            blue_metrics = compute_branch_metrics_by_plane( ...
                data, 'blue_plane', m, sampling_rate, ...
                'DF_blue_by_plane', ...
                'Raster_blue_by_plane', ...
                first_stim_frame, ...
                date_name);

            % ==========================================================
            % 3) SCE metrics
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
                            NCell_sce = size(RasterRace_gcamp, 1);

                            if NCell_sce > 0 && ~isempty(TRace_gcamp)
                                valid_TRace = TRace_gcamp( ...
                                    TRace_gcamp >= 1 & ...
                                    TRace_gcamp <= size(RasterRace_gcamp, 2));

                                sce_cell_participation_percent = nan(numel(valid_TRace), 1);

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

                            if size(sces_distances_gcamp, 2) >= 2
                                frame_duration_ms = 1000 / sampling_rate;
                                sces_duration_ms = sces_distances_gcamp(:, 2) * frame_duration_ms;
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
            % 4) Store par plan
            % ==========================================================
            results_analysis(m).NumFrames             = gcamp_metrics.nFrames_by_plane;
            results_analysis(m).ZPosition_um          = z_position_um;
            results_analysis(m).ActiveCellsNumber     = gcamp_metrics.nCells_by_plane;
            results_analysis(m).ActiveCellsNumberBlue = blue_metrics.nCells_by_plane;

            results_analysis(m).FrequencyPerCell_gcamp = gcamp_metrics.freq_by_plane;
            results_analysis(m).FrequencyPerCell_blue  = blue_metrics.freq_by_plane;

            results_analysis(m).InterEventIntervals_gcamp_ms = gcamp_metrics.intervals_ms_by_plane;
            results_analysis(m).InterEventIntervals_blue_ms  = blue_metrics.intervals_ms_by_plane;

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

function metrics = compute_branch_metrics_by_plane( ...
    data, branchName, m, sampling_rate, dfField, rasterField, first_stim_frame, date_name)

    metrics = struct( ...
        'valid', false, ...
        'nCells_by_plane', {{}}, ...
        'nFrames_by_plane', {{}}, ...
        'freq_by_plane', {{}}, ...
        'intervals_ms_by_plane', {{}});

    has_data = has_nonempty_plane_field_nested(data, branchName, dfField, m) && ...
               has_nonempty_plane_field_nested(data, branchName, rasterField, m);

    if ~has_data
        return;
    end

    DF_planes     = get_planes_nested(data, branchName, m, dfField);
    Raster_planes = get_planes_nested(data, branchName, m, rasterField);

    nPlanes = max(numel(DF_planes), numel(Raster_planes));

    metrics.nCells_by_plane       = cell(1, nPlanes);
    metrics.nFrames_by_plane      = cell(1, nPlanes);
    metrics.freq_by_plane         = cell(1, nPlanes);
    metrics.intervals_ms_by_plane = cell(1, nPlanes);

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
        
        % Crop avant la première frame de stimulation
        if ~isempty(first_stim_frame) && isfinite(first_stim_frame)
        
            first_stim_frame_global = round(first_stim_frame);
        
            % Conversion frame globale → frame du plan
            first_stim_frame_plane = ceil(first_stim_frame_global / nPlanes);
            fprintf('[INFO] Date %s | Branch %s | Plane %d | First stim frame (plane): %d\n', ...
                date_name, branchName, p, first_stim_frame_plane);
        
            if first_stim_frame_plane > 1 && first_stim_frame_plane <= size(Raster, 2)
                %DF     = DF(:, 1:first_stim_frame_plane-1);
                Raster = Raster(:, 1:first_stim_frame_plane-1);
            end
        end

        metrics.valid = true;

        metrics.nCells_by_plane{p}  = size(Raster, 1);
        metrics.nFrames_by_plane{p} = size(Raster, 2);

        metrics.freq_by_plane{p} = compute_frequency_from_raster(Raster, sampling_rate);
        metrics.intervals_ms_by_plane{p} = compute_inter_event_intervals_from_raster(Raster, sampling_rate);
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

    if ~isfield(branch, fieldName) || numel(branch.(fieldName)) < m || isempty(branch.(fieldName){m})
        return;
    end

    planes = branch.(fieldName){m};

    if ~iscell(planes)
        planes = {planes};
    end
end

% Ancienne version : concaténation des plans
% function out = concat_planes_nested(data, branchName, m, fieldName)
%     out = [];
%
%     if ~isfield(data, branchName) || ~isstruct(data.(branchName))
%         return;
%     end
%
%     branch = data.(branchName);
%
%     if ~isfield(branch, fieldName) || numel(branch.(fieldName)) < m || isempty(branch.(fieldName){m})
%         return;
%     end
%
%     planes = branch.(fieldName){m};
%     if isempty(planes)
%         return;
%     end
%
%     for p = 1:numel(planes)
%         if ~isempty(planes{p})
%             out = [out; planes{p}]; %#ok<AGROW>
%         end
%     end
% end

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
        intervals_ms = [intervals_ms; cell_intervals(:)]; %#ok<AGROW>
    end

    intervals_ms = intervals_ms(isfinite(intervals_ms));
end